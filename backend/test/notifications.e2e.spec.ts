delete process.env.DATABASE_URL;
process.env.SQLITE_FILE = ':memory:';
process.env.SEED_DEMO = 'false';
process.env.ADMIN_EMAIL = 'admin@test.vn';
process.env.ADMIN_PASSWORD = 'admin12345';

import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/setup';

describe('Thông báo', () => {
  let app: INestApplication;
  const tok: Record<string, string> = {};
  const ids: Record<string, string> = {};
  const http = () => request(app.getHttpServer());
  const auth = (w: string) => ({ Authorization: `Bearer ${tok[w]}` });
  let classId: string, inviteCode: string;

  const inbox = async (who: string) => (await http().get('/api/notifications').set(auth(who)).expect(200)).body;
  const types = async (who: string) => (await inbox(who)).items.map((n: { type: string }) => n.type);

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication();
    configureApp(app);
    await app.init();
    for (const [who, role] of [['gv', 'teacher'], ['hs1', 'student'], ['hs2', 'student'], ['ph', 'parent']]) {
      const r = await http().post('/api/auth/register').send({ email: `${who}@t.vn`, password: 'matkhau123', fullName: who, role }).expect(201);
      tok[who] = r.body.accessToken;
      ids[who] = r.body.user.id;
    }
    const admin = (await http().post('/api/auth/login').send({ email: 'admin@test.vn', password: 'admin12345' })).body.accessToken;
    await http().post('/api/parent-links').set({ Authorization: `Bearer ${admin}` }).send({ parentId: ids.ph, studentId: ids.hs1 }).expect(201);
    const c = await http().post('/api/classes').set(auth('gv')).send({ name: 'Lớp 10A' }).expect(201);
    classId = c.body.id;
    inviteCode = c.body.inviteCode;
  });
  afterAll(async () => app?.close());

  it('xin vào lớp thì giáo viên được báo; duyệt thì học sinh được báo', async () => {
    const e = await http().post('/api/classes/join').set(auth('hs1')).send({ inviteCode }).expect(201);
    await http().post('/api/classes/join').set(auth('hs2')).send({ inviteCode }).expect(201);
    const box = await inbox('gv');
    expect(box.unreadCount).toBe(2);
    expect(box.items[0]).toMatchObject({ type: 'enroll_request', classId, tab: 'students' });
    expect(box.items.map((n: { title: string }) => n.title)).toContain('hs1 xin vào lớp Lớp 10A');
    await http().patch(`/api/classes/${classId}/enrollments/${e.body.id}`).set(auth('gv')).send({ status: 'approved' }).expect(200);
    expect(await types('hs1')).toEqual(['enroll_approved']);
    expect(await types('hs2')).toEqual([]);
  });

  it('giao bài: học sinh trong lớp và phụ huynh được báo, người chưa vào lớp thì không', async () => {
    const a = await http().post(`/api/classes/${classId}/assignments`).set(auth('gv')).send({ title: 'Bài 1', dueAt: '2026-12-20T16:59:00Z' }).expect(201);
    const box = await inbox('hs1');
    expect(box.items[0]).toMatchObject({ type: 'assignment_new', tab: 'assignments' });
    expect(box.items[0].body).toBe('Bài 1 (hạn nộp 23:59 20/12/2026)');
    expect(await types('ph')).toEqual(['assignment_new']);
    expect(await types('hs2')).toEqual([]);

    const s = await http().post(`/api/assignments/${a.body.id}/submit`).set(auth('hs1')).send({ content: '4' }).expect(201);
    expect((await inbox('gv')).items[0]).toMatchObject({ type: 'submission_new', title: 'hs1 đã nộp bài' });
    await http().patch(`/api/assignments/${a.body.id}/submissions/${s.body.id}`).set(auth('gv')).send({ score: 9, feedback: 'Tốt' }).expect(200);
    expect((await inbox('hs1')).items[0]).toMatchObject({ type: 'graded', body: 'hs1: 9/10. Nhận xét: Tốt' });
    expect((await types('ph'))[0]).toBe('graded');
  });

  it('bài kiểm tra: báo khi phát hành (không báo bản nháp); phụ huynh nhận điểm', async () => {
    const questions = [{ text: '1+1', options: ['1', '2'], correct: [1] }];
    const q = await http().post(`/api/classes/${classId}/quizzes`).set(auth('gv')).send({ title: 'KT 15p', questions }).expect(201);
    expect((await types('hs1'))[0]).not.toBe('quiz_new');
    await http().patch(`/api/quizzes/${q.body.id}`).set(auth('gv')).send({ published: true }).expect(200);
    expect((await types('hs1'))[0]).toBe('quiz_new');
    await http().patch(`/api/quizzes/${q.body.id}`).set(auth('gv')).send({ title: 'KT 15 phút' }).expect(200);
    expect((await types('hs1')).filter((t: string) => t === 'quiz_new')).toHaveLength(1);
    await http().post(`/api/quizzes/${q.body.id}/start`).set(auth('hs1')).expect(200);
    await http().post(`/api/quizzes/${q.body.id}/submit`).set(auth('hs1')).send({ answers: { c1: [1] } }).expect(200);
    expect((await inbox('ph')).items[0]).toMatchObject({ type: 'quiz_result', body: 'KT 15 phút: 1/1 điểm' });
  });

  it('bài giảng mới và lớp bắt đầu học trực tuyến', async () => {
    await http().post(`/api/classes/${classId}/lessons`).set(auth('gv')).send({ title: 'Bài 1' }).expect(201);
    expect((await types('hs1'))[0]).toBe('lesson_new');
    const m = await http().post(`/api/classes/${classId}/meetings`).set(auth('gv')).send({ title: 'Ôn tập' }).expect(201);
    await http().post(`/api/meetings/${m.body.id}/join`).set(auth('gv')).expect(200);
    expect((await inbox('hs1')).items[0]).toMatchObject({ type: 'meeting_live', tab: 'meetings', body: 'Ôn tập. Vào tab Cuộc họp để tham gia.' });
    // Giáo viên vào lại phòng thì không báo lần nữa.
    await http().post(`/api/meetings/${m.body.id}/join`).set(auth('gv')).expect(200);
    expect((await types('hs1')).filter((t: string) => t === 'meeting_live')).toHaveLength(1);
  });

  it('đánh dấu đã đọc; không đụng được thông báo của người khác', async () => {
    const box = await inbox('hs1');
    expect(box.unreadCount).toBeGreaterThan(3);
    await http().post(`/api/notifications/${box.items[0].id}/read`).set(auth('hs2')).expect(404);
    const r = await http().post(`/api/notifications/${box.items[0].id}/read`).set(auth('hs1')).expect(200);
    expect(r.body.readAt).toBeTruthy();
    expect((await http().get('/api/notifications/unread-count').set(auth('hs1')).expect(200)).body.unreadCount).toBe(box.unreadCount - 1);
    await http().post('/api/notifications/read-all').set(auth('hs1')).expect(200);
    expect((await inbox('hs1')).unreadCount).toBe(0);
    expect((await http().get('/api/notifications?unread=true').set(auth('hs1')).expect(200)).body.items).toHaveLength(0);
  });
});
