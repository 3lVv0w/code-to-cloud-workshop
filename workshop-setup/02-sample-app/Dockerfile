# ==============================================================================
# STAGE 1: Build & Compilation (Hermetic Environment)
# ==============================================================================
FROM node:22-alpine AS builder

WORKDIR /usr/src/app

COPY package.json tsconfig.json ./
RUN npm install

COPY src ./src
RUN npm run build
RUN npm prune --production

# ==============================================================================
# STAGE 2: Production Distroless Runtime (Zero Shell, Zero Package Manager)
# Reduces OS package CVE attack surface to 0
# ==============================================================================
FROM gcr.io/distroless/nodejs22-debian12:nonroot AS runner

WORKDIR /app

COPY --from=builder --chown=nonroot:nonroot /usr/src/app/package.json ./
COPY --from=builder --chown=nonroot:nonroot /usr/src/app/node_modules ./node_modules
COPY --from=builder --chown=nonroot:nonroot /usr/src/app/dist ./dist

USER nonroot

ENV NODE_ENV=production \
    PORT=3000

EXPOSE 3000

# Direct binary execution prevents shell injection
CMD ["dist/index.js"]
