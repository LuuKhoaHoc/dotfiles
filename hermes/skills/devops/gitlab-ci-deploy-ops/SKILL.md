---
name: gitlab-ci-deploy-ops
description: "erp-admin GitLab CI: gates, bridges, play jobs, triage."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitLab, CI, Deploy, erp-admin, Pipeline]
    related_skills: ["gitlab-release", "gitlab-issues"]
---

# GitLab CI Deploy Ops (erp-admin / vppos-team)

Vận hành pipeline GitLab để deploy UAT/prod cho `vppos-team/erp-admin` (project id 9) qua `glab` CLI. Bổ sung cho `gitlab-release` (user-owned — skill đó lo flow release, skill này lo thao tác CI).

## Cấu trúc pipeline

- **Parent pipeline** (branch develop/main): scan jobs (sonarqube:scan `allow_failure: true`, trivy:iac) → gate manual (`deploy:uat` trên develop) → trigger jobs.
- **Trigger jobs KHÔNG nằm trong `/pipelines/:id/jobs`** — chúng là *bridges*. Phải đọc qua `/pipelines/:id/bridges`; mỗi bridge có `downstream_pipeline.id` (child pipeline). `pipelines?ref=<branch>` để tìm pipeline mới nhất.

## Thao tác chuẩn (glab API)

```bash
# Pipeline mới nhất theo branch
glab api "projects/vppos-team%2Ferp-admin/pipelines?ref=develop&per_page=1"

# Job manual (gate) trong parent
glab api "projects/vppos-team%2Ferp-admin/pipelines/<pid>/jobs?per_page=100"   # filter status=manual

# Play gate deploy:uat → triggers TỰ chạy (không cần play từng cái)
glab api --method POST "projects/vppos-team%2Ferp-admin/jobs/<job_id>/play"

# Bridges + child pipelines
glab api "projects/vppos-team%2Ferp-admin/pipelines/<pid>/bridges"
glab api "projects/vppos-team%2Ferp-admin/pipelines/<child_pid>"   # status

# Log job failed
glab api "projects/vppos-team%2Ferp-admin/jobs/<job_id>/trace"
```

- **Changes rules**: child triggers chỉ chạy cho MFE bị đụng (`apps/hr/**/*` → chỉ `trigger:hr`). Deploy 1 fix HR = 1 child pipeline duy nhất — tiết kiệm runner.
- **Main (prod)**: merge vào main → triggers tự chạy (không gate); child pipeline có job `deploy:app` **manual** → play sau khi build xong.
- Verify UAT sau deploy: UAT host thật = `https://erp.hilo.com.vn/apps/<mfe>/` (vd `/apps/hr/`, `/apps/employee/`) — ingress host trong `helm/frontend/values-*.yaml`. `hr-uat-erp.vppos.vn` KHÔNG phải domain UAT (sai — 502/000). 502 trong vài phút đầu là rollout bình thường, không phải lỗi (pod đang restart).

## Pitfall: pipeline fail vì branch bị xóa (VÔ HẠI)

MR merge mặc định **xóa source branch** (GitLab delete_source_branch). Pipeline CŨ của branch đó (trigger lúc push, chạy SAU merge) fail ở job đầu với:

```
fatal: couldn't find remote ref refs/heads/<branch>
```

→ KHÔNG phải lỗi code, KHÔNG tạo lại branch. Pipeline branch đã hoàn thành sứ mệnh (MR merged); pipeline main (deploy thật) không dính. Verify: `git ls-remote origin <branch>` rỗng + MR state merged. Trường hợp thật: pipeline 14321 của `release/v1.0.1` fail 2 child (product/sale) sau khi MR !568 merged.

## Pitfall: glab output JSON

- `glab mr view <iid> --output json` đôi khi trả state CŨ (cache) ngay sau merge — poll lại sau vài giây hoặc verify qua `git ls-remote`/pipeline SHA.
- `glab api user --jq .username` KHÔNG chạy trên Windows/MSYS glab — dùng `glab api user` (raw JSON) hoặc hardcode username đã biết (`luukhoahoc`).
- Merge MR chờ pipeline: `glab mr merge <iid> --when-pipeline-succeeds` — chạy background + `notify_on_complete` (block lâu).
- **MWPS merges IMMEDIATELY nếu pipeline ĐÃ green** (real case 2026-08-10: `PUT /merge?merge_when_pipeline_succeeds=true` trên MR !576 merged tức thì vì pipeline 14537 đã success — user vừa gửi "khoan merge"). Luôn check pipeline MR trước khi đặt MWPS (`/pipelines` của MR); nếu status đã `success` thì merge là tức thì, KHÔNG có window hủy. Muốn giữ MR mở: đừng đặt MWPS khi pipeline đã xong.
- Python trên Windows không đọc path MSYS `/tmp/...` — dùng file trong repo (xóa sau) hoặc `$(cygpath -w ...)`.

## Milestone & issue lifecycle (kèm deploy)

- Tạo milestone `vX.Y.Z` (due = deadline trả lương/phát hành) + description chứa scope (issue refs) + release checklist NGAY khi bắt đầu release; gắn issue vào milestone lúc tạo.
- **Bug mới khi milestone CHƯA release** → gộp vào cùng version (vd v1.0.2), KHÔNG bump thêm. Chỉ bump khi version trước đã có tag + Release record.
- Issue OPEN khi merge develop (label `status::done` qua job `issue:lifecycle:merge`) → **close SAU prod deploy**; milestone close sau cùng (mọi checklist hoàn tất) — close sớm gây hiểu nhầm "đã release".
- Closeout release record: GET `/releases/<tag>` → tick checklist bằng python replace (idempotent, giữ CRLF) → PUT với description mới.
