// TEST_DB=sqlite: chạy trên SQLite trong bộ nhớ. Mặc định: PostgreSQL (database test riêng, bị xóa mỗi lần chạy).
if (process.env.TEST_DB === 'sqlite') {
  delete process.env.DATABASE_URL;
  process.env.SQLITE_FILE = ':memory:';
} else {
  process.env.DATABASE_URL ??= 'postgres://eduboard:eduboard@localhost:5432/eduboard_test';
}
process.env.SEED_DEMO = 'false';
process.env.JWT_SECRET = 'test-secret';
process.env.DB_SYNC = 'true';
process.env.DB_DROP_SCHEMA = 'true';
process.env.ADMIN_EMAIL = 'admin@test.vn';
process.env.ADMIN_PASSWORD = 'admin12345';

import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { TokenVerifier } from 'livekit-server-sdk';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/setup';

describe('EduBoard API', () => {
  let app: INestApplication;
  const http = () => request(app.getHttpServer());
  const tok: Record<string, string> = {};
  const ids: Record<string, string> = {};
  const auth = (who: string) => ({ Authorization: `Bearer ${tok[who]}` });

  async function register(who: string, role: string) {
    const res = await http()
      .post('/api/auth/register')
      .send({ email: `${who}@test.vn`, password: 'matkhau123', fullName: who, role })
      .expect(201);
    tok[who] = res.body.accessToken;
    ids[who] = res.body.user.id;
    expect(res.body.user.passwordHash).toBeUndefined();
  }

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication();
    configureApp(app);
    await app.init();
  });
  afterAll(async () => app?.close());

  describe('Đăng nhập và phân quyền', () => {
    it('tạo sẵn admin từ biến môi trường và đăng nhập được', async () => {
      const res = await http().post('/api/auth/login').send({ email: 'admin@test.vn', password: 'admin12345' }).expect(200);
      tok.admin = res.body.accessToken;
      expect(res.body.user.role).toBe('admin');
    });

    it('đăng ký giáo viên, học sinh, phụ huynh', async () => {
      await register('gv1', 'teacher');
      await register('gv2', 'teacher');
      await register('hs1', 'student');
      await register('hs2', 'student');
      await register('ph1', 'parent');
    });

    it('không cho tự đăng ký làm admin', async () => {
      await http()
        .post('/api/auth/register')
        .send({ email: 'hack@test.vn', password: 'matkhau123', fullName: 'x', role: 'admin' })
        .expect(400);
    });

    it('từ chối email trùng và mật khẩu sai', async () => {
      await http()
        .post('/api/auth/register')
        .send({ email: 'HS1@test.vn', password: 'matkhau123', fullName: 'Trùng', role: 'student' })
        .expect(409);
      await http().post('/api/auth/login').send({ email: 'hs1@test.vn', password: 'sai-mat-khau' }).expect(401);
    });

    it('cần token cho route riêng tư', async () => {
      await http().get('/api/auth/me').expect(401);
      const me = await http().get('/api/auth/me').set(auth('hs1')).expect(200);
      expect(me.body.email).toBe('hs1@test.vn');
    });

    it('chỉ admin xem được danh sách người dùng', async () => {
      await http().get('/api/users').set(auth('gv1')).expect(403);
      const res = await http().get('/api/users?role=student').set(auth('admin')).expect(200);
      expect(res.body).toHaveLength(2);
    });

    it('admin liên kết phụ huynh với học sinh, kiểm tra đúng vai trò', async () => {
      await http().post('/api/parent-links').set(auth('admin')).send({ parentId: ids.hs1, studentId: ids.hs2 }).expect(400);
      await http().post('/api/parent-links').set(auth('admin')).send({ parentId: ids.ph1, studentId: ids.hs1 }).expect(201);
      await http().post('/api/parent-links').set(auth('admin')).send({ parentId: ids.ph1, studentId: ids.hs1 }).expect(409);
      const kids = await http().get('/api/me/children').set(auth('ph1')).expect(200);
      expect(kids.body.map((k: any) => k.email)).toEqual(['hs1@test.vn']);
    });
  });

  describe('Lớp học và đăng ký', () => {
    let code: string;

    it('học sinh không được tạo lớp, giáo viên thì được', async () => {
      await http().post('/api/classes').set(auth('hs1')).send({ name: 'Toán 10A1' }).expect(403);
      const res = await http()
        .post('/api/classes')
        .set(auth('gv1'))
        .send({ name: 'Toán 10A1', subject: 'Toán' })
        .expect(201);
      ids.class1 = res.body.id;
      code = res.body.inviteCode;
      expect(code).toMatch(/^[A-Z2-9]{6}$/);
    });

    it('học sinh xin vào lớp bằng mã mời (không phân biệt hoa thường)', async () => {
      await http().post('/api/classes/join').set(auth('hs1')).send({ inviteCode: 'ZZZZZZ' }).expect(404);
      const res = await http().post('/api/classes/join').set(auth('hs1')).send({ inviteCode: code.toLowerCase() }).expect(201);
      expect(res.body.status).toBe('pending');
      ids.enr1 = res.body.id;
      await http().post('/api/classes/join').set(auth('hs1')).send({ inviteCode: code }).expect(409);
      const r2 = await http().post('/api/classes/join').set(auth('hs2')).send({ inviteCode: code }).expect(201);
      ids.enr2 = r2.body.id;
    });

    it('chưa duyệt thì học sinh và phụ huynh chưa thấy lớp', async () => {
      expect((await http().get('/api/classes').set(auth('hs1')).expect(200)).body).toHaveLength(0);
      await http().get(`/api/classes/${ids.class1}`).set(auth('hs1')).expect(403);
      expect((await http().get('/api/classes').set(auth('ph1')).expect(200)).body).toHaveLength(0);
    });

    it('chỉ giáo viên chủ lớp được duyệt', async () => {
      await http()
        .patch(`/api/classes/${ids.class1}/enrollments/${ids.enr1}`)
        .set(auth('gv2'))
        .send({ status: 'approved' })
        .expect(403);
      const pending = await http().get(`/api/classes/${ids.class1}/enrollments?status=pending`).set(auth('gv1')).expect(200);
      expect(pending.body).toHaveLength(2);
      await http()
        .patch(`/api/classes/${ids.class1}/enrollments/${ids.enr1}`)
        .set(auth('gv1'))
        .send({ status: 'approved' })
        .expect(200);
      await http()
        .patch(`/api/classes/${ids.class1}/enrollments/${ids.enr2}`)
        .set(auth('gv1'))
        .send({ status: 'rejected' })
        .expect(200);
    });

    it('sau khi duyệt: học sinh và phụ huynh thấy lớp, học sinh bị từ chối thì không', async () => {
      expect((await http().get('/api/classes').set(auth('hs1')).expect(200)).body).toHaveLength(1);
      await http().get(`/api/classes/${ids.class1}`).set(auth('hs1')).expect(200);
      expect((await http().get('/api/classes').set(auth('ph1')).expect(200)).body).toHaveLength(1);
      expect((await http().get('/api/classes').set(auth('hs2')).expect(200)).body).toHaveLength(0);
      expect((await http().get('/api/classes').set(auth('gv2')).expect(200)).body).toHaveLength(0);
      expect((await http().get('/api/classes').set(auth('admin')).expect(200)).body).toHaveLength(1);
    });

    it('học sinh bị từ chối có thể gửi lại yêu cầu', async () => {
      const res = await http().post('/api/classes/join').set(auth('hs2')).send({ inviteCode: code }).expect(201);
      expect(res.body.status).toBe('pending');
    });

    it('đổi mã mời: mã cũ hết hiệu lực', async () => {
      const res = await http().post(`/api/classes/${ids.class1}/invite-code`).set(auth('gv1')).expect(201);
      expect(res.body.inviteCode).not.toBe(code);
      await register('hs3', 'student');
      await http().post('/api/classes/join').set(auth('hs3')).send({ inviteCode: code }).expect(404);
    });
  });

  describe('Thời khóa biểu', () => {
    const tiet = { title: 'Đại số', dayOfWeek: 1, startTime: '07:30', endTime: '08:15', startDate: '2026-12-07' };

    it('giáo viên chủ lớp tạo tiết học, kiểm tra dữ liệu đầu vào', async () => {
      await http().post(`/api/classes/${ids.class1}/timetable`).set(auth('gv2')).send(tiet).expect(403);
      await http()
        .post(`/api/classes/${ids.class1}/timetable`)
        .set(auth('gv1'))
        .send({ ...tiet, startTime: '25:00' })
        .expect(400);
      await http()
        .post(`/api/classes/${ids.class1}/timetable`)
        .set(auth('gv1'))
        .send({ ...tiet, startTime: '09:00', endTime: '08:00' })
        .expect(400);
      await http().post(`/api/classes/${ids.class1}/timetable`).set(auth('gv1')).send(tiet).expect(201);
      await http()
        .post(`/api/classes/${ids.class1}/timetable`)
        .set(auth('gv1'))
        .send({ ...tiet, title: 'Hình học', dayOfWeek: 3, startTime: '09:00', endTime: '09:45', endDate: '2026-12-20' })
        .expect(201);
    });

    it('chặn giáo viên có hai tiết trùng giờ, kể cả ở lớp khác', async () => {
      const c2 = await http().post('/api/classes').set(auth('gv1')).send({ name: 'Toán 11B2' }).expect(201);
      const res = await http()
        .post(`/api/classes/${c2.body.id}/timetable`)
        .set(auth('gv1'))
        .send({ ...tiet, startTime: '08:00', endTime: '08:45' })
        .expect(409);
      expect(res.body.message).toContain('Đại số');
      // Nối tiếp ngay sau tiết trước thì hợp lệ
      await http()
        .post(`/api/classes/${c2.body.id}/timetable`)
        .set(auth('gv1'))
        .send({ ...tiet, startTime: '08:15', endTime: '09:00' })
        .expect(201);
    });

    it('lịch tuần cho học sinh và phụ huynh, tôn trọng ngày kết thúc', async () => {
      const w1 = await http().get('/api/timetable/week?date=2026-12-09').set(auth('hs1')).expect(200);
      expect(w1.body.weekStart).toBe('2026-12-07');
      expect(w1.body.weekEnd).toBe('2026-12-13');
      expect(w1.body.sessions.map((s: any) => `${s.date} ${s.startTime} ${s.title}`)).toEqual([
        '2026-12-07 07:30 Đại số',
        '2026-12-09 09:00 Hình học',
      ]);
      const w3 = await http().get('/api/timetable/week?date=2026-12-21').set(auth('ph1')).expect(200);
      expect(w3.body.sessions.map((s: any) => s.title)).toEqual(['Đại số']);
      const none = await http().get('/api/timetable/week?date=2026-12-09').set(auth('hs3')).expect(200);
      expect(none.body.sessions).toHaveLength(0);
    });

    it('xóa tiết học', async () => {
      const list = await http().get(`/api/classes/${ids.class1}/timetable`).set(auth('hs1')).expect(200);
      expect(list.body).toHaveLength(2);
      await http().delete(`/api/classes/${ids.class1}/timetable/${list.body[0].id}`).set(auth('hs1')).expect(403);
      await http().delete(`/api/classes/${ids.class1}/timetable/${list.body[0].id}`).set(auth('gv1')).expect(204);
      const after = await http().get(`/api/classes/${ids.class1}/timetable`).set(auth('gv1')).expect(200);
      expect(after.body).toHaveLength(1);
    });
  });

  describe('Họp trực tuyến và quyền viết bảng', () => {
    let meetingId: string;

    it('chỉ giáo viên chủ lớp tạo được cuộc họp', async () => {
      await http().post(`/api/classes/${ids.class1}/meetings`).set(auth('hs1')).send({ title: 'x' }).expect(403);
      await http().post(`/api/classes/${ids.class1}/meetings`).set(auth('gv2')).send({ title: 'x' }).expect(403);
      const res = await http()
        .post(`/api/classes/${ids.class1}/meetings`)
        .set(auth('gv1'))
        .send({ title: 'Ôn tập lượng giác', scheduledAt: '2026-12-08T07:30:00+07:00' })
        .expect(201);
      expect(res.body.status).toBe('scheduled');
      meetingId = res.body.id;
      const list = await http().get(`/api/classes/${ids.class1}/meetings`).set(auth('hs1')).expect(200);
      expect(list.body).toHaveLength(1);
    });

    it('học sinh chưa vào được khi giáo viên chưa mở phòng; người ngoài lớp và phụ huynh bị chặn', async () => {
      await http().post(`/api/meetings/${meetingId}/join`).set(auth('hs1')).expect(400);
      await http().post(`/api/meetings/${meetingId}/join`).set(auth('hs3')).expect(403);
      await http().post(`/api/meetings/${meetingId}/join`).set(auth('ph1')).expect(403);
    });

    it('giáo viên vào thì phòng mở, nhận token LiveKit có quyền quản trị phòng', async () => {
      const res = await http().post(`/api/meetings/${meetingId}/join`).set(auth('gv1')).expect(200);
      expect(res.body.isHost).toBe(true);
      expect(res.body.canWriteBoard).toBe(true);
      const grants = await new TokenVerifier('devkey', 'secret').verify(res.body.token);
      expect(grants.video?.room).toBe(res.body.roomName);
      expect(grants.video?.roomAdmin).toBe(true);
      expect(grants.sub).toBe(ids.gv1);
    });

    it('học sinh vào được, token không có quyền quản trị, mặc định không được viết bảng', async () => {
      const res = await http().post(`/api/meetings/${meetingId}/join`).set(auth('hs1')).expect(200);
      expect(res.body.isHost).toBe(false);
      expect(res.body.canWriteBoard).toBe(false);
      const grants = await new TokenVerifier('devkey', 'secret').verify(res.body.token);
      expect(grants.video?.roomAdmin).toBeFalsy();
    });

    it('giáo viên cấp quyền viết cho từng học sinh, rồi cho cả lớp, rồi thu lại', async () => {
      await http()
        .put(`/api/meetings/${meetingId}/whiteboard/permissions`)
        .set(auth('hs1'))
        .send({ studentIds: [ids.hs1] })
        .expect(403);
      // hs3 không thuộc lớp
      await http()
        .put(`/api/meetings/${meetingId}/whiteboard/permissions`)
        .set(auth('gv1'))
        .send({ studentIds: [ids.hs3] })
        .expect(400);
      await http()
        .put(`/api/meetings/${meetingId}/whiteboard/permissions`)
        .set(auth('gv1'))
        .send({ studentIds: [ids.hs1] })
        .expect(200);
      let p = await http().get(`/api/meetings/${meetingId}/whiteboard/permissions`).set(auth('hs1')).expect(200);
      expect(p.body.canWrite).toBe(true);

      await http().put(`/api/meetings/${meetingId}/whiteboard/permissions`).set(auth('gv1')).send({ studentIds: [] }).expect(200);
      p = await http().get(`/api/meetings/${meetingId}/whiteboard/permissions`).set(auth('hs1')).expect(200);
      expect(p.body.canWrite).toBe(false);

      await http().put(`/api/meetings/${meetingId}/whiteboard/permissions`).set(auth('gv1')).send({ allowAll: true }).expect(200);
      const j = await http().post(`/api/meetings/${meetingId}/join`).set(auth('hs1')).expect(200);
      expect(j.body.canWriteBoard).toBe(true);
    });

    it('kết thúc họp: thu hết quyền viết, không ai vào lại được trừ khi tạo phòng mới', async () => {
      await http().post(`/api/meetings/${meetingId}/end`).set(auth('hs1')).expect(403);
      const res = await http().post(`/api/meetings/${meetingId}/end`).set(auth('gv1')).expect(200);
      expect(res.body.status).toBe('ended');
      expect(res.body.boardAllowAll).toBe(false);
      await http().post(`/api/meetings/${meetingId}/join`).set(auth('hs1')).expect(400);
      await http().post(`/api/meetings/${meetingId}/join`).set(auth('gv1')).expect(400);
    });
  });
});
