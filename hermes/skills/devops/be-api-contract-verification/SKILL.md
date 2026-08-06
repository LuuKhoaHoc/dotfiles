---
name: be-api-contract-verification
description: Use when verifying FE API contracts against the BE OpenAPI.
---

# BE API Contract Verification (erp-admin ↔ api-erp.vppos.vn)

Class of task: confirm what the backend actually exposes before writing code, issues, or bug reports about an API — endpoint exists?, request body fields?, query params?, response shape? Also detecting FE↔BE contract drift (dead form fields, wrong paths, invented endpoints).

## Trigger Conditions
- "Check endpoint X tồn tại không / có field Y không" trước khi viết issue hoặc code.
- Nghi ngờ form field / payload không khớp BE (dead required field, field bị bỏ qua khi submit).
- Audit MFE dùng endpoint của domain khác (sale → finance/product) có đúng interface không.
- Debug 404 / contract mismatch.

## Key discovery: where the real spec lives

`https://api-erp.vppos.vn/docs` trả về **Scalar HTML shell** (script tag `data-url="/openapi.yaml"`) — KHÔNG phải spec. Đường thật:

```bash
curl -sS --max-time 15 "https://api-erp.vppos.vn/openapi.yaml" -o /tmp/openapi.yaml   # ~1.4MB, 200 OK
```

`/docs/json`, `/openapi.json`, `/docs/openapi.json` → **405** — đừng thử. Spec là YAML 1.4MB: luôn grep/python, không load nguyên file vào context.

## Verification recipes

### 1. Endpoint tồn tại + list paths
```bash
grep -oE '^  /[^ ]+' /tmp/openapi.yaml | sort -u | grep -iE "partner|customer|transfer"
```

### 2. Request body schema (dead-field check — quan trọng nhất)
```bash
python3 - <<'EOF'
y = open('/tmp/openapi.yaml').read()
i = y.find('TransferCustomerPartnerRequest:')   # tên schema từ $ref trong requestBody
print(y[i:i+1500])
EOF
```
Pattern "dead required field": form field `required` trong FE schema nhưng request schema BE không có field đó (real case 2026-08-05: `TransferCustomerPartnerRequest { partnerId, reason }` — không có `verifierId` dù AgentTransferModal bắt buộc chọn verifier từ 3 tên fake). → issue `ready-for-human` (cần BE/PO quyết: thêm endpoint + field, hoặc gỡ field), KHÔNG để agent tự ý xử lý.

### 3. OperationId + query params của list endpoint
```bash
python3 - <<'EOF'
import re
y = open('/tmp/openapi.yaml').read()
for path in ['/api/v1/crm/finance/receivables:', '/api/v1/crm/finance/invoice-requests:']:
    seg = y[y.find(path):y.find(path)+1800]
    op = re.search(r'operationId: (\w+)', seg)
    params = re.findall(r'name: (\w+)\n\s+in: query', seg)
    print(path, '->', op.group(1) if op else '?', '| query:', params)
EOF
```
Dùng để xác nhận FE gửi đúng param (vd `customerId` có tồn tại không).

### 4. Cross-MFE endpoint usage audit (dùng đúng interface chưa)
```bash
grep -rhoE "API_ENDPOINTS\.[A-Z_]+" apps/<mfe>/src --include="*.ts" --include="*.tsx" | sort | uniq -c
grep -rE '/api/v1/(finance|product)|api-erp|https?://' apps/<mfe>/src   # phải = 0 ngoài config
```
- Interface chính thức: `@hilo/shared` index.ts → `export * from './api'` → `api/index.ts` → `endpoints.ts`. Import từ package root, không deep import.
- Base URL: `VITE_API_BASE_URL` (constants/urls.ts) → path `/crm/...` resolve thành `/api/v1/crm/...`.
- **Path drift check**: so path trong shared vs OpenAPI — real case: `FINANCE.BANK_TRANSACTIONS = '/finance/bank-transactions'` thiếu prefix `/crm` (BE: `/api/v1/crm/finance/bank-transactions`) → flag cho MFE chủ quản, dù MFE đang audit không dùng.
- Namespace tồn tại nhưng MFE không dùng (vd sale dùng 0 `API_ENDPOINTS.PRODUCT`) → báo cáo "đã check, không dùng" thay vì đoán.

### 5. Endpoint có sẵn nhưng method khác
Check method của path (GET/POST/PUT) trước khi kết luận "không có API" — real case: `/api/v1/crm/partners/{id}/staff` chỉ có POST (create), không có GET list → verifier list FE phải dùng endpoint khác hoặc chờ BE thêm.

## Pitfalls
- Đừng đọc `/docs` HTML làm spec — nó chỉ là shell Scalar.
- Spec 1.4MB: luôn grep/python extract, không `read_file` nguyên file.
- `x-required-permissions` trong OpenAPI là manh mối quyền (vd `crm:customer:transfer_partner`) — hữu ích khi issue hỏi "ai được gọi endpoint này".
- Kết quả contract (schema, query params) nên ghi vào issue/note — dev đỡ phải tự tra lại.

## Related
- `mfe-feature-audit` — audit pass E (cross-MFE endpoint usage) + "Fake-Data Form Field" trap (overlap: kỹ thuật này là phần check contract của audit đó).
- `gitlab-issue-workflow` — cách ghi "BE contract đã xác nhận" vào issue + rule tách issue ready-for-human.
