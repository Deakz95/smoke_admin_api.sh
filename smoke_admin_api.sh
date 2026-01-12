cat > smoke_admin_api.sh <<'EOF'
#!/usr/bin/env bash
#!/usr/bin/env bash
set -euo pipefail

BASE="https://app-7165.onrender.com"
COOKIE_JAR="/tmp/qt.cookies"

EMAIL="admin@demo.quantract"
PASSWORD="Password123!"
ROLE="admin"

have_jq() { command -v jq >/dev/null 2>&1; }

json_first() {
  # usage: json_first "<json>" "<jq_expr_for_array_or_scalar>"
  # returns first string (or empty)
  local json="$1"
  local expr="$2"
  if have_jq; then
    echo "$json" | jq -r "$expr // empty" 2>/dev/null | head -n 1
  else
    # node fallback: expr is limited to a few known patterns below (we call with fixed tokens)
    node - <<'NODE' "$expr"
const fs = require("fs");
const expr = process.argv[2];
let input = "";
process.stdin.on("data", d => input += d);
process.stdin.on("end", () => {
  try {
    const j = JSON.parse(input || "{}");
    const get = (path) => path.split(".").reduce((a,k)=>a && a[k], j);
    const firstFromArray = (arr) => Array.isArray(arr) && arr.length ? arr[0] : null;

    const m = expr.match(/^\.(\w+)\[0\]\.(\w+)$/);
    if (m) {
      const arr = j[m[1]];
      const first = firstFromArray(arr);
      const v = first && first[m[2]];
      if (v) process.stdout.write(String(v));
      return;
    }
    const m2 = expr.match(/^\.(\w+)\[0\]$/);
    if (m2) {
      const first = firstFromArray(j[m2[1]]);
      if (first != null) process.stdout.write(String(first));
      return;
    }
  } catch {}
});
NODE
  fi
}

curl_json() {
  # usage: curl_json METHOD PATH [JSON_BODY]
  local method="$1"; shift
  local path="$1"; shift
  local body="${1:-}"

  if [[ -n "$body" ]]; then
    curl -sS -X "$method" -b "$COOKIE_JAR" \
      -H 'content-type: application/json' \
      --data-binary "$body" \
      "$BASE$path"
  else
    curl -sS -X "$method" -b "$COOKIE_JAR" "$BASE$path"
  fi
}

curl_status() {
  # usage: curl_status METHOD PATH [JSON_BODY]
  local method="$1"; shift
  local path="$1"; shift
  local body="${1:-}"

  local code
  if [[ -n "$body" ]]; then
    code="$(curl -sS -o /dev/null -w "%{http_code}" -X "$method" -b "$COOKIE_JAR" \
      -H 'content-type: application/json' \
      --data-binary "$body" \
      "$BASE$path")"
  else
    code="$(curl -sS -o /dev/null -w "%{http_code}" -X "$method" -b "$COOKIE_JAR" "$BASE$path")"
  fi
  echo "$code"
}

log() { printf "%s\n" "$*"; }

hit() {
  # hit METHOD PATH [JSON]
  local method="$1"; shift
  local path="$1"; shift
  local body="${1:-}"

  local code
  code="$(curl_status "$method" "$path" "$body")"
  printf "%-6s %-55s %s\n" "$method" "$path" "$code"
}

# -------------------
# 1) Login
# -------------------
log "== LOGIN =="
curl -sS -c "$COOKIE_JAR" "$BASE/api/auth/password/login" \
  -H 'content-type: application/json' \
  --data-binary "{\"role\":\"$ROLE\",\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" >/dev/null

# Sanity: auth/me
hit GET  "/api/auth/me"

# -------------------
# 2) Discover IDs
# -------------------
log ""
log "== DISCOVER IDS =="

JOBS_JSON="$(curl_json GET /api/admin/jobs || true)"
JOB_ID="$(json_first "$JOBS_JSON" '.jobs[0].id')"
QUOTE_ID_FROM_JOBS="$(json_first "$JOBS_JSON" '.jobs[0].quoteId')"

QUOTES_SUMMARY_JSON="$(curl_json GET /api/admin/quotes/summary || true)"
QUOTE_ID="$(json_first "$QUOTES_SUMMARY_JSON" '.data[0].quoteId')"
[[ -z "${QUOTE_ID:-}" ]] && QUOTE_ID="${QUOTE_ID_FROM_JOBS:-}"

CLIENTS_JSON="$(curl_json GET /api/admin/clients || true)"
CLIENT_ID="$(json_first "$CLIENTS_JSON" '.clients[0].id')"

USERS_JSON="$(curl_json GET /api/admin/users || true)"
USER_ID="$(json_first "$USERS_JSON" '.users[0].id')"

INVOICES_JSON="$(curl_json GET /api/admin/invoices || true)"
INVOICE_ID="$(json_first "$INVOICES_JSON" '.invoices[0].id')"

SUPPLIERS_JSON="$(curl_json GET /api/admin/suppliers || true)"
SUPPLIER_ID="$(json_first "$SUPPLIERS_JSON" '.suppliers[0].id')"

SUBCONTRACTORS_JSON="$(curl_json GET /api/admin/subcontractors || true)"
SUBCONTRACTOR_ID="$(json_first "$SUBCONTRACTORS_JSON" '.subcontractors[0].id')"

ENQUIRIES_JSON="$(curl_json GET /api/admin/enquiries || true)"
ENQUIRY_ID="$(json_first "$ENQUIRIES_JSON" '.enquiries[0].id')"

TIMESHEETS_JSON="$(curl_json GET /api/admin/timesheets || true)"
TIMESHEET_ID="$(json_first "$TIMESHEETS_JSON" '.timesheets[0].id')"

CERTS_JSON="$(curl_json GET /api/admin/certificates || true)"
CERT_ID="$(json_first "$CERTS_JSON" '.certificates[0].id')"

VARS_JSON="$(curl_json GET /api/admin/jobs/${JOB_ID:-___}/variations 2>/dev/null || true)"
VARIATION_ID="$(json_first "$VARS_JSON" '.variations[0].id')"

COST_ITEMS_JSON="$(curl_json GET /api/admin/jobs/${JOB_ID:-___}/cost-items 2>/dev/null || true)"
COST_ITEM_ID="$(json_first "$COST_ITEMS_JSON" '.costItems[0].id')"

SNAG_ITEMS_JSON="$(curl_json GET /api/admin/jobs/${JOB_ID:-___}/snag-items 2>/dev/null || true)"
SNAG_ID="$(json_first "$SNAG_ITEMS_JSON" '.snagItems[0].id')"

INVITES_JSON="$(curl_json GET /api/admin/invites || true)"
INVITE_ID="$(json_first "$INVITES_JSON" '.invites[0].id')"

SUPPLIER_BILLS_JSON="$(curl_json GET /api/admin/jobs/${JOB_ID:-___}/supplier-bills 2>/dev/null || true)"
BILL_ID="$(json_first "$SUPPLIER_BILLS_JSON" '.supplierBills[0].id')"

SITES_JSON="$(curl_json GET /api/admin/sites || true)"
SITE_ID="$(json_first "$SITES_JSON" '.sites[0].id')"

log "JOB_ID=${JOB_ID:-<none>}"
log "QUOTE_ID=${QUOTE_ID:-<none>}"
log "CLIENT_ID=${CLIENT_ID:-<none>}"
log "USER_ID=${USER_ID:-<none>}"
log "INVOICE_ID=${INVOICE_ID:-<none>}"
log "SUPPLIER_ID=${SUPPLIER_ID:-<none>}"
log "SUBCONTRACTOR_ID=${SUBCONTRACTOR_ID:-<none>}"
log "ENQUIRY_ID=${ENQUIRY_ID:-<none>}"
log "TIMESHEET_ID=${TIMESHEET_ID:-<none>}"
log "CERT_ID=${CERT_ID:-<none>}"
log "VARIATION_ID=${VARIATION_ID:-<none>}"
log "COST_ITEM_ID=${COST_ITEM_ID:-<none>}"
log "SNAG_ID=${SNAG_ID:-<none>}"
log "INVITE_ID=${INVITE_ID:-<none>}"
log "BILL_ID=${BILL_ID:-<none>}"
log "SITE_ID=${SITE_ID:-<none>}"

# Helper to substitute placeholders safely
sub() {
  local p="$1"
  p="${p/\[jobId\]/${JOB_ID:-__MISSING__}}"
  p="${p/\[quoteId\]/${QUOTE_ID:-__MISSING__}}"
  p="${p/\[clientId\]/${CLIENT_ID:-__MISSING__}}"
  p="${p/\[userId\]/${USER_ID:-__MISSING__}}"
  p="${p/\[invoiceId\]/${INVOICE_ID:-__MISSING__}}"
  p="${p/\[engineerId\]/${USER_ID:-__MISSING__}}"
  p="${p/\[inviteId\]/${INVITE_ID:-__MISSING__}}"
  p="${p/\[billId\]/${BILL_ID:-__MISSING__}}"
  p="${p/\[certificateId\]/${CERT_ID:-__MISSING__}}"
  p="${p/\[variationId\]/${VARIATION_ID:-__MISSING__}}"
  p="${p/\[costItemId\]/${COST_ITEM_ID:-__MISSING__}}"
  p="${p/\[attachmentId\]/__MISSING__}"
  p="${p/\[snagId\]/${SNAG_ID:-__MISSING__}}"
  p="${p/\[stageId\]/__MISSING__}"
  p="${p/\[id\]/${TIMESHEET_ID:-__MISSING__}}"   # used by timesheets/[id] and expenses/[id]
  echo "$p"
}

# -------------------
# 3) Smoke test all routes (GET by default)
# -------------------
log ""
log "== SMOKE TEST (GET unless noted) =="

# List based on your find output; all map to /api/...
ROUTES=(
  "/api/admin/sites"
  "/api/admin/materials/stock-items"
  "/api/admin/materials/stock-movements"
  "/api/admin/stages/[stageId]"
  "/api/admin/schedule"
  "/api/admin/invites/[inviteId]"
  "/api/admin/invites"
  "/api/admin/supplier-bills/[billId]/lines"
  "/api/admin/supplier-bills/[billId]/pdf"
  "/api/admin/supplier-bills/[billId]/post"
  "/api/admin/clients/[clientId]"
  "/api/admin/clients"
  "/api/admin/suppliers/summary"
  "/api/admin/suppliers"
  "/api/admin/dashboard"
  "/api/admin/invoices/auto-chase/run"
  "/api/admin/invoices"
  "/api/admin/invoices/[invoiceId]/send"
  "/api/admin/invoices/[invoiceId]"
  "/api/admin/invoices/[invoiceId]/payment-link"
  "/api/admin/invoices/[invoiceId]/remind"
  "/api/admin/jobs"
  "/api/admin/jobs/[jobId]/finance-overview"
  "/api/admin/jobs/[jobId]/stages"
  "/api/admin/jobs/[jobId]/supplier-bills"
  "/api/admin/jobs/[jobId]/invoices"
  "/api/admin/jobs/[jobId]/time-entries"
  "/api/admin/jobs/[jobId]/costing"
  "/api/admin/jobs/[jobId]"
  "/api/admin/jobs/[jobId]/certificates"
  "/api/admin/jobs/[jobId]/cost-items"
  "/api/admin/jobs/[jobId]/variations"
  "/api/admin/jobs/[jobId]/snag-items"
  "/api/admin/jobs/[jobId]/budget-lines"
  "/api/admin/enquiries"
  "/api/admin/enquiries/[id]/move-stage"
  "/api/admin/certificates/[certificateId]"
  "/api/admin/certificates/[certificateId]/void"
  "/api/admin/certificates/[certificateId]/pdf"
  "/api/admin/certificates/[certificateId]/complete"
  "/api/admin/certificates/[certificateId]/reissue"
  "/api/admin/certificates/[certificateId]/issue"
  "/api/admin/certificates"
  "/api/admin/rate-cards"
  "/api/admin/settings/logo"
  "/api/admin/settings"
  "/api/admin/timesheets"
  "/api/admin/timesheets/[id]/reject"
  "/api/admin/timesheets/[id]/approve"
  "/api/admin/timesheets/[id]"
  "/api/admin/billing/checkout"
  "/api/admin/billing/portal"
  "/api/admin/billing/status"
  "/api/admin/subcontractors"
  "/api/admin/reports/profitability"
  "/api/admin/cost-items/[costItemId]/attachments"
  "/api/admin/cost-items/[costItemId]/attachments/[attachmentId]"
  "/api/admin/quotes/summary"
  "/api/admin/quotes"
  "/api/admin/quotes/[quoteId]/send"
  "/api/admin/quotes/[quoteId]/invoice"
  "/api/admin/quotes/[quoteId]"
  "/api/admin/quotes/[quoteId]/token"
  "/api/admin/purchase-orders"
  "/api/admin/variations/[variationId]/attachments/[attachmentId]"
  "/api/admin/variations/[variationId]/send"
  "/api/admin/variations/[variationId]"
  "/api/admin/variations/[variationId]/pdf"
  "/api/admin/expenses"
  "/api/admin/expenses/[id]/confirm"
  "/api/admin/expenses/[id]/parse"
  "/api/admin/expenses/upload"
  "/api/admin/expenses/parse"
  "/api/admin/users"
  "/api/admin/users/set-password"
  "/api/admin/users/[userId]/permissions"
  "/api/admin/planner"
  "/api/admin/planner/move"
  "/api/admin/snag-items/[snagId]"
  "/api/admin/xero/invoices.csv"
  "/api/admin/xero/oauth/callback"
  "/api/admin/xero/oauth/start"
  "/api/admin/xero/export-pack"
  "/api/admin/engineers"
  "/api/admin/engineers/[engineerId]"
)

# Some endpoints are likely POST-only. We’ll still try GET and you’ll see 405.
# If you want, we can extend this to call POST with a known-safe body per route.ts.

for r in "${ROUTES[@]}"; do
  path="$(sub "$r")"
  hit GET "$path"
done

log ""
log "Done. Any 405s mean 'wrong method'; any __MISSING__ means we couldn’t discover an ID for that route."

EOF