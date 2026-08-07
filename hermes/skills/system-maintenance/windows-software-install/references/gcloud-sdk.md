# Google Cloud SDK — cài trên Windows (đã verify 2026-08, SDK 579.0.0)

## Lệnh cài chính thức (từ Google — dùng đúng lệnh này khi user yêu cầu)
```powershell
(New-Object Net.WebClient).DownloadFile("https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe", "$env:Temp\GoogleCloudSDKInstaller.exe")
& $env:Temp\GoogleCloudSDKInstaller.exe
```

## Sự thật đã kiểm chứng
- **Installer là bootstrapper ~267KB** (Content-Length: 267096), KHÔNG còn là file ~400MB tự chứa như xưa — nó tải component trong lúc cài. Size nhỏ = bình thường, đừng nghi ngờ; verify bằng MZ header (bytes 77 90).
- Thư mục cài mặc định: `%LOCALAPPDATA%\Google\Cloud SDK\google-cloud-sdk\`
- Binary: `%LOCALAPPDATA%\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd` (path CÓ space — phải quote nguyên path)
- Installer tự thêm bin dir vào **User PATH** (không cần admin).

## Verify từ git-bash
```bash
"$LOCALAPPDATA/Google/Cloud SDK/google-cloud-sdk/bin/gcloud.cmd" --version
# → Google Cloud SDK 579.0.0 / bq 2.1.36 / core ... / gsutil 5.37
```
Lưu ý: `cmd //c "\"path\gcloud.cmd\" --version"` VỠ với lỗi `'loud' is not recognized` — chạy thẳng .cmd từ bash như trên.

## Wizard (user bấm tay)
Next → đồng ý license → Next → giữ thư mục mặc định → (bỏ tick component thừa) → Install → chờ tải component vài phút → Finish.
Watch completion: `while tasklist 2>/dev/null | grep -qi GoogleCloudSDKInstaller; do sleep 10; done` (lưu ý tasklist truncate tên → không dùng filter IMAGENAME eq đầy đủ).

## Sau cài
- `gcloud init` (chọn project + region), `gcloud auth login`.
- PATH chỉ áp dụng terminal mới; verify:
  `powershell -NoProfile -Command '[Environment]::GetEnvironmentVariable("Path","User")'`
