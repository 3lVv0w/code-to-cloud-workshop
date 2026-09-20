import express, { Request, Response } from 'express';
import { Pool } from 'pg';
import Redis from 'ioredis';
import client from 'prom-client';

// ==============================================================================
// 12-Factor App Demonstration Service
// Demonstrates:
// - Factor III: Config via environment variables
// - Factor IV: Backing services as attached resources (Postgres & Redis)
// - Factor VI: Stateless processes
// - Factor IX: Fast boot & Graceful connection draining on SIGTERM
// - Factor XI: Logs as unbuffered structured JSON streams to stdout
// ==============================================================================

const app = express();
app.use(express.json());

const PORT = parseInt(process.env.PORT || '3000', 10);
const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:postgres@postgres:5432/workshop_db';
const REDIS_URL = process.env.REDIS_URL || 'redis://redis:6379';

// Structured Logger
const log = (level: string, message: string, meta: Record<string, any> = {}) => {
  console.log(JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    service: 'order-service',
    message,
    ...meta,
  }));
};

// Attached Backing Services
const dbPool = new Pool({
  connectionString: DATABASE_URL,
  max: 10,
  idleTimeoutMillis: 10000,
});

const redis = new Redis(REDIS_URL, {
  maxRetriesPerRequest: 2,
  enableReadyCheck: true,
  lazyConnect: true,
});

// Prometheus Metrics Registry
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total count of HTTP requests processed',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

const orderReservationDuration = new client.Histogram({
  name: 'order_reservation_duration_seconds',
  help: 'Latency of ticket reservation transactions',
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2],
  registers: [register],
});

// Application State Flags for Kubernetes Probes
let isReady = false;
let isShuttingDown = false;

// Initialize Database Schema on Startup
async function initDb() {
  log('info', 'Connecting to database and initializing schema...');
  const client = await dbPool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS ticket_tiers (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        total_capacity INT NOT NULL,
        issued_count INT NOT NULL DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS ticket_reservations (
        id VARCHAR(64) PRIMARY KEY,
        tier_id INT REFERENCES ticket_tiers(id),
        user_id VARCHAR(64) NOT NULL,
        status VARCHAR(20) NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT NOW()
      );

      INSERT INTO ticket_tiers (id, name, total_capacity, issued_count)
      VALUES (1, 'General Participant Pass (ClassRoom 3)', 50, 0)
      ON CONFLICT (id) DO NOTHING;
    `);
    log('info', 'Database schema initialized successfully.');
  } finally {
    client.release();
  }
}

// ==============================================================================
// Kubernetes Health Probes
// ==============================================================================

// Startup Probe: Confirms application process has booted
app.get('/healthz/startup', (req: Request, res: Response) => {
  res.status(200).send('STARTED');
});

// Liveness Probe: Fails only when service deadlocks and requires restart
app.get('/healthz/liveness', (req: Request, res: Response) => {
  if (isShuttingDown) {
    return res.status(503).send('SHUTTING_DOWN');
  }
  res.status(200).send('ALIVE');
});

// Readiness Probe: Controls whether Ingress directs active traffic to this Pod
app.get('/healthz/readiness', async (req: Request, res: Response) => {
  if (!isReady || isShuttingDown) {
    return res.status(503).send('NOT_READY');
  }
  try {
    // Ping DB to confirm connectivity
    await dbPool.query('SELECT 1;');
    res.status(200).send('READY');
  } catch (err) {
    res.status(503).send('DB_UNAVAILABLE');
  }
});

// Standard Combined Healthz
app.get('/healthz', (req: Request, res: Response) => {
  if (!isReady || isShuttingDown) {
    return res.status(503).send('DEGRADED');
  }
  res.status(200).send('OK');
});

// Prometheus Metrics Endpoint
app.get('/metrics', async (req: Request, res: Response) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// ==============================================================================
// High-Concurrency Ticket Reservation (SELECT ... FOR UPDATE)
// ==============================================================================
app.post('/orders', async (req: Request, res: Response) => {
  const timer = orderReservationDuration.startTimer();
  const { tierId = 1, userId = 'anonymous' } = req.body;

  if (isShuttingDown) {
    httpRequestCounter.inc({ method: 'POST', route: '/orders', status: '503' });
    return res.status(503).json({ error: 'Server is currently draining connections for shutdown' });
  }

  const client = await dbPool.connect();

  try {
    // 1. Begin atomic transaction
    await client.query('BEGIN');

    // 2. Acquire exclusive ROW LOCK on the requested tier
    const tierRes = await client.query(
      `SELECT id, name, total_capacity, issued_count FROM ticket_tiers WHERE id = $1 FOR UPDATE;`,
      [tierId]
    );

    if (tierRes.rows.length === 0) {
      await client.query('ROLLBACK');
      httpRequestCounter.inc({ method: 'POST', route: '/orders', status: '404' });
      return res.status(404).json({ error: 'Ticket tier not found' });
    }

    const tier = tierRes.rows[0];

    // 3. Strict capacity validation inside the locked state
    if (tier.issued_count >= tier.total_capacity) {
      await client.query('ROLLBACK');
      httpRequestCounter.inc({ method: 'POST', route: '/orders', status: '409' });
      return res.status(409).json({
        error: 'Sold Out',
        message: 'No remaining inventory available for this tier',
        tier: tier.name,
      });
    }

    // 4. Increment stock atomically
    await client.query(
      `UPDATE ticket_tiers SET issued_count = issued_count + 1 WHERE id = $1;`,
      [tierId]
    );

    // 5. Create reservation record
    const reservationId = `ord_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
    await client.query(
      `INSERT INTO ticket_reservations (id, tier_id, user_id, status) VALUES ($1, $2, $3, 'CONFIRMED');`,
      [reservationId, tierId, userId]
    );

    // 6. Commit transaction and release row lock
    await client.query('COMMIT');

    log('info', 'Ticket order confirmed successfully', { reservationId, tierId, userId });
    httpRequestCounter.inc({ method: 'POST', route: '/orders', status: '201' });

    return res.status(201).json({
      success: true,
      reservationId,
      tier: tier.name,
      seatNumber: tier.issued_count + 1,
      totalCapacity: tier.total_capacity,
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    log('error', 'Order transaction failed', { error: error.message });
    httpRequestCounter.inc({ method: 'POST', route: '/orders', status: '500' });
    return res.status(500).json({ error: 'Internal Server Error', details: error.message });
  } finally {
    client.release();
    timer();
  }
});

// ==============================================================================
// Server Boot & Graceful Connection Draining
// ==============================================================================

const server = app.listen(PORT, async () => {
  try {
    await initDb();
    await redis.connect();
    isReady = true;
    log('info', `Order microservice booted and ready on port ${PORT}`);
  } catch (err: any) {
    log('fatal', 'Failed to boot backing services', { error: err.message });
    process.exit(1);
  }
});

// Graceful Termination Signals (Kubernetes Drain)
const handleSignal = (signal: string) => {
  log('warn', `Received ${signal}. Initiating graceful termination sequence...`);
  isShuttingDown = true;
  isReady = false;

  // 1. Stop accepting new connections
  server.close(async (err) => {
    if (err) {
      log('error', 'Error closing HTTP server', { error: err.message });
      process.exit(1);
    }

    log('info', 'HTTP listeners closed. Draining database connection pool...');
    try {
      // 2. Drain database connections
      await dbPool.end();
      log('info', 'Database pool drained cleanly.');

      // 3. Close Redis connection
      await redis.quit();
      log('info', 'Redis connection closed cleanly. Process exiting with code 0.');

      process.exit(0);
    } catch (shutdownErr: any) {
      log('error', 'Error during shutdown cleanup', { error: shutdownErr.message });
      process.exit(1);
    }
  });

  // Fallback safety timeout (25 seconds)
  setTimeout(() => {
    log('fatal', 'Graceful shutdown timed out after 25s. Force killing process.');
    process.exit(1);
  }, 25000).unref();
};

process.on('SIGTERM', () => handleSignal('SIGTERM'));
process.on('SIGINT', () => handleSignal('SIGINT'));
