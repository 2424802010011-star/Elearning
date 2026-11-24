# EduBoard

Phần mềm học tập, giảng dạy và quản lý lớp học cho giáo viên, học sinh, phụ huynh và nhà trường.
Kế hoạch chi tiết: xem file Word/Excel trong thư mục `ke-hoach` của dự án.

## Tiến độ

| Phần | Trạng thái |
|---|---|
| Backend: đăng nhập, JWT, phân quyền 4 vai trò | Xong |
| Backend: liên kết phụ huynh - học sinh | Xong |
| Backend: lớp học, mã mời, duyệt đăng ký | Xong |
| Backend: thời khóa biểu, chặn trùng giờ, lịch tuần | Xong |
| App Flutter (mobile + desktop) | Chưa bắt đầu |
| Họp trực tuyến (LiveKit), bảng trắng, AI nhận diện nét | Chưa bắt đầu |

## Chạy backend

Cần Node.js 20+ và PostgreSQL 16 (hoặc Docker).

```bash
docker compose up -d db          # khởi động PostgreSQL
cd backend
cp .env.example .env             # sửa JWT_SECRET, ADMIN_EMAIL, ADMIN_PASSWORD
npm install
npm run start:dev                # API chạy ở http://localhost:3000/api
```

Lần chạy đầu, hệ thống tự tạo tài khoản admin từ `ADMIN_EMAIL` / `ADMIN_PASSWORD`.

Chạy test (cần một database trống riêng cho test, dữ liệu sẽ bị xóa mỗi lần chạy):

```bash
DATABASE_URL=postgres://eduboard:eduboard@localhost:5432/eduboard_test npm test
```

## API

Mọi route (trừ đăng ký, đăng nhập) cần header `Authorization: Bearer <accessToken>`.

| Phương thức | Đường dẫn | Ai được dùng | Mô tả |
|---|---|---|---|
| POST | `/api/auth/register` | Mọi người | Đăng ký học sinh, giáo viên, phụ huynh |
| POST | `/api/auth/login` | Mọi người | Đăng nhập, trả về `accessToken` |
| GET | `/api/auth/me` | Đã đăng nhập | Thông tin tài khoản |
| GET | `/api/users?role=` | Admin | Danh sách người dùng |
| POST | `/api/users` | Admin | Tạo tài khoản bất kỳ vai trò |
| PATCH | `/api/users/:id/role` | Admin | Đổi vai trò |
| POST | `/api/parent-links` | Admin | Liên kết phụ huynh với học sinh |
| GET | `/api/me/children` | Phụ huynh | Danh sách con |
| POST | `/api/classes` | Giáo viên, admin | Tạo lớp (tự sinh mã mời 6 ký tự) |
| GET | `/api/classes` | Đã đăng nhập | Lớp theo vai trò: admin thấy hết, GV thấy lớp mình dạy, HS thấy lớp đã được duyệt, PH thấy lớp của con |
| GET | `/api/classes/:id` | Thành viên lớp | Chi tiết lớp |
| POST | `/api/classes/join` | Học sinh | Xin vào lớp bằng mã mời |
| GET | `/api/classes/:id/enrollments?status=` | GV chủ lớp, admin | Danh sách yêu cầu |
| PATCH | `/api/classes/:id/enrollments/:eid` | GV chủ lớp, admin | Duyệt (`approved`) hoặc từ chối (`rejected`) |
| POST | `/api/classes/:id/invite-code` | GV chủ lớp, admin | Đổi mã mời |
| POST | `/api/classes/:id/timetable` | GV chủ lớp, admin | Thêm tiết lặp hằng tuần (chặn trùng giờ của GV) |
| GET | `/api/classes/:id/timetable` | Thành viên lớp | Các tiết của lớp |
| DELETE | `/api/classes/:id/timetable/:entryId` | GV chủ lớp, admin | Xóa tiết |
| GET | `/api/timetable/week?date=YYYY-MM-DD` | Đã đăng nhập | Lịch cả tuần chứa ngày đó, gộp mọi lớp |

## Ghi chú kỹ thuật

- NestJS 11, TypeORM, PostgreSQL. Mật khẩu băm bằng bcrypt.
- `DB_SYNC=true` tự tạo bảng, chỉ dùng cho dev/test. Trước khi lên production cần chuyển sang migration.
