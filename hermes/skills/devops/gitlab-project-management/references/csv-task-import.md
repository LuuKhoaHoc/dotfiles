# CSV Task Import Format for Lark

## Column Header (19 columns)

```csv
Thời gian,Task đang làm,Dự án,Nền tảng,Tính năng,Loại công việc,Trạng thái,Ngày bắt đầu,Deadline (PM),Ngày hoàn thành thực tế,⚠️ Trễ hạn,Vai trò,Người thực hiện,Chi tiết công việc,Tuần - Tháng/Năm,Ghi chú,Parent items 5,Các mục mẹ 6,Link
```

## Column Definitions

| # | Column | Format | Example |
|---|---|---|---|
| 1 | Thời gian | `"Thứ X, DD/MM/YYYY đến Thứ Y, DD/MM/YYYY - Tuần N"` | `"Thứ 2, 20/07/2026 đến Thứ 4, 29/07/2026 - Tuần 30"` |
| 2 | Task đang làm | Task name | `TASK-1.2 - Customer management` |
| 3 | Dự án | Project identifier | `0. ERP` / `1. VPPOS` |
| 4 | Nền tảng | Platform | `Website` / `Mobile Application` / `MiniApp / Webview` |
| 5 | Tính năng | Feature name (short) | `TASK-1.2 - Customer management` |
| 6 | Loại công việc | Work type | `Xây dựng tính năng` / `Tài liệu` / `Meeting` |
| 7 | Trạng thái | Status | `Chưa thực hiện` / `Đang thực hiện` / `Hoàn thành` |
| 8 | Ngày bắt đầu | `DD/MM/YYYY` | `20/07/2026` |
| 9 | Deadline (PM) | `DD/MM/YYYY` | `29/07/2026` |
| 10 | Ngày hoàn thành thực tế | `DD/MM/YYYY` | empty if not done |
| 11 | ⚠️ Trễ hạn | Status indicator | `⏳ CHƯA ĐẾN NGÀY BẮT ĐẦU` / `⚠ ĐẾN HẠN HÔM NAY` / `✅ HOÀN THÀNH ĐÚNG HẠN` |
| 12 | Vai trò | Role | `FE` / `BE` / `Design` / `BA` / `QC` / `DevOps` |
| 13 | Người thực hiện | Person name | `Lưu Khoa Học` |
| 14 | Chi tiết công việc | Full task description | Same as Task đang làm (or expanded) |
| 15 | Tuần - Tháng/Năm | Week reference | `Tuần 30 - 20/07... Q3/2026` |
| 16 | Ghi chú | Notes | Empty or free text |
| 17 | Parent items 5 | Phase/group | `Phase 1` / `Phase 2` |
| 18 | Các mục mẹ 6 | Parent group | Same as Parent items 5 |
| 19 | Link | GitLab URL | `https://gitlab.vppos.vn/vppos-team/erp-admin/-/work_items/18` |

## Standard Values — ERP Project

```python
STANDARD_VALUES = {
    "dự án": "0. ERP",
    "nền tảng": "Website",  # for MFE web apps
    "loại_công_việc": "Xây dựng tính năng",
    "trạng_thái": "Chưa thực hiện",
    "trễ_hạn": "⏳ CHƯA ĐẾN NGÀY BẮT ĐẦU",
}
```

## Time Range Format

```
"Thứ <day_num>, <DD/MM/YYYY> đến Thứ <day_num>, <DD/MM/YYYY> - Tuần <week>"
```

Day name mapping:
- Monday → Thứ 2
- Tuesday → Thứ 3
- Wednesday → Thứ 4
- Thursday → Thứ 5
- Friday → Thứ 6
- Saturday → Thứ 7
- Sunday → Chủ nhật

## Week Calculation

```python
from datetime import date

def get_week_info(d: date) -> tuple[int, str]:
    """Returns (week_number, week_range_string)"""
    week = d.isocalendar()[1]
    monday = d - timedelta(days=d.weekday())
    sunday = monday + timedelta(days=6)
    q = (d.month - 1) // 3 + 1
    return week, f"Tuần {week} - {monday.strftime('%d/%m')}... Q{q}/{d.year}"
```

## GitLab Link Format

```
https://<host>/<group>/<project>/-/work_items/<iid>
```

Example: `https://gitlab.vppos.vn/vppos-team/erp-admin/-/work_items/18`
