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

describe('Kiểm tra trắc nghiệm', () => {
  let app: INestApplication;
  const tok: Record<string, string> = {};
  const ids: Record<string, string> = {};
  const http = () => request(app.getHttpServer());
  const auth = (w: string) => ({ Authorization: `Bearer ${tok[w]}` });
  let classId: string, quizId: string, qids: string[];

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

  const questions = [
    { text: '1 + 1 = ?', options: ['1', '2', '3'], correct: [1], points: 2 },
    { text: 'Số nào là số chẵn?', options: ['2', '3', '4', '5'], correct: [2, 0], points: 3 },
    { text: 'π xấp xỉ', options: ['3.14', '2.71'], correct: [0] },
  ];

  it('chỉ giáo viên chủ lớp soạn đề; đề sai bị từ chối', async () => {
    await http().post(`/api/classes/${classId}/quizzes`).set(auth('hs1')).send({ title: 'x', questions }).expect(403);
    await http().post(`/api/classes/${classId}/quizzes`).set(auth('gv2')).send({ title: 'x', questions }).expect(403);
    await http().post(`/api/classes/${classId}/quizzes`).set(auth('gv')).send({ title: 'x', questions: [] }).expect(400);
    await http()
      .post(`/api/classes/${classId}/quizzes`)
      .set(auth('gv'))
      .send({ title: 'x', questions: [{ text: 'a', options: ['1', '2'], correct: [5] }] })
      .expect(400);
    const r = await http().post(`/api/classes/${classId}/quizzes`).set(auth('gv')).send({ title: 'Kiểm tra 1', durationMinutes: 10, questions }).expect(201);
    quizId = r.body.id;
    qids = r.body.questions.map((q: { id: string }) => q.id);
    expect(r.body.maxScore).toBe(6);
    expect(r.body.published).toBe(false);
    expect(r.body.questions[1].correct).toEqual([0, 2]);
  });

  it('chưa phát hành thì học sinh không thấy, không làm được', async () => {
    const list = await http().get(`/api/classes/${classId}/quizzes`).set(auth('hs1')).expect(200);
    expect(list.body).toHaveLength(0);
    await http().post(`/api/quizzes/${quizId}/start`).set(auth('hs1')).expect(404);
    await http().patch(`/api/quizzes/${quizId}`).set(auth('gv')).send({ published: true }).expect(200);
  });

  it('học sinh làm bài: đề không lộ đáp án, có hạn giờ', async () => {
    await http().post(`/api/quizzes/${quizId}/start`).set(auth('ngoai')).expect(403);
    await http().post(`/api/quizzes/${quizId}/start`).set(auth('ph')).expect(403);
    const r = await http().post(`/api/quizzes/${quizId}/start`).set(auth('hs1')).expect(200);
    expect(JSON.stringify(r.body.questions)).not.toContain('correct');
    expect(r.body.questions[1].multiple).toBe(true);
    const deadline = new Date(r.body.attempt.deadline).getTime();
    expect(deadline - Date.now()).toBeGreaterThan(9 * 60_000);
    // Bắt đầu lại thì tiếp tục lượt cũ, đồng hồ không chạy lại.
    const again = await http().post(`/api/quizzes/${quizId}/start`).set(auth('hs1')).expect(200);
    expect(again.body.attempt.id).toBe(r.body.attempt.id);
    const view = await http().get(`/api/quizzes/${quizId}`).set(auth('hs1')).expect(200);
    expect(JSON.stringify(view.body.questions)).not.toContain('correct');
  });

  it('nộp bài thì tự chấm: câu nhiều đáp án phải chọn đủ', async () => {
    await http().post(`/api/quizzes/${quizId}/submit`).set(auth('hs2')).send({ answers: {} }).expect(400); // chưa bắt đầu
    const r = await http()
      .post(`/api/quizzes/${quizId}/submit`)
      .set(auth('hs1'))
      .send({ answers: { [qids[0]]: [1], [qids[1]]: [0], [qids[2]]: [0, 99] } })
      .expect(200);
    expect(r.body.attempt.score).toBe(3); // câu 1 (2 điểm) + câu 3 (1 điểm); câu 2 thiếu đáp án
    expect(r.body.attempt.late).toBe(false);
    expect(r.body.questions[1].correct).toEqual([0, 2]); // được xem đáp án sau khi nộp
    await http().post(`/api/quizzes/${quizId}/submit`).set(auth('hs1')).send({ answers: {} }).expect(400);
    await http().post(`/api/quizzes/${quizId}/start`).set(auth('hs1')).expect(400);

    await http().post(`/api/quizzes/${quizId}/start`).set(auth('hs2')).expect(200);
    const r2 = await http()
      .post(`/api/quizzes/${quizId}/submit`)
      .set(auth('hs2'))
      .send({ answers: { [qids[0]]: [1], [qids[1]]: [2, 0], [qids[2]]: [0] } })
      .expect(200);
    expect(r2.body.attempt.score).toBe(6);
  });

  it('giáo viên xem điểm cả lớp và tỉ lệ đúng từng câu; không sửa câu hỏi khi đã có bài làm', async () => {
    const list = await http().get(`/api/classes/${classId}/quizzes`).set(auth('gv')).expect(200);
    expect(list.body[0]).toMatchObject({ submittedCount: 2, totalStudents: 2, averageScore: 4.5, maxScore: 6 });
    const res = await http().get(`/api/quizzes/${quizId}/results`).set(auth('gv')).expect(200);
    expect(res.body.attempts).toHaveLength(2);
    expect(res.body.questionStats.map((s: { correctCount: number }) => s.correctCount)).toEqual([2, 1, 2]);
    await http().get(`/api/quizzes/${quizId}/results`).set(auth('hs1')).expect(403);
    await http().patch(`/api/quizzes/${quizId}`).set(auth('gv')).send({ questions }).expect(400);
    await http().patch(`/api/quizzes/${quizId}`).set(auth('gv')).send({ title: 'Kiểm tra 1 (đã sửa tên)' }).expect(200);
  });

  it('phụ huynh xem điểm của con, không xem được đề', async () => {
    const list = await http().get(`/api/classes/${classId}/quizzes`).set(auth('ph')).expect(200);
    expect(list.body[0].attempts).toHaveLength(1);
    expect(list.body[0].attempts[0].score).toBe(3);
    const v = await http().get(`/api/quizzes/${quizId}`).set(auth('ph')).expect(200);
    expect(v.body.questions).toBeUndefined();
  });

  it('quá hạn thì không bắt đầu được; giấu đáp án nếu giáo viên tắt', async () => {
    const q = await http()
      .post(`/api/classes/${classId}/quizzes`)
      .set(auth('gv'))
      .send({ title: 'Quá hạn', published: true, dueAt: '2020-01-01T00:00:00Z', questions })
      .expect(201);
    await http().post(`/api/quizzes/${q.body.id}/start`).set(auth('hs1')).expect(400);
    const q2 = await http()
      .post(`/api/classes/${classId}/quizzes`)
      .set(auth('gv'))
      .send({ title: 'Giấu đáp án', published: true, showAnswers: false, questions })
      .expect(201);
    await http().post(`/api/quizzes/${q2.body.id}/start`).set(auth('hs1')).expect(200);
    const r = await http().post(`/api/quizzes/${q2.body.id}/submit`).set(auth('hs1')).send({ answers: {} }).expect(200);
    expect(r.body.attempt.score).toBe(0);
    expect(JSON.stringify(r.body.questions)).not.toContain('correct');
    await http().delete(`/api/quizzes/${q2.body.id}`).set(auth('gv2')).expect(403);
    await http().delete(`/api/quizzes/${q2.body.id}`).set(auth('gv')).expect(204);
  });
});
