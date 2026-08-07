---
name: windows-software-install
description: Use when installing Windows software via terminal.
---

# Windows Software Install (from git-bash)

Cài/upgrade phần mềm trên máy Windows của user qua Hermes terminal (bash/MSYS — KHÔNG phải PowerShell). Áp dụng cho: gcloud, CLIs, bất kỳ .exe installer chính thức nào.

## Rules
1. **User đưa lệnh cài chính thức → chạy ĐÚNG lệnh đó qua powershell**, không tự thay bằng curl/approach riêng. Lệnh chính thức (vd từ Google) là đường đã biết là chuẩn; user sẽ nhắc lại nếu ta làm khác.
2. GUI installer: launch cho user tự bấm qua wizard; KHÔNG tự ý thêm silent flag trừ khi user yêu cầu.
3. Sau install luôn verify: lệnh version + PATH. Báo evidence cụ thể (version, thư mục).

## Chạy PowerShell từ git-bash
Pattern đã kiểm chứng:
```bash
powershell -NoProfile -ExecutionPolicy Bypass -Command '(...)'
```
- Ngoài dùng **single quote** của bash; bên trong dùng double quote cho PS string (ví dụ `"$env:Temp\x.exe"` — `$env` giữ nguyên cho PS).
- Tránh lồng `cmd //c` với path có space (xem Pitfalls).

## GUI installer flow
1. Download bằng lệnh chính thức (PowerShell WebClient hoặc curl).
2. Verify file exe: `curl -sI <url> | grep -i content-length` so với size local; 2 bytes đầu phải là `MZ` (77 90) = PE hợp lệ. **Size nhỏ là BÌNH THƯỜNG**: installer mới của Google Cloud SDK là bootstrapper ~267KB, tự tải component lúc cài.
3. Launch (trả về ngay, GUI hiện trên màn hình user):
```bash
powershell -NoProfile -ExecutionPolicy Bypass -Command 'Start-Process -FilePath "$env:Temp\Installer.exe"'
```
4. Báo user các bước cần bấm, rồi watch completion ở background:
```bash
while tasklist 2>/dev/null | grep -qi InstallerShortName; do sleep 10; done; echo DONE
```
(background=true + notify_on_complete=true; `ls "$LOCALAPPDATA/Google"` sau đó để xác nhận thư mục cài)

## Pitfalls
- **`tasklist //FI "IMAGENAME eq X.exe"` không match**: tasklist truncate tên image về 15 ký tự (vd `GoogleCloudSDKInstaller.e`). Dùng `tasklist | grep -i <shortname>`.
- **`cmd //c "C:\path có space\prog.cmd args"` vỡ** (lỗi `'loud' is not recognized` — bash→cmd nuốt quote quanh space). Chạy thẳng .cmd từ bash với path quoted:
  ```bash
  "$LOCALAPPDATA/Google/Cloud SDK/google-cloud-sdk/bin/gcloud.cmd" --version
  ```
  (git-bash tự execute .cmd qua cmd.exe OK)
- **curl -o /tmp/x.exe báo success mà file không có**: download thực sự fail (bash /tmp = Windows temp). Đừng vật lộn — fallback sang lệnh PowerShell chính thức của user.
- PATH đổi chỉ áp dụng terminal MỚI; verify user PATH bằng:
  ```bash
  powershell -NoProfile -Command '[Environment]::GetEnvironmentVariable("Path","User")' | tr ';' '\n' | grep -i <vendor>
  ```

## Verify
- Version: chạy binary/script với full path quoted.
- PATH: check user-level như trên; đảm bảo bin dir của phần mềm có mặt.
- Báo user: version + thư mục cài + bước tiếp theo (vd `gcloud init`).

Chi tiết Google Cloud SDK: references/gcloud-sdk.md
