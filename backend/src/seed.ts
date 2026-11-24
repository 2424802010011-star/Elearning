import { Logger } from '@nestjs/common';
import { ClassesService } from './classes/classes.service';
import { EnrollmentStatus } from './classes/enrollment.entity';
import { AuthUser } from './common/decorators';
import { Role } from './common/role.enum';
import { MeetingsService } from './meetings/meetings.service';
import { TimetableService } from './timetable/timetable.service';
import { UsersService } from './users/users.service';

export const DEMO_PASSWORD = 'demo1234';

/** Tạo dữ liệu mẫu để xem thử: 1 giáo viên, 3 học sinh, 1 phụ huynh, 1 lớp, thời khóa biểu, 1 cuộc họp. */
export async function seedDemo(users: UsersService, classes: ClassesService, timetable: TimetableService, meetings: MeetingsService) {
  if ((await users.list(Role.Teacher)).length > 0) return;
  const log = new Logger('Demo');
  const as = (u: { id: string; email: string; role: Role }): AuthUser => ({ id: u.id, email: u.email, role: u.role });

  const gv = await users.create('giaovien@demo.vn', DEMO_PASSWORD, 'Cô Lan (Giáo viên Toán)', Role.Teacher);
  const hs1 = await users.create('hocsinh1@demo.vn', DEMO_PASSWORD, 'Nguyễn Minh An', Role.Student);
  const hs2 = await users.create('hocsinh2@demo.vn', DEMO_PASSWORD, 'Trần Bảo Châu', Role.Student);
  const hs3 = await users.create('hocsinh3@demo.vn', DEMO_PASSWORD, 'Lê Gia Huy', Role.Student);
  const ph = await users.create('phuhuynh@demo.vn', DEMO_PASSWORD, 'Nguyễn Văn Bình (bố An)', Role.Parent);
  await users.linkParent(ph.id, hs1.id);

  const lop = await classes.create(as(gv), { name: 'Toán 10A1', subject: 'Toán', description: 'Lớp mẫu để xem thử' });
  for (const hs of [hs1, hs2]) {
    const e = await classes.join(as(hs), lop.inviteCode);
    await classes.review(as(gv), lop.id, e.id, EnrollmentStatus.Approved);
  }
  await classes.join(as(hs3), lop.inviteCode); // để lại 1 yêu cầu chờ duyệt

  const start = '2026-12-07';
  await timetable.create(as(gv), lop.id, { title: 'Đại số', dayOfWeek: 1, startTime: '07:30', endTime: '08:15', startDate: start, location: 'Học online' });
  await timetable.create(as(gv), lop.id, { title: 'Hình học', dayOfWeek: 3, startTime: '09:00', endTime: '09:45', startDate: start, location: 'Phòng 201' });
  await timetable.create(as(gv), lop.id, { title: 'Luyện đề', dayOfWeek: 5, startTime: '14:00', endTime: '15:30', startDate: start, location: 'Học online' });
  await meetings.create(as(gv), lop.id, { title: 'Ôn tập hàm số lượng giác' });

  log.log(`Đã tạo dữ liệu mẫu. Mật khẩu mọi tài khoản demo: ${DEMO_PASSWORD}. Mã mời lớp Toán 10A1: ${lop.inviteCode}`);
}
