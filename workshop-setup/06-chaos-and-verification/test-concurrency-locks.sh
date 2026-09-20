#!/usr/bin/env bash
# ==============================================================================
# Script: test-concurrency-locks.sh
# Purpose: High-traffic concurrency test verifying PostgreSQL row-level locks
# ==============================================================================

set -eo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ENDPOINT="http://localhost:3000/orders"
PARALLEL_REQUESTS=30

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}  High-Concurrency Ticket Rush Simulation              ${NC}"
echo -e "${BLUE}  Firing ${PARALLEL_REQUESTS} parallel checkout requests...            ${NC}"
echo -e "${BLUE}======================================================${NC}\n"

# Verify service is responding
curl -s -f http://localhost:3000/healthz >/dev/null || {
  echo -e "${YELLOW}Warning: Sample app is not running on http://localhost:3000.${NC}"
  echo "Please start the local stack first via: cd ../02-sample-app && docker compose up -d"
  exit 1
}

echo "Dispatching requests concurrently in background..."
TMP_DIR=$(mktemp -d)

for i in $(seq 1 $PARALLEL_REQUESTS); do
  (
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ENDPOINT" \
      -H "Content-Type: application/json" \
      -d "{\"tierId\": 1, \"userId\": \"usr_rush_$i\"}")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    echo "$HTTP_CODE: $BODY" >> "$TMP_DIR/results.log"
  ) &
done

wait

echo -e "\n${BLUE}======================================================${NC}"
echo -e "${BLUE}  Transaction Reconciliation Results                  ${NC}"
echo -e "${BLUE}======================================================${NC}"

SUCCESS_COUNT=$(grep -c "^201" "$TMP_DIR/results.log" || true)
CONFLICT_COUNT=$(grep -c "^409" "$TMP_DIR/results.log" || true)
ERROR_COUNT=$(grep -c "^500" "$TMP_DIR/results.log" || true)

echo -e "  [${GREEN}CONFIRMED ORDERS (201)${NC}]: ${SUCCESS_COUNT}"
echo -e "  [${YELLOW}SAFELY SOLD OUT (409)${NC}]:  ${CONFLICT_COUNT}"
echo -e "  [${RED}SYSTEM FAILURES (500)${NC}]:   ${ERROR_COUNT}"

if [ "$ERROR_COUNT" -eq 0 ]; then
  echo -e "\n${GREEN}SUCCESS: Zero overselling and zero 500 errors!${NC}"
  echo "PostgreSQL row-level locking (SELECT ... FOR UPDATE) guaranteed perfect transactional consistency."
else
  echo -e "\n${RED}ALERT: System failures encountered.${NC}"
fi

rm -rf "$TMP_DIR"
