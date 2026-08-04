# API Testing Patterns — erp-admin

## Cookie-based auth for curl

The erp-admin API uses JWT tokens stored in cookies. To test endpoints:

```bash
TOKEN="eyJ..."  # access_token from browser DevTools > Application > Cookies
REFRESH="eyJ..."  # refresh_token
DEVICE="uuid"  # device_id

curl 'https://api-erp.vppos.vn/api/v1/attendance-sheets/{id}?q=keyword' \
  -H "Cookie: access_token=$TOKEN; refresh_token=$REFRESH; device_id=$DEVICE" \
  --compressed | jq '.data.rows | length'
```

## How to get the token

1. Open browser DevTools → Network tab
2. Make any request in the app
3. Copy `Cookie` header from the request
4. Or: DevTools → Application → Cookies → copy `access_token`

## Testing filter params

```bash
# Baseline: no filter
NO_FILTER=$(curl -s "..." | jq '.data.rows | length')

# With filter
WITH_FILTER=$(curl -s "...?q=keyword" | jq '.data.rows | length')

if [ "$NO_FILTER" = "$WITH_FILTER" ]; then
  echo "Param NOT supported"
else
  echo "Param IS supported"
fi
```

## Verified endpoint support (2026-07-30)

| Endpoint | Method | `q` param | `employeeIds` | Notes |
|----------|--------|-----------|---------------|-------|
| `/attendance-sheets` (list) | GET | ✅ | N/A | Timesheet period list; `useAttendanceTimesheetRows({ q })` works |
| `/attendance-sheets/{id}` (detail) | GET | ❌ | ❌ | Detail rows, no filtering support |
| `/payroll-runs/{id}/employees` | GET | ✅ | N/A | Server-side search works, used by PayrollPeriodDetailView |
| `/hr/employees` | GET | ✅ | N/A | Server-side search works |

## Response structure

```json
{
  "success": true,
  "data": { "rows": [...], "sheet": {...}, "pagination": {...} },
  "meta": { "timestamp": "...", "path": "..." }
}
```

For list endpoints (without detail nesting):
```json
{
  "success": true,
  "data": [...],
  "meta": { "pagination": { "page": 1, "totalPages": 7, "pageSize": 2 } }
}
```
