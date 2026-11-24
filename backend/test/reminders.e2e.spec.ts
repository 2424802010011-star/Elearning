delete process.env.DATABASE_URL;
process.env.SQLITE_FILE = ':memory:';
process.env.SEED_DEMO = 'false';
process.env.ADMIN_EMAIL = 'admin@test.vn';
process.env.ADMIN_PASSWORD = 'admin12345';
process.env.REMIND_MINUTES = '15';

import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/setup';
import { localParts, RemindersService } from '../src/timetable/reminders.service';

describe('Nhắc giờ học', () => {
  let app: INestApplication;
  let reminders: RemindersService;
  const tok: Record<string, string> = {};
  const ids: Record<string, string> = {};
  const http = () => request(app.getHttpServer());
  const auth = (w: string) => ({ Authorization: `Bearer ${tok[w]}` });
  const inbox = async (who: string) => (await http().get('/api/notifications').set(auth(who)).expect(200)).body.items;
  // Thứ Tư 09/12/2026. 07:20 giờ Việt Nam = 00:20 UTC.
  const at = (hhmm: string, day = '2026-12-09') => {
    const [h, m] = hhmm.split(':').map(Number);
    return new Date(Date.UTC(Number(day.slice(0, 4)), Number(day.slice(5, 7)) - 1, Number(day.slice(8, 10)), h - 7, m));
  };

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication();
    configureApp(app);
    await app.init();
    reminders = app.get(RemindersService);
    for (const [who, role] of [['gv', 'teacher'], ['hs', 'student'], ['hs2', 'student'], ['ph', 'parent']]) {
      const r = await http().post('/api/auth/register').send({ email: `${who}@t.vn`, password: 'matkhau123', fullName: who, role }).expect(201);
      tok[who] = r.body.accessToken;
      ids[who] = r.body.user.id;
    }
    const admin = (await http().post('/api/auth/login').send({ email: 'admin@test.vn', password: 'admin12345' })).body.accessToken;
    await http().post('/api/parent-links').set({ Authorization: `Bearer ${admin}` }).send({ parentId: ids.ph, studentId: ids.hs }).expect(201);
    const c = (await http().post('/api/classes').set(auth('gv')).send({ name: 'Toán 10A1' }).expect(201)).body;
    ids.class = c.id;
    const e = (await http().post('/api/classes/join').set(auth('hs')).send({ inviteCode: c.inviteCode }).expect(201)).body;
    await http().patch(`/api/classes/${c.id}/enrollments/${e.id}`).set(auth('gv')).send({ status: 'approved' }).expect(200);
    await http().post('/api/classes/join').set(auth('hs2')).send({ inviteCode: c.inviteCode }).expect(201); // chưa duyệt
    const entry = (t: object) => http().post(`/api/classes/${c.id}/timetable`).set(auth('gv')).send({ dayOfWeek: 3, startDate: '2026-12-01', ...t }).expect(201);
    await entry({ title: 'Đại số', startTime: '07:30', endTime: '08:15', location: 'Phòng A2', startDate: '2026-12-09' });
    await entry({ title: 'Hình học', startTime: '07:30', endTime: '08:15', endDate: '2026-12-08', startDate: '2026-11-01' }); // đã hết hạn
    await entry({ title: 'Giải tích', startTime: '09:00', endTime: '09:45' });
    for (const w of ['gv', 'hs', 'hs2', 'ph']) await http().post('/api/notifications/read-all').set(auth(w));
  });
  afterAll(async () => app?.close());

  it('tính giờ địa phương', () => {
    expect(localParts(at('07:20'), 'Asia/Ho_Chi_Minh')).toEqual({ date: '2026-12-09', dow: 3, minutes: 440 });
    expect(localParts(new Date('2026-12-13T17:30:00Z'), 'Asia/Ho_Chi_Minh')).toMatchObject({ date: '2026-12-14', dow: 1 });
  });

  it('còn hơn 15 phút thì chưa nhắc', async () => {
    expect(await reminders.tick(at('07:14'))).toBe(0);
  });

  it('nhắc học sinh đã vào lớp và giáo viên, chỉ một lần', async () => {
    expect(await reminders.tick(at('07:20'))).toBe(1);
    const n = (await inbox('hs')).filter((x: { type: string }) => x.type === 'class_soon');
    expect(n).toHaveLength(1);
    expect(n[0]).toMatchObject({ title: '10 phút nữa: Đại số (Toán 10A1)', body: '07:30–08:15 · Phòng A2', classId: ids.class, tab: 'timetable' });
    expect((await inbox('gv')).map((x: { type: string }) => x.type)).toContain('class_soon');
    expect((await inbox('hs2')).map((x: { type: string }) => x.type)).not.toContain('class_soon');
    expect((await inbox('ph')).map((x: { type: string }) => x.type)).not.toContain('class_soon');
    expect(await reminders.tick(at('07:25'))).toBe(0);
  });

  it('tiết đã bắt đầu hoặc khác ngày thì không nhắc', async () => {
    expect(await reminders.tick(at('09:00'))).toBe(0);
    expect(await reminders.tick(at('08:50', '2026-12-10'))).toBe(0); // Thứ Năm
    expect(await reminders.tick(at('08:50'))).toBe(1); // Giải tích 09:00
  });

  it('tuần sau lại nhắc', async () => {
    expect(await reminders.tick(at('07:20', '2026-12-16'))).toBe(1);
  });
});
