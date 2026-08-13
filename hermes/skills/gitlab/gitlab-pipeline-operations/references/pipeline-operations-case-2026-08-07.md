# Case 2026-08-07 — Release v1.0.0 pipeline operations

Chronology của session release v1.0.0 đầu tiên (SemVer) trên erp-admin, minh họa mọi pitfall trong SKILL.md.

## Timeline

| Time (UTC+7) | Event |
|---|---|
| 07:53 | Push `release/v1.0.0` (lần 1, commit d4d5039) → pipeline push #14123 created |
| 07:57 | GitLab auto-create MR !566 khi push branch; push pipeline #14133 (commit 1df6eac9) |
| 08:01 | `create_merge_request` → **409** "Another open merge request already exists for this source branch: !566" → get + update MR !566 |
| 08:28 | #14133 **auto-canceled** (GitLab hủy pipeline cũ khi có pipeline mới hơn cho cùng SHA — MR pipeline #14138 success) |
| 08:29 | Merge MR !566 → main (merge commit fe0bb444) |
| 09:09 | Sau khi user set `DRY_RUN=false` (project CI/CD variable): `POST /pipelines/14133/retry` → **no-op** (trả pipeline vẫn `canceled`) → `POST /projects/9/pipeline?ref=release/v1.0.0` → pipeline mới #14189 |
| 09:09+ | `GET /pipelines/14189/jobs` chỉ trả **1 job** (`issue:lifecycle:prod`, created) — trigger jobs ẩn; job chờ runner (runner bận build main pipeline) |

## Key observations

1. **Retry no-op:** `POST /pipelines/14133/retry` trả về nguyên pipeline id 14133 với `status: canceled`, không có pipeline mới, không lỗi. Pipeline bị auto-cancel không retry được → tạo pipeline mới qua `POST /pipeline?ref=`.
2. **Variable snapshot:** `DRY_RUN=false` được user thêm vào project variables SAU khi #14181 (pipeline tạo lúc 08:5x) được tạo → #14181 không nhận variable mới. #14189 tạo sau khi set variable → nhận `DRY_RUN=false`. Phải set variable TRƯỚC rồi mới tạo pipeline.
3. **Jobs API vs statuses:** `GET /pipelines/14133/jobs` sau cancel chỉ còn 1 job (`issue:lifecycle:prod`, skipped) dù pipeline lúc chạy có 7 `trigger:*` jobs (thấy qua `list_commit_statuses`). Trigger jobs không hiện trong jobs endpoint.
4. **Cancel async:** `POST /pipelines/14181/cancel` trả `status: running`; re-fetch sau ~10s → `canceled`.
5. **Runner:** 1 instance runner duy nhất (id=2) tag `erp-admin`, online — job post-deploy chờ vì runner bận build 7 MFE. `GET /projects/9/runners` hiện `tag_list: None` nhưng `GET /runners/2` hiện đủ tags.

## Actions thực tế đã chạy (curl)

```bash
TOKEN=$(cat ~/.config/glab-cli/config.yml | grep -oP '(?<=token: ).*' | head -1)

# Retry (no-op trên canceled):
curl -s -X POST -H "PRIVATE-TOKEN: $TOKEN" "https://gitlab.vppos.vn/api/v4/projects/9/pipelines/14133/retry"

# Tạo pipeline mới trên branch:
curl -s -X POST -H "PRIVATE-TOKEN: $TOKEN" --data "ref=release/v1.0.0" "https://gitlab.vppos.vn/api/v4/projects/9/pipeline"

# Cancel (async):
curl -s -X POST -H "PRIVATE-TOKEN: $TOKEN" "https://gitlab.vppos.vn/api/v4/projects/9/pipelines/14181/cancel"

# Jobs + statuses:
curl -s -H "PRIVATE-TOKEN: $TOKEN" "https://gitlab.vppos.vn/api/v4/projects/9/pipelines/14189/jobs"
curl -s -H "PRIVATE-TOKEN: $TOKEN" "https://gitlab.vppos.vn/api/v4/projects/9/pipelines/14189/statuses"

# Runner:
curl -s -H "PRIVATE-TOKEN: $TOKEN" "https://gitlab.vppos.vn/api/v4/projects/9/runners"
curl -s -H "PRIVATE-TOKEN: $TOKEN" "https://gitlab.vppos.vn/api/v4/runners/2"
```

## Context release (bối cảnh)

- Release flow đầy đủ (branch/tag/MR/merge/sync): skill `gitlab-release` (user-owned).
- `issue:lifecycle:prod` chỉ chạy trên branch `release/v*` (rules `.gitlab-ci.yml` dòng ~272); job này `DRY_RUN: "true"` mặc định trong YAML; deploy jobs trên release/v* là manual + `allow_failure: false` để chặn lifecycle cho tới khi prod deploy xong.
- Verify "deploy từ main sau merge == code release": `git diff <release-head> <merge-commit>` trống (merge commit tree = source branch tree) — dùng để trấn an khi user deploy nhầm pipeline.
