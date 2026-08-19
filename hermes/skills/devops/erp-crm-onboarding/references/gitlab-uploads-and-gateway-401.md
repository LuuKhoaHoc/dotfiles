# Fetching issue attachments & verifying BE endpoints (16/08/2026)

## GitLab upload links (`/uploads/<hash>/file`) are login-walled

Issue descriptions reference uploaded docs via `/uploads/<hash>/crm-onboarding-integration-guide.md`.

- `curl` trần → `302` → login page HTML (`<title>Sign in · GitLab</title>`) — không lấy được nội dung.
- `glab api projects/<id>/uploads/<hash>` → `400 {"error":"upload_id is invalid"}` — the uploads API is **write-only** (create uploads), it cannot download by hash.
- **Fallback hiệu quả**: đọc chính issue description — key facts (tên permission đầy đủ, section số) thường đã được nhúng sẵn vào description khi issue được soạn kỹ. Grep issue description trước khi tốn thời gian fetch attachment.
- Chưa thử (đề xuất cho lần sau nếu cần nội dung đầy đủ): fetch với PRIVATE-TOKEN header qua curl, hoặc tải qua web UI login. Ghi nhận: token glab ở `~/.config/glab-cli/config.yml`.

## GATEWAY-401 = endpoint TỒN TẠI (401 ≠ 404)

Curl BE API không token:

```bash
curl -s https://api-erp.vppos.vn/api/v1/crm/authorization/permissions
# {"success":false,"data":null,"error":{"code":"GATEWAY-401","message":"Authorization token not provided"},...}
```

- `GATEWAY-401` từ gateway = route đã đăng ký tồn tại — khác hẳn 404 (route không có). Dùng để xác nhận endpoint tồn tại mà không cần token.
- Không verify được shape/giá trị (vd danh sách permission thật) nếu không có token BE — ghi rõ trong review rằng tên permission dựa trên guide/issue, chưa curl-verified.
- Swagger: `https://api-erp.vppos.vn/docs` trả 200; các path thường (`/openapi.json`, `/api-docs`, `/v3/api-docs`, `/swagger/doc.json`) trả `405 method not allowed`.
