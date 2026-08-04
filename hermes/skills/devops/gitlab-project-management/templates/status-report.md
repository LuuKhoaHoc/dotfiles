# Báo cáo tình hình dự án <Tên dự án> — <DD/MM/YYYY>

> Nguồn dữ liệu: GitLab `<group>/<project>` (số liệu snapshot lúc <giờ>)

## 1. Tổng quan

| Chỉ số | Giá trị |
|---|---|
| Milestone đang chạy | **<Tên>** (<start> → <due>) |
| Issue đang mở | N (x đã xong code nhưng chưa đóng, y in-progress, z blocked...) |
| MR đang mở | N (bao nhiêu mergeable) |
| MR đã merge N tuần qua | N |
| Release gần nhất | <ngày> |

1-2 câu nhận định nhịp delivery (vd: ~3 MR/ngày, đang chuyển mock → real API).

## 2. Tiến độ milestone <X> (deadline <ngày>)

- Tổng N issues → **x đóng / y mở**; phân bổ theo module (bảng hoặc liệt kê).
- Điểm sáng đã ship gần đây (MR merged: `!iid` + 1 dòng mô tả).
- ⚠️ Nếu có nhiều issue "status::done nhưng chưa đóng" → ghi chú số liệu thực tế cao hơn con số đóng issue.

## 3. Tồn đọng cần xử lý

### MR mở
| MR | Nội dung | Người | Ghi chú |
|---|---|---|---|
| !iid | ... | ... | mergeable / chờ review / **treo từ <ngày>** |

### Issue chưa gán người (N)
- Liệt kê, đánh dấu cái nào thuộc scope milestone hiện tại (gán sớm) vs priority thấp (dời sau).

### Issue bị blocked (N) — cần BE phối hợp
- `#iid` <tiêu đề> (assignee) — thường là chờ BE API/endpoint.

## 4. Rủi ro & điểm cần quyết định (cho buổi họp PO + CTO)

1. Deadline milestone vs tiến độ thực tế (số issue mở, task blocked chờ BE).
2. Issue chưa gán người — đề xuất phân bổ.
3. MR treo lâu ngày — cần quyết định merge/đóng.
4. Issue "done nhưng chưa đóng" làm lệch số liệu — đề xuất buổi rà soát đóng issue.
5. Bug/fix mở — chờ PO xác nhận ưu tiên.

## 5. Điểm sáng

- Release hàng tuần ổn định / tính năng X đã lên main / mảng Y gần hoàn thiện luồng chính.
