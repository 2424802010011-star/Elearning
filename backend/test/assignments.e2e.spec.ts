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

describe('Bài tập', () => {
  let app: INestApplication;
  const tok: Record<string, string> = {};
  const ids: Record<string, string> = {};
  const http = () => request(app.getHttpServer());
  const auth = (w: string) => ({ Authorization: `Bearer ${tok[w]}` });
  let classId: string, a1: string, a2: string, sub1: string;

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication();
    configureApp(app);
    await app.init();
    for (const [who, role] of [['gv', 'teacher'], ['gv2', 'teacher'], ['hs1', 'student'], ['hs2', 'student'], ['ngoai', 'student'], ['ph', 'parent']]) {
      const r = await http().post('/api/auth/register').send({ email: `${who}@t.vn`, password: 'matkhau123', fullName: who, role }).expect(201);
      tok[who] = r.body.accessToken;
      ids[who] = r.body.user.id;
    }
    const admin = (await http().post('/api/auth/login').send({ email: 'admin@test.vn', password: 'admin12345' })).body.accessToken;
    await http().post('/api/parent-links').set({ Authorization: `Bearer ${admin}` }).send({ parentId: ids.ph, studentId: ids.hs1 }).expect(201);
    const c = await http().post('/api/classes').set(auth('gv')).send({ name: 'Lớp thử' }).expect(201);
    classId = c.body.id;
    for (const hs of ['hs1', 'hs2']) {
      const e = await http().post('/api/classes/join').set(auth(hs)).send({ inviteCode: c.body.inviteCode }).expect(201);
      await http().patch(`/api/classes/${classId}/enrollments/${e.body.id}`).set(auth('gv')).send({ status: 'approved' }).expect(200);
    }
  });
  afterAll(async () => app?.close());

  it('chỉ giáo viên chủ lớp giao bài', async () => {
    await http().post(`/api/classes/${classId}/assignments`).set(auth('hs1')).send({ title: 'x' }).expect(403);
    await http().post(`/api/classes/${classId}/assignments`).set(auth('gv2')).send({ title: 'x' }).expect(403);
    a1 = (await http().post(`/api/classes/${classId}/assignments`).set(auth('gv')).send({ title: 'Bài 1', description: 'Tính 2+2', maxScore: 10 }).expect(201)).body.id;
    a2 = (
      await http()
        .post(`/api/classes/${classId}/assignments`)
        .set(auth('gv'))
        .send({ title: 'Bài 2 (đã quá hạn)', dueAt: '2020-01-01T00:00:00Z' })
        .expect(201)
    ).body.id;
  });

  it('học sinh nộp bài, nộp lại được; người ngoài lớp không nộp được', async () => {
    await http().post(`/api/assignments/${a1}/submit`).set(auth('ngoai')).send({ content: '4' }).expect(403);
    await http().post(`/api/assignments/${a1}/submit`).set(auth('hs1')).send({ content: '' }).expect(400);
    await http().post(`/api/assignments/${a1}/submit`).set(auth('hs1')).send({ content: '5' }).expect(201);
    const r = await http().post(`/api/assignments/${a1}/submit`).set(auth('hs1')).send({ content: '4' }).expect(201);
    expect(r.body.content).toBe('4');
    expect(r.body.late).toBe(false);
    sub1 = r.body.id;
    const late = await http().post(`/api/assignments/${a2}/submit`).set(auth('hs2')).send({ content: 'muộn' }).expect(201);
    expect(late.body.late).toBe(true);
  });

  it('giáo viên xem số bài đã nộp; học sinh chỉ thấy bài của mình', async () => {
    const gv = await http().get(`/api/classes/${classId}/assignments`).set(auth('gv')).expect(200);
    const b1 = gv.body.find((a: any) => a.id === a1);
    expect(b1).toMatchObject({ submittedCount: 1, gradedCount: 0, totalStudents: 2 });
    const hs2 = await http().get(`/api/classes/${classId}/assignments`).set(auth('hs2')).expect(200);
    expect(hs2.body.find((a: any) => a.id === a1).submissions).toHaveLength(0);
    expect(hs2.body.find((a: any) => a.id === a2).submissions).toHaveLength(1);
  });

  it('chấm điểm: không vượt điểm tối đa, chỉ chủ lớp chấm', async () => {
    await http().patch(`/api/assignments/${a1}/submissions/${sub1}`).set(auth('gv2')).send({ score: 9 }).expect(403);
    await http().patch(`/api/assignments/${a1}/submissions/${sub1}`).set(auth('gv')).send({ score: 11 }).expect(400);
    const g = await http().patch(`/api/assignments/${a1}/submissions/${sub1}`).set(auth('gv')).send({ score: 9.5, feedback: 'Tốt' }).expect(200);
    expect(g.body.score).toBe(9.5);
    const subs = await http().get(`/api/assignments/${a1}/submissions`).set(auth('gv')).expect(200);
    expect(subs.body[0].student.email).toBe('hs1@t.vn');
  });

  it('đã chấm thì không nộp lại được; phụ huynh thấy điểm của con', async () => {
    await http().post(`/api/assignments/${a1}/submit`).set(auth('hs1')).send({ content: 'sửa' }).expect(400);
    const ph = await http().get(`/api/classes/${classId}/assignments`).set(auth('ph')).expect(200);
    expect(ph.body.find((a: any) => a.id === a1).submissions[0]).toMatchObject({ score: 9.5, feedback: 'Tốt' });
    await http().post(`/api/assignments/${a1}/submit`).set(auth('ph')).send({ content: 'x' }).expect(403);
  });

  it('xóa bài tập', async () => {
    await http().delete(`/api/assignments/${a2}`).set(auth('hs1')).expect(403);
    await http().delete(`/api/assignments/${a2}`).set(auth('gv')).expect(204);
    const list = await http().get(`/api/classes/${classId}/assignments`).set(auth('gv')).expect(200);
    expect(list.body).toHaveLength(1);
  });
});
