# EduBoard

Phần mềm học tập, giảng dạy và quản lý lớp học cho giáo viên, học sinh, phụ huynh và nhà trường.
Kế hoạch chi tiết: hai file Word/Excel `Ke_hoach_du_an_phan_mem_hoc_tap` đặt cùng thư mục.

## Viết bằng gì

| Phần | Công nghệ | Trạng thái |
|---|---|---|
| Backend (máy chủ API) | TypeScript, NestJS 11, TypeORM | Đã có: đăng nhập, phân quyền, lớp, TKB, họp, bảng trắng thời gian thực, bài giảng và file, bài tập và chấm điểm, kiểm tra trắc nghiệm tự chấm, thông báo |
| Cơ sở dữ liệu | PostgreSQL (thật), SQLite (chạy thử, không cần cài) | Xong |
| Họp video | LiveKit (WebRTC) | Đã có: camera, micro, chia sẻ màn hình, khung hình người tham gia |
| App điện thoại + máy tính | Flutter (Dart), một mã nguồn cho Android, iOS, Windows, macOS, web | Đã có: đăng nhập, lớp, TKB, phòng học + bảng trắng, bài giảng có file, bài tập (nộp kèm file), kiểm tra trắc nghiệm, thông báo (thư mục `app`) |
| Bảng trắng, AI nhận diện nét | Flutter, thuật toán hình học và bộ nhận diện ký hiệu $P chạy ngay trên máy (không cần mạng) | Đã có: vẽ tay, nắn hình học và đồ thị sin, đọc chữ số, chữ và ký hiệu toán (phân số, căn, số mũ, ∫, π, Σ, ∞…) rồi viết lại cho gọn, đồng bộ thời gian thực |

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
2. Chọn "AI hình", vẽ tay một vòng tròn, tam giác, đường lượn sóng: app tự nắn lại cho gọn.
   Chọn "AI chữ & toán", viết ví dụ `y = x² + 1`, một phân số hay căn bậc hai rồi dừng tay khoảng 1 giây: app đọc biểu thức (hiện ở dưới màn hình) và viết lại ngay ngắn, thẳng hàng. Bấm "Giữ nét gốc" nếu muốn giữ chữ viết tay.
3. Bấm biểu tượng quyền viết (góc trên) để cho học sinh viết lên bảng.
4. Mở thêm một cửa sổ ẩn danh (Ctrl+Shift+N), đăng nhập Học sinh, vào cùng cuộc họp: giáo viên vẽ đến đâu học sinh thấy ngay đến đó; khi được cấp quyền, học sinh vẽ thì giáo viên cũng thấy.
5. Tab **Kiểm tra**: giáo viên bấm "Soạn đề", đánh dấu đáp án đúng (một hoặc nhiều), đặt thời gian làm bài rồi "Phát hành". Học sinh (thử hocsinh2@demo.vn, vì hocsinh1 đã làm sẵn) bấm "Bắt đầu làm bài": có đồng hồ đếm ngược, hết giờ tự nộp, nộp xong thấy điểm và đáp án ngay. Giáo viên xem điểm từng em và tỉ lệ làm đúng từng câu.

6. Đăng nhập **Admin** → mục **Quản trị**: xem số liệu, tìm và khóa thử một học sinh (học sinh đó sẽ không đăng nhập được nữa cho tới khi mở khóa), liên kết phụ huynh với học sinh.

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

Họp video cần máy chủ LiveKit. Bản Windows đã có sẵn ở `tools\livekit-server.exe` và `chay-thu.bat` tự bật nó
(nếu Windows hỏi tường lửa thì chọn Allow). Máy khác: tải tại https://github.com/livekit/livekit/releases rồi chạy `livekit-server --dev`.
Học sinh dùng máy khác trong mạng LAN: đặt `LIVEKIT_URL=ws://<IP máy chủ>:7880` và chạy `livekit-server --dev --bind 0.0.0.0`.

### Cơ sở dữ liệu và migration (PostgreSQL)

Bảng được tạo và cập nhật bằng migration trong `backend/src/migrations`. Máy chủ tự chạy các migration còn thiếu mỗi lần khởi động, nên chỉ cần tạo một database trống rồi đặt `DATABASE_URL`.

Khi sửa entity (thêm cột, thêm bảng):

```bash
npm run migration:generate -- src/migrations/TenThayDoi   # sinh file migration từ phần khác nhau giữa entity và database
npm run migration:run                                      # chạy migration còn thiếu
npm run migration:revert                                   # hoàn tác migration gần nhất
npm run migration:check                                    # báo lỗi nếu entity đã đổi mà chưa có migration
```

Entity mới phải thêm vào `src/entities.ts`. Test trên PostgreSQL kiểm tra migration khớp với entity và chạy ngược được.
Chạy thử bằng SQLite thì không cần migration: bảng tự khớp theo entity.

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
| Quản trị | Admin xem số liệu tổng quan; tìm tài khoản (gõ không dấu được), thêm, sửa tên, đổi vai trò, khóa / mở khóa, đặt lại mật khẩu; liên kết hoặc gỡ liên kết phụ huynh với học sinh. Khóa tài khoản hoặc đổi vai trò có hiệu lực ngay, không cần chờ hết hạn đăng nhập |
| Lớp học | Tạo lớp có mã mời, học sinh xin vào lớp, giáo viên duyệt hoặc từ chối, đổi mã mời |
| Thời khóa biểu | Tiết lặp hằng tuần, chặn giáo viên trùng giờ, xem lịch theo tuần cho mọi vai trò |
| Họp trực tuyến | Tạo/lên lịch họp, vào phòng (nhận token LiveKit), giáo viên mở và kết thúc phòng |
| Bài tập | Giáo viên giao bài (hạn nộp, điểm tối đa), học sinh nộp/nộp lại khi chưa chấm, tự đánh dấu nộp muộn, giáo viên chấm điểm + nhận xét, phụ huynh xem điểm của con |
| Bài giảng, file | Giáo viên đăng bài giảng kèm tài liệu, slide, video (tối đa 50 MB mỗi file); học sinh nộp bài bằng ảnh chụp hoặc file. File bài giảng: cả lớp tải được. File bài nộp: chỉ học sinh đó, giáo viên và phụ huynh. Link tải có hạn 10 phút |
| Thông báo | Tự báo khi có bài tập, bài kiểm tra, bài giảng mới, khi có điểm, khi lớp bắt đầu học trực tuyến, khi học sinh xin vào lớp hoặc được duyệt. Phụ huynh nhận cả điểm của con. App hiện số chưa đọc trên chuông, bấm vào mở đúng lớp và đúng tab |
| Kiểm tra trắc nghiệm | Soạn đề (câu một hoặc nhiều đáp án, điểm từng câu), bản nháp/phát hành, giới hạn thời gian và hạn chót, đề gửi học sinh không kèm đáp án, tự chấm khi nộp, thống kê điểm và tỉ lệ đúng từng câu, phụ huynh xem điểm của con |
| Bảng trắng | Giáo viên cấp/thu quyền viết cho từng học sinh hoặc cả lớp. Đồng bộ nét vẽ qua WebSocket `ws://<máy chủ>/ws/board?meetingId=&token=` |

Quy tắc phân quyền chính:
- Admin thấy mọi lớp. Giáo viên thấy lớp mình dạy. Học sinh thấy lớp đã được duyệt. Phụ huynh thấy lớp của con.
- Học sinh chỉ vào phòng họp khi giáo viên đã mở phòng. Phụ huynh không vào phòng học.
- Học sinh mặc định không viết được lên bảng. Khi kết thúc họp, mọi quyền viết bị thu lại.
- Không đổi được vai trò của giáo viên còn phụ trách lớp. Đổi vai trò phụ huynh hoặc học sinh thì liên kết phụ huynh của tài khoản đó bị gỡ. Admin không tự khóa hay tự bỏ quyền admin của mình.

## Ghi chú kỹ thuật

- Mật khẩu băm bằng bcrypt, đăng nhập bằng JWT.
- File tải lên lưu trong thư mục `backend/uploads` (đổi bằng `UPLOAD_DIR`, giới hạn bằng `MAX_UPLOAD_MB`). File HTML/SVG luôn bị bắt tải về, không mở trực tiếp, để tránh chạy mã lạ.
- PostgreSQL dùng migration (xem mục "Cơ sở dữ liệu và migration"). `DB_SYNC=true` chỉ để thử nghiệm nhanh.
