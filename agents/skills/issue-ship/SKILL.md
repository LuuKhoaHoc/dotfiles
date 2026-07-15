---
name: issue-ship
description: Vòng ship một issue từ code xong đến MR live — update issue description theo diff, sync develop, push atomic, tạo MR.
disable-model-invocation: true
---

# Issue Ship

Ship cycle cho một issue: update → sync → push → MR.

**Prerequisite:** Đang trên feature branch, code đã sẵn sàng commit.

## 1. Update issue description

```bash
git diff --stat HEAD
git status
```

Đọc diff. Dùng MCP GitLab (`update_issue_description_patch` hoặc `update_issue`) để update description của issue được chỉ định — mô tả đúng những gì thực sự thay đổi, không thêm gì không có trong diff.

**Done when:** Issue description phản ánh đủ và đúng các thay đổi thực tế.

## 2. Sync develop

```bash
git fetch origin
git merge origin/develop
```

Nếu có conflict → chạy `/resolving-merge-conflicts`.

**Done when:** `git status` clean, không còn conflict marker, automated checks pass.

## 3. Push

Chạy `/auto-push`.

**Done when:** Branch pushed, commits atomic theo conventional commits, Lefthook hooks pass.

## 4. Tạo MR

Chạy `/pr-to-branch <target-branch>` (mặc định `develop`).

**Done when:** MR URL live, assignee = self, label gắn đúng, pipeline triggered.
