# EduBoard app (Flutter)

Một mã nguồn chạy trên Android, iOS, Windows, macOS và trình duyệt web.

## Đã có
- Đăng nhập, đăng ký, nút đăng nhập nhanh bằng tài khoản mẫu
- Lớp học: tạo lớp, mã mời, học sinh xin vào lớp, giáo viên duyệt/từ chối
- Bài tập: giáo viên giao bài và chấm điểm, học sinh nộp bài và xem điểm, phụ huynh xem điểm của con
- Lịch học của lớp, thêm/xóa tiết; thời khóa biểu cả tuần cho mọi vai trò
- Phòng học: video/âm thanh qua LiveKit (bật/tắt micro, camera, chia sẻ màn hình, viền xanh khi đang nói)
- Bảng trắng vẽ tay (bút, tẩy, màu, độ dày, hoàn tác, xóa bảng)
- **AI hình**: tự nắn đường thẳng, hình tròn, elip, tam giác, hình chữ nhật, tứ giác, đa giác và đồ thị hình sin; có nút "Giữ nét gốc"
- **AI chữ & toán** (`lib/ink/math_ink.dart`): đọc 0–9, x y z a b c e f n, + − = ( ) < >, ∫ π Σ ∞ θ, dấu chấm, cùng phân số, căn bậc hai, số mũ; viết lại cho thẳng hàng, cùng cỡ. Thuật toán đám mây điểm $P, chạy trên máy, ~3 ms mỗi ký hiệu
- Bảng trắng đồng bộ thời gian thực (WebSocket): nét vẽ hiện ngay trên máy mọi người, tự kết nối lại khi rớt mạng, toạ độ chuẩn hoá nên màn hình to nhỏ đều đúng vị trí
- Giáo viên cấp/thu quyền viết bảng cho từng học sinh hoặc cả lớp; học sinh được báo ngay

## Chạy
Cần cài Flutter (https://docs.flutter.dev/get-started/install) và bật máy chủ backend trước.

```bash
flutter pub get
flutter run -d chrome      # trình duyệt
flutter run -d windows     # ứng dụng Windows
flutter test               # chạy test AI nắn hình, đọc chữ & toán, bảng trắng
```

Bản web đã build sẵn được backend phục vụ tại http://localhost:3000, nên chỉ để xem thì không cần cài Flutter.
Build lại bản web: `flutter build web --release --no-web-resources-cdn` rồi chép `build/web` vào `backend/public`.
