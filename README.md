# EduBoard

Phần mềm học tập, giảng dạy và quản lý lớp học cho giáo viên, học sinh, phụ huynh và nhà trường.
Kế hoạch chi tiết: hai file Word/Excel `Ke_hoach_du_an_phan_mem_hoc_tap` đặt cùng thư mục.

## Viết bằng gì

| Phần | Công nghệ | Trạng thái |
|---|---|---|
| Backend (máy chủ API) | TypeScript, NestJS 11, TypeORM | Đã có: đăng nhập, phân quyền, lớp, TKB, họp, bảng trắng thời gian thực, bài tập và chấm điểm |
| Cơ sở dữ liệu | PostgreSQL (thật), SQLite (chạy thử, không cần cài) | Xong |
| Họp video | LiveKit (WebRTC) | Backend cấp phòng và token xong; giao diện video chưa làm |
| App điện thoại + máy tính | Flutter (Dart), một mã nguồn cho Android, iOS, Windows, macOS, web | Đã có: đăng nhập, lớp, TKB, phòng học + bảng trắng, bài tập (thư mục `app`) |
| Bảng trắng, AI nhận diện nét | Flutter, thuật toán hình học (chữ viết tay: ML Kit ở giai đoạn sau) | Đã có: vẽ tay, nắn hình học và đồ thị sin, đồng bộ thời gian thực giữa giáo viên và học sinh |

## Chạy thử trên Windows (cách nhanh nhất)

1. Cài **Node.js bản LTS** từ https://nodejs.org (chỉ cần làm một lần).
2. Bấm đúp file **`chay-thu.bat`**. Lần đầu sẽ mất vài phút để tải thư viện.
3. Trình duyệt tự mở **http://localhost:3000**: giao diện app EduBoard. Bấm nút "Giáo viên", "Học sinh"... để đăng nhập nhanh.
   Trang **http://localhost:3000/docs** dùng để xem và thử từng API.

Không cần cài cơ sở dữ liệu: bản chạy thử lưu vào file `backend/eduboard-demo.sqlite` và tự tạo dữ liệu mẫu.
Muốn làm lại từ đầu thì xóa file đó rồi chạy lại.

### Tài khoản mẫu (mật khẩu đều là `demo1234`)

| Email | Vai trò |
|---|---|
| admin@demo.vn | Admin |
| giaovien@demo.vn | Giáo viên lớp Toán 10A1 |
| hocsinh1@demo.vn, hocsinh2@demo.vn | Học sinh đã vào lớp |
| hocsinh3@demo.vn | Học sinh đang chờ duyệt |
| phuhuynh@demo.vn | Phụ huynh của hocsinh1 |

### Thử trong app

1. Đăng nhập Giáo viên → Toán 10A1 → tab Cuộc họp → Mở phòng.
2. Bật "AI làm đẹp nét", vẽ tay một vòng tròn, tam giác, đường lượn sóng: app tự nắn lại cho gọn.
3. Bấm biểu tượng quyền viết (góc trên) để cho học sinh viết lên bảng.
4. Mở thêm một cửa sổ ẩn danh (Ctrl+Shift+N), đăng nhập Học sinh, vào cùng cuộc họp: giáo viên vẽ đến đâu học sinh thấy ngay đến đó; khi được cấp quyền, học sinh vẽ thì giáo viên cũng thấy.

### Thử trên trang /docs

1. Mở `POST /api/auth/login` → **Try it out** → nhập email, mật khẩu → **Execute**. Sao chép `accessToken`.
2. Bấm nút **Authorize** ở đầu trang, dán token, bấm **Authorize**.
3. Thử các API khác, ví dụ `GET /api/classes`, `GET /api/timetable/week` (nhập date = 2026-12-09), `POST /api/meetings/{id}/join`.
4. Đăng nhập bằng tài khoản khác để thấy mỗi vai trò nhìn thấy dữ liệu khác nhau.

## Chạy bằng dòng lệnh

```bash
cd backend
npm install
npm run demo        # chạy thử (SQLite + dữ liệu mẫu) → http://localhost:3000/docs
npm run dev         # chế độ phát triển
```

Môi trường thật dùng PostgreSQL: chép `.env.example` thành `.env`, bỏ dấu `#` ở các dòng `DATABASE_URL`, `JWT_SECRET`, `ADMIN_*`.
Có Docker thì `docker compose up -d db` để bật PostgreSQL.

Họp video thật cần máy chủ LiveKit: tải `livekit-server` tại https://github.com/livekit/livekit/releases rồi chạy `livekit-server --dev`.
Giao diện họp sẽ có khi làm app Flutter.

### Test tự động

```bash
TEST_DB=sqlite npm test      # không cần PostgreSQL
npm test                     # trên PostgreSQL, database eduboard_test (bị xóa mỗi lần chạy)
```

## API

Mọi route (trừ đăng ký, đăng nhập) cần header `Authorization: Bearer <accessToken>`. Danh sách đầy đủ, có thể bấm thử, nằm ở `/docs`.

| Nhóm | Chức năng |
|---|---|
| Đăng nhập | Đăng ký (học sinh, giáo viên, phụ huynh), đăng nhập, xem tài khoản |
| Người dùng | Admin quản lý tài khoản, đổi vai trò, liên kết phụ huynh với học sinh |
| Lớp học | Tạo lớp có mã mời, học sinh xin vào lớp, giáo viên duyệt hoặc từ chối, đổi mã mời |
| Thời khóa biểu | Tiết lặp hằng tuần, chặn giáo viên trùng giờ, xem lịch theo tuần cho mọi vai trò |
| Họp trực tuyến | Tạo/lên lịch họp, vào phòng (nhận token LiveKit), giáo viên mở và kết thúc phòng |
| Bài tập | Giáo viên giao bài (hạn nộp, điểm tối đa), học sinh nộp/nộp lại khi chưa chấm, tự đánh dấu nộp muộn, giáo viên chấm điểm + nhận xét, phụ huynh xem điểm của con |
| Bảng trắng | Giáo viên cấp/thu quyền viết cho từng học sinh hoặc cả lớp. Đồng bộ nét vẽ qua WebSocket `ws://<máy chủ>/ws/board?meetingId=&token=` |

Quy tắc phân quyền chính:
- Admin thấy mọi lớp. Giáo viên thấy lớp mình dạy. Học sinh thấy lớp đã được duyệt. Phụ huynh thấy lớp của con.
- Học sinh chỉ vào phòng họp khi giáo viên đã mở phòng. Phụ huynh không vào phòng học.
- Học sinh mặc định không viết được lên bảng. Khi kết thúc họp, mọi quyền viết bị thu lại.

## Ghi chú kỹ thuật

- Mật khẩu băm bằng bcrypt, đăng nhập bằng JWT.
- `DB_SYNC=true` tự tạo bảng, chỉ dùng cho dev/test. Trước khi lên production cần chuyển sang migration.
