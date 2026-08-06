---
# TTSR rule — time-traveling stream rule cho omp (oh-my-pi)
# Đặt tại: ~/.omp/agent/rules/<name>.md (user) hoặc .omp/rules/<name>.md (project)
# LƯU Ý: key frontmatter là `condition` (regex) hoặc `astCondition` (ast-grep pattern).
# KHÔNG dùng `ttsrtrigger` — docs cũ (mseep) sai, rule sẽ bị drop SILENTLY.
# Verify: `omp ttsr list` và `omp ttsr test '<snippet>'`
condition: "(?i)\\b(example-slop-word|delve|leverage)\\b"
---

# Rule title (ngắn, mệnh lệnh)

Nội dung rule được inject vào stream khi regex match — viết rõ hành vi mong muốn, thay thế bằng gì. Ví dụ:

Viết tự nhiên như người thật: câu ngắn, từ đơn giản, đi thẳng vào nội dung. Không dùng từ/cụm từ AI-slop (delve, leverage, robust, seamless, utilize, "in conclusion", "it's worth noting", ...). Ưu tiên từ ngữ đời thường; code, comment, commit message giữ tiếng Anh nhưng vẫn giản dị.

# Ghi chú
# - `condition` = regex thuần (không cần /.../); dùng (?i) cho case-insensitive, \\b cho word boundary
# - Regex YAML double-quoted: `\\b` trong YAML = `\b` regex
# - Rule không có condition hợp lệ → biến mất khỏi `omp ttsr list` không báo lỗi
# - `scope:` (tuỳ chọn) giới hạn nguồn, vd `tool:edit(*.ts), tool:write(*.ts)`
