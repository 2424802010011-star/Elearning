import { Logger } from '@nestjs/common';
import { AssignmentsService } from './assignments/assignments.service';
import { ClassesService } from './classes/classes.service';
import { EnrollmentStatus } from './classes/enrollment.entity';
import { AuthUser } from './common/decorators';
import { Role } from './common/role.enum';
import { FilesService } from './files/files.service';
import { LessonsService } from './lessons/lessons.service';
import { MeetingsService } from './meetings/meetings.service';
import { QuizzesService } from './quizzes/quizzes.service';
import { localParts } from './timetable/reminders.service';
import { TimetableService } from './timetable/timetable.service';
import { UsersService } from './users/users.service';

/** 23:59 giờ Việt Nam, [n] ngày sau hôm nay (hạn nộp của dữ liệu mẫu). */
function inDays(n: number): string {
  const d = new Date(Date.now() + n * 86_400_000);
  return `${localParts(d, process.env.DISPLAY_TZ ?? 'Asia/Ho_Chi_Minh').date}T23:59:00+07:00`;
}

export const DEMO_PASSWORD = 'demo1234';

/** Tạo dữ liệu mẫu để xem thử: 1 giáo viên, 3 học sinh, 1 phụ huynh, 1 lớp, thời khóa biểu, 1 cuộc họp. */
const as = (u: { id: string; email: string; role: Role }): AuthUser => ({ id: u.id, email: u.email, role: u.role });

export async function seedDemo(
  users: UsersService,
  classes: ClassesService,
  timetable: TimetableService,
  meetings: MeetingsService,
  assignments: AssignmentsService,
  quizzes: QuizzesService,
  files: FilesService,
  lessons: LessonsService,
) {
  if ((await users.list(Role.Teacher)).length > 0) {
    // Dữ liệu mẫu đã có từ bản trước: chỉ bổ sung phần mới.
    await seedQuizzes(users, classes, quizzes);
    await seedLessons(users, classes, files, lessons);
    return;
  }
  const log = new Logger('Demo');

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

  // Lịch bắt đầu từ Thứ Hai tuần này, để mở app là thấy ngay thời khóa biểu.
  const today = localParts(new Date(), process.env.DISPLAY_TZ ?? 'Asia/Ho_Chi_Minh');
  const monday = new Date(`${today.date}T00:00:00Z`);
  monday.setUTCDate(monday.getUTCDate() - (today.dow - 1));
  const start = monday.toISOString().slice(0, 10);
  await timetable.create(as(gv), lop.id, { title: 'Đại số', dayOfWeek: 1, startTime: '07:30', endTime: '08:15', startDate: start, location: 'Học online' });
  await timetable.create(as(gv), lop.id, { title: 'Hình học', dayOfWeek: 3, startTime: '09:00', endTime: '09:45', startDate: start, location: 'Phòng 201' });
  await timetable.create(as(gv), lop.id, { title: 'Luyện đề', dayOfWeek: 5, startTime: '14:00', endTime: '15:30', startDate: start, location: 'Học online' });
  await meetings.create(as(gv), lop.id, { title: 'Ôn tập hàm số lượng giác' });

  const bt1 = await assignments.create(as(gv), lop.id, {
    title: 'Đồ thị hàm số y = 2sin(x)',
    description: 'Nêu tập xác định, chu kỳ, giá trị lớn nhất và nhỏ nhất của y = 2sin(x).',
    dueAt: inDays(14),
    maxScore: 10,
  });
  await assignments.create(as(gv), lop.id, {
    title: 'Tam giác vuông và định lý Pythagore',
    description: 'Cho tam giác ABC vuông tại A, AB = 3, AC = 4. Tính BC và đường cao AH.',
    maxScore: 10,
  });
  const nop = await assignments.submit(as(hs1), bt1.id, { content: 'Tập xác định R, chu kỳ 2π, lớn nhất 2, nhỏ nhất -2.' });
  await assignments.grade(as(gv), bt1.id, nop.id, { score: 9, feedback: 'Đúng. Nên ghi thêm khi nào đạt giá trị lớn nhất.' });
  await assignments.submit(as(hs2), bt1.id, { content: 'Chu kỳ là π.' });

  await seedQuizzes(users, classes, quizzes);
  await seedLessons(users, classes, files, lessons);

  log.log(`Đã tạo dữ liệu mẫu. Mật khẩu mọi tài khoản demo: ${DEMO_PASSWORD}. Mã mời lớp Toán 10A1: ${lop.inviteCode}`);
}

/** Bài kiểm tra trắc nghiệm mẫu cho lớp Toán 10A1 (chỉ tạo khi lớp chưa có bài nào). */
async function seedQuizzes(users: UsersService, classes: ClassesService, quizzes: QuizzesService) {
  const all = await users.list();
  const gv = all.find((u) => u.email === 'giaovien@demo.vn');
  const hs1 = all.find((u) => u.email === 'hocsinh1@demo.vn');
  if (!gv) return;
  const lop = (await classes.listFor(as(gv))).find((c) => c.name === 'Toán 10A1');
  if (!lop || (await quizzes.listForClass(as(gv), lop.id)).length) return;

  const kt = await quizzes.create(as(gv), lop.id, {
    title: 'Kiểm tra 15 phút: hàm số lượng giác',
    description: 'Mỗi câu 2,5 điểm. Câu có nhiều đáp án đúng phải chọn đủ mới được điểm.',
    durationMinutes: 15,
    published: true,
    questions: [
      { text: 'Chu kỳ của hàm số y = sin(2x) là:', options: ['π', '2π', 'π/2', '4π'], correct: [0], points: 2.5 },
      { text: 'Giá trị lớn nhất của y = 3cos(x) + 1 là:', options: ['3', '4', '1', '2'], correct: [1], points: 2.5 },
      { text: 'Những hàm số nào là hàm số chẵn?', options: ['y = cos(x)', 'y = sin(x)', 'y = x²', 'y = tan(x)'], correct: [0, 2], points: 2.5 },
      { text: 'sin²(x) + cos²(x) bằng:', options: ['0', '1', '2', 'sin(2x)'], correct: [1], points: 2.5 },
    ],
  });
  await quizzes.create(as(gv), lop.id, {
    title: 'Kiểm tra 45 phút: hình học (bản nháp)',
    durationMinutes: 45,
    published: false,
    questions: [
      { text: 'Tam giác vuông có hai cạnh góc vuông 3 và 4 thì cạnh huyền bằng:', options: ['5', '6', '7', '√7'], correct: [0] },
      { text: 'Tổng ba góc trong một tam giác bằng:', options: ['90°', '180°', '270°', '360°'], correct: [1] },
    ],
  });
  if (hs1) {
    await quizzes.start(as(hs1), kt.id);
    const ids = kt.questions.map((q) => q.id);
    await quizzes.submit(as(hs1), kt.id, { answers: { [ids[0]]: [0], [ids[1]]: [1], [ids[2]]: [0], [ids[3]]: [1] } });
  }
}

/** Bài giảng mẫu có file đính kèm (chỉ tạo khi lớp chưa có bài giảng nào). */
async function seedLessons(users: UsersService, classes: ClassesService, files: FilesService, lessons: LessonsService) {
  const gv = (await users.list(Role.Teacher)).find((u) => u.email === 'giaovien@demo.vn');
  if (!gv) return;
  const lop = (await classes.listFor(as(gv))).find((c) => c.name === 'Toán 10A1');
  if (!lop || (await lessons.list(as(gv), lop.id)).length) return;
  const text = [
    'TÓM TẮT CÔNG THỨC LƯỢNG GIÁC',
    '',
    'sin²x + cos²x = 1',
    'tan x = sin x / cos x',
    '1 + tan²x = 1 / cos²x',
    'sin 2x = 2 sin x cos x',
    'cos 2x = cos²x − sin²x = 1 − 2sin²x',
    '',
    'Chu kỳ: y = sin(ax) và y = cos(ax) có chu kỳ 2π/|a|.',
  ].join('\n');
  const buffer = Buffer.from(text, 'utf8');
  const name = 'Tóm tắt công thức lượng giác.txt';
  const f = await files.upload(as(gv), {
    originalname: Buffer.from(name, 'utf8').toString('latin1'),
    mimetype: 'text/plain; charset=utf-8',
    size: buffer.length,
    buffer,
  } as Express.Multer.File);
  await lessons.create(as(gv), lop.id, {
    title: 'Bài 1: Hàm số lượng giác',
    content: 'Các em đọc bản tóm tắt công thức trước buổi học thứ Hai. Chú ý cách tìm chu kỳ của hàm số.',
    fileIds: [f.id],
  });
}
