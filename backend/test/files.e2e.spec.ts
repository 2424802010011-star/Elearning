delete process.env.DATABASE_URL;
process.env.SQLITE_FILE = ':memory:';
process.env.SEED_DEMO = 'false';
process.env.ADMIN_EMAIL = 'admin@test.vn';
process.env.ADMIN_PASSWORD = 'admin12345';
process.env.UPLOAD_DIR = require('fs').mkdtempSync(require('path').join(require('os').tmpdir(), 'eduboard-up-'));

import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/setup';

describe('File, bài giảng, bài nộp kèm file', () => {
  let app: INestApplication;
  const tok: Record<string, string> = {};
  const ids: Record<string, string> = {};
  const http = () => request(app.getHttpServer());
  const auth = (w: string) => ({ Authorization: `Bearer ${tok[w]}` });
  let classId: string, classB: string;

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
    classB = (await http().post('/api/classes').set(auth('gv2')).send({ name: 'Lớp khác' }).expect(201)).body.id;
  });
  afterAll(async () => app?.close());

  const up = (who: string, name: string, content: string | Buffer, type = 'application/pdf') =>
    http().post('/api/files').set(auth(who)).attach('file', Buffer.from(content), { filename: name, contentType: type });

  const download = async (who: string, id: string) => {
    const l = await http().get(`/api/files/${id}/link`).set(auth(who));
    if (l.status !== 200) return { status: l.status, body: undefined as unknown as Buffer, headers: {} as Record<string, string> };
    const r = await http().get(l.body.url).buffer(true).parse((res, cb) => {
      const chunks: Buffer[] = [];
      res.on('data', (c: Buffer) => chunks.push(c));
      res.on('end', () => cb(null, Buffer.concat(chunks)));
    });
    return { status: r.status, body: r.body as Buffer, headers: r.headers as Record<string, string> };
  };

  let slide: string, lessonId: string, bailam: string;

  it('tải file lên, giữ tên tiếng Việt; phải đăng nhập', async () => {
    await http().post('/api/files').attach('file', Buffer.from('x'), 'a.txt').expect(401);
    await http().post('/api/files').set(auth('gv')).expect(400);
    const r = await up('gv', 'Bài giảng hàm số.pdf', '%PDF-1.4 nội dung').expect(201);
    expect(r.body).toMatchObject({ name: 'Bài giảng hàm số.pdf', mimeType: 'application/pdf' });
    slide = r.body.id;
    // Chưa gắn vào đâu: chỉ người tải lên xem được.
    expect((await download('gv', slide)).status).toBe(200);
    expect((await download('hs1', slide)).status).toBe(403);
  });

  it('giáo viên đăng bài giảng kèm file; cả lớp tải được, người ngoài lớp thì không', async () => {
    const other = (await up('hs1', 'cua-hs.pdf', 'x').expect(201)).body.id;
    await http().post(`/api/classes/${classId}/lessons`).set(auth('gv')).send({ title: 'Bài 1', fileIds: [other] }).expect(403);
    await http().post(`/api/classes/${classId}/lessons`).set(auth('hs1')).send({ title: 'Bài 1' }).expect(403);
    const r = await http().post(`/api/classes/${classId}/lessons`).set(auth('gv')).send({ title: 'Bài 1', content: 'Đọc trước', fileIds: [slide] }).expect(201);
    lessonId = r.body.id;
    expect(r.body.attachments[0]).toMatchObject({ id: slide, name: 'Bài giảng hàm số.pdf' });
    // File đã thuộc lớp này thì không gắn sang lớp khác được.
    await http().post(`/api/classes/${classB}/lessons`).set(auth('gv2')).send({ title: 'x', fileIds: [slide] }).expect(403);

    const list = await http().get(`/api/classes/${classId}/lessons`).set(auth('hs2')).expect(200);
    expect(list.body).toHaveLength(1);
    const d = await download('hs2', slide);
    expect(d.status).toBe(200);
    expect(d.body.toString()).toBe('%PDF-1.4 nội dung');
    expect(d.headers['content-disposition']).toContain("inline; filename*=UTF-8''B%C3%A0i%20gi%E1%BA%A3ng");
    expect((await download('ph', slide)).status).toBe(200); // phụ huynh của hs1 cũng xem được tài liệu lớp
    expect((await download('ngoai', slide)).status).toBe(403);
    await http().get(`/api/classes/${classId}/lessons`).set(auth('ngoai')).expect(403);
  });

  it('link tải không dùng thay token đăng nhập được, sai file thì bị chặn', async () => {
    const l = await http().get(`/api/files/${slide}/link`).set(auth('hs1')).expect(200);
    const t = decodeURIComponent(l.body.url.split('t=')[1]);
    await http().get('/api/auth/me').set({ Authorization: `Bearer ${t}` }).expect(401);
    await http().get(`/api/files/${slide}/raw?t=sai`).expect(403);
    const other = (await up('gv', 'khac.pdf', 'y').expect(201)).body.id;
    await http().get(`/api/files/${other}/raw?t=${encodeURIComponent(t)}`).expect(403);
  });

  it('file HTML luôn bị tải về, không mở trong trình duyệt', async () => {
    const h = (await up('gv', 'trang.html', '<script>alert(1)</script>', 'text/html').expect(201)).body.id;
    const d = await download('gv', h);
    expect(d.headers['content-type']).toBe('application/octet-stream');
    expect(d.headers['content-disposition']).toMatch(/^attachment/);
    expect(d.headers['x-content-type-options']).toBe('nosniff');
  });

  it('học sinh nộp bài bằng ảnh chụp; chỉ mình, giáo viên và phụ huynh xem được', async () => {
    const a = (await http().post(`/api/classes/${classId}/assignments`).set(auth('gv')).send({ title: 'Bài tập ảnh' }).expect(201)).body.id;
    await http().post(`/api/assignments/${a}/submit`).set(auth('hs1')).send({}).expect(400);
    bailam = (await up('hs1', 'bai-lam.jpg', 'JPEGDATA', 'image/jpeg').expect(201)).body.id;
    const r = await http().post(`/api/assignments/${a}/submit`).set(auth('hs1')).send({ fileIds: [bailam] }).expect(201);
    expect(r.body.attachments[0]).toMatchObject({ id: bailam, name: 'bai-lam.jpg' });
    const subs = await http().get(`/api/assignments/${a}/submissions`).set(auth('gv')).expect(200);
    expect(subs.body[0].attachments).toHaveLength(1);
    expect((await download('gv', bailam)).status).toBe(200);
    expect((await download('ph', bailam)).status).toBe(200);
    expect((await download('hs1', bailam)).status).toBe(200);
    expect((await download('hs2', bailam)).status).toBe(403); // bạn cùng lớp không xem được bài của nhau
    expect((await download('gv2', bailam)).status).toBe(403);
  });

  it('xóa bài giảng thì xóa luôn file', async () => {
    await http().delete(`/api/lessons/${lessonId}`).set(auth('gv2')).expect(403);
    await http().delete(`/api/lessons/${lessonId}`).set(auth('gv')).expect(204);
    await http().get(`/api/files/${slide}/link`).set(auth('gv')).expect(404);
  });
});
