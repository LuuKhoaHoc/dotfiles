---
name: hilo-erp-hrm
description: Answer questions about the Hilo ERP HRM project sitemap. Ground responses in sitemap structure, module flows, and real-world ERP/HRM best practices. Use when user asks about Hilo ERP modules, workflows, design gaps, or BA feedback.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [erp, hrm, sitemap, hilo, vietnamese]
    related_skills: []
---

# Hilo ERP HRM — Project Skill

## Quick Start

When user asks about Hilo ERP:
1. Load this skill
2. Ground answer in sitemap structure
3. Reference sitemap section/module
4. Apply ERP best practice check if reviewing design

## Project Context

**File:** `C:\Users\luukhoahoc\Dev-Work\Hilo\ERP-Sitemap.md`
**User role:** Frontend Lead
**Language:** Vietnamese responses, technical terms in English where standard

### Sitemap Structure Overview

```
DANH MỤC - HRM Phase 1
├── 1. DASHBOARD
├── 2. TỔ CHỨC VÀ ĐỊNH BIÊN
│   ├── 2.1 Đơn vị tổ chức (Org Units)
│   ├── 2.2 Nhóm nghề nghiệp (Job Families)
│   ├── 2.3 Chức danh (Job Titles)
│   ├── 2.4 Ngạch chức danh (Job Levels/Grades)
│   ├── 2.5 Dải lương/Band (Salary Bands)
│   ├── 2.6 Vị trí (Positions)
│   ├── 2.7 Kế hoạch định biên (Headcount Planning)
│   └── 2.8 Sơ đồ tổ chức (Org Chart)
├── 3. HỒ SƠ NHÂN VIÊN (Employee Master Data)
├── 4. HỢP ĐỒNG LAO ĐỘNG (Labor Contracts)
├── 5. CẤU HÌNH HRM
│   ├── 5.1 Cấu hình tổ chức
│   ├── 5.2 Cấu hình lịch/ca làm việc
│   ├── 5.3 Cấu hình chấm công
│   ├── 5.4 Cấu hình nghỉ phép
│   ├── 5.5 Cấu hình yêu cầu làm việc
│   ├── 5.6 Cấu hình lương
│   ├── 5.7 Cấu hình thông báo
│   ├── 5.8 Cấu hình phân quyền HRM
│   ├── 5.9 Cấu hình đánh giá
│   └── 5.10 Cấu hình KPI & Hiệu suất
├── 6. NGHỈ PHÉP VÀ QUỸ PHÉP
├── 7. YÊU CẦU CÔNG VIỆC ĐẶC THÙ (OT, WFH, Công tác...)
├── 8. CHẤM CÔNG
├── 9. THAY ĐỔI PHÂN CÔNG
├── 10. BẢNG LƯƠNG (Payroll)
├── 11. KPI VÀ HIỆU SUẤT
├── 12. BẢO HIỂM VÀ THUẾ TNCN
├── 13. ONBOARDING
├── 14. OFFBOARDING
├── 15. ĐÁNH GIÁ NHÂN VIÊN
├── 16. ĐÀO TẠO
├── 17. QUẢN LÝ TÀI SẢN NHÂN SỰ
└── 18. KHEN THƯỞNG - KỶ LUẬT
```

## Answering Questions

**When user asks about a specific module:**
→ Navigate to that section in the sitemap
→ Explain current design
→ Identify any gaps vs ERP best practices

**When user asks for BA feedback:**
→ Use ERP best practice checklist
→ Flag missing validations, integrations, or workflow gaps
→ Be specific: which step, what is missing, why it matters

**When user asks to review design:**
→ Load sitemap section
→ Apply validation rules from Section below
→ List findings with severity: MUST FIX / SHOULD FIX / NICE TO HAVE

## ERP Best Practice Validation Rules

### Universal HR Master Data Rules

1. **Position vs Person separation** — Position is a "seat", Person fills it. Never conflate. A position can be vacant; a person has only one primary position.
2. **Effective dating** — All organizational changes (unit hierarchy, position assignment, manager changes) must have effective_from/effective_to dates. Never overwrite historical data.
3. **Immutable audit trail** — Every create/update/delete must be logged with before/after values, actor, timestamp. No hard deletes.
4. **DAG validation** — Org hierarchy must be a directed acyclic graph. Circular manager relationships are invalid.
5. **Cost center → Position → Person flow** — Cost center assigned to position, not directly to person. Payroll aggregates by cost center.

### Module-Specific Rules

#### Attendance (Section 8)
- GPS validation must compare against known-valid location radius, not just accept any coordinates
- Auto-checkout requires clear rule: based on scheduled shift end, or last check-in + minimum hours?
- OT validation: OT must be pre-approved OR have policy allowing post-fact. Never auto-generate OT without policy reference.
- **Missing in sitemap:** What happens if employee checks in on wrong day? What is the de-duplication rule for duplicate check-in records?
- **Missing in sitemap:** How does the system handle shift changes mid-period? Does it re-calculate all prior days?

#### Leave Management (Section 6)
- Leave balance must be calculated as of request date, not effective date
- Leave type → leave balance → leave request → leave approval → attendance update flow is correct
- Negative balance: allow with policy flag or block?
- **Missing in sitemap:** What if approved leave crosses month boundary? Does it split into 2 attendance records?
- **Missing in sitemap:** Carry-forward validation: what happens to balance at year-end?

#### Employee Master Data (Section 3)
- Employee is the CENTER of the system. All modules (attendance, payroll, contracts, KPI, training, asset) must reference employee_id as foreign key.
- Snapshot principle: when employee transfers departments, historical records must retain the original department at time of record, not updated retroactively.
- **Missing in sitemap:** What is the deactivation flow? Does deactivating an employee cascade to disable all system access?

#### Contracts (Section 4)
- Contract should snapshot position, salary, department at time of signing — not reference live employee fields.
- Contract status transitions: Draft → Signed → Active → Expired/Terminated. Each transition has a date.
- **Missing in sitemap:** How does the system handle contract renewal? Auto-create renewal draft? Link to prior contract?

#### Payroll (Section 10)
- Payroll inputs: attendance data (days worked, OT hours, late minutes) + salary components + deductions.
- Payroll is period-based (monthly). All inputs must be locked before payroll runs.
- **Missing in sitemap:** What is the payroll approval workflow? Who approves before payment?

#### Onboarding/Offboarding (Sections 13-14)
- Onboarding tasks should be relative to employee start date (e.g., "Day -3: Send welcome email", "Day 0: Setup workstation", "Day +7: Complete compliance training")
- Offboarding should follow saga pattern: for each step (payroll final, IT deprov, asset return, benefits close), if a step fails, compensate previous steps.
- **Missing in sitemap:** Is there a dependency chain in onboarding tasks? (e.g., cannot issue laptop until account is created)

## Common Design Gaps in Vietnamese ERP Specs

| Gap | Impact | ERP Standard |
|-----|---------|-------------|
| No effective dating on org changes | Historical reports wrong | All org changes dated |
| Person ↔ Position conflation | Vacancy tracking broken | Separate entities |
| No audit trail | Compliance risk | Immutable before/after log |
| Salary stored directly on employee | Retroactive changes affect history | Salary on contract/position with effective dates |
| No data locking before payroll | Payroll can change mid-run | Lock attendance → run payroll → unlock |
| Approval workflow lacks escalation | Bottleneck = process stop | SLA-based escalation |
| No orphan detection | Employee without org unit | FK constraint + validation |

## How to Reference the Sitemap

The full sitemap lives at:
`C:\Users\luukhoahoc\Dev-Work\Hilo\ERP-Sitemap.md`

Use `read_file` to load relevant sections when answering detailed questions.

When discussing a module, always:
1. Quote the relevant sitemap section name
2. Note what is well-designed
3. Flag what is missing or ambiguous
4. Propose specific BA change

## Gaps Already Identified in Sitemap

These are areas where the sitemap is silent or ambiguous — suggest BA clarification:

- **Employee master data:** No mention of employee deactivation/termination flow
- **Attendance:** No de-duplication rule for duplicate check-in records  
- **Leave balance:** No year-end carry-forward/cancellation rule defined
- **Payroll:** No data locking mechanism before payroll run
- **Contracts:** No contract renewal workflow specified
- **Onboarding:** No task dependency chain (parallel vs sequential tasks unclear)
- **Offboarding:** No compensation/saga pattern for failed offboarding steps
- **Org hierarchy:** No explicit validation for circular manager relationships
- **Position vs Person:** The sitemap mixes "vị trí" (position) with employee assignments — need explicit separation
- **Effective dating:** Org changes appear to overwrite rather than add effective-dated records
