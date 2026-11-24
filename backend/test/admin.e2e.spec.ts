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

describe('Quản trị', () => {
  let app: INestApplication;
  const tok: Record<string, string> = {};
  const ids: Record<string, string> = {};
  const http = () => request(app.getHttpServer());
  const auth = (w: string) => ({ Authorization: `Bearer ${tok[w]}` });

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication();
    configureApp(app);
    await app.init();
    for (const [who, role, name] of [
      ['gv', 'teacher', 'Trần Văn Giáo'],
      ['hs', 'student', 'Nguyễn Thị Học'],
      ['ph', 'parent', 'Lê Phụ Huynh'],
    ]) {
      const r = await http().post('/api/auth/register').send({ email: `${who}@t.vn`, password: 'matkhau123', fullName: name, role }).expect(201);
      tok[who] = r.body.accessToken;
      ids[who] = r.body.user.id;
    }
    const a = (await http().post('/api/auth/login').send({ email: 'admin@test.vn', password: 'admin12345' }).expect(200)).body;
    tok.admin = a.accessToken;
    ids.admin = a.user.id;
  });
  afterAll(async () => app?.close());

  it('kiểm tra sức khỏe máy chủ không cần đăng nhập', async () => {
    expect((await http().get('/api/health').expect(200)).body).toEqual({ ok: true, db: true });
  });

  it('chỉ admin xem được danh sách và số liệu', async () => {
    await http().get('/api/users').set(auth('gv')).expect(403);
    await http().get('/api/admin/stats').set(auth('gv')).expect(403);
    const s = (await http().get('/api/admin/stats').set(auth('admin')).expect(200)).body;
    expect(s.users).toMatchObject({ admin: 1, teacher: 1, student: 1, parent: 1, total: 4, locked: 0 });
    expect(s).toHaveProperty('files.bytes', 0);
  });

  it('tìm người dùng không cần gõ dấu', async () => {
    const r = (await http().get('/api/users').query({ q: 'nguyen thi' }).set(auth('admin')).expect(200)).body;
    expect(r.map((u: { id: string }) => u.id)).toEqual([ids.hs]);
    expect(r[0].active).toBe(true);
    expect(r[0].passwordHash).toBeUndefined();
    const t = (await http().get('/api/users').query({ q: 'T.VN', role: 'parent' }).set(auth('admin')).expect(200)).body;
    expect(t.map((u: { id: string }) => u.id)).toEqual([ids.ph]);
  });

  it('liên kết phụ huynh: tạo, xem, xóa', async () => {
    const l = (await http().post('/api/parent-links').set(auth('admin')).send({ parentId: ids.ph, studentId: ids.hs }).expect(201)).body;
    const list = (await http().get('/api/parent-links').set(auth('admin')).expect(200)).body;
    expect(list).toHaveLength(1);
    expect(list[0]).toMatchObject({ parent: { id: ids.ph }, student: { id: ids.hs } });
    expect((await http().get('/api/me/children').set(auth('ph')).expect(200)).body).toHaveLength(1);
    await http().delete(`/api/parent-links/${l.id}`).set(auth('admin')).expect(204);
    await http().delete(`/api/parent-links/${l.id}`).set(auth('admin')).expect(404);
    expect((await http().get('/api/me/children').set(auth('ph')).expect(200)).body).toHaveLength(0);
  });

  it('khóa tài khoản: không gọi API và không đăng nhập được, mở lại thì được', async () => {
    await http().get('/api/classes').set(auth('hs')).expect(200);
    const u = (await http().patch(`/api/users/${ids.hs}`).set(auth('admin')).send({ active: false }).expect(200)).body;
    expect(u.active).toBe(false);
    const r = await http().get('/api/classes').set(auth('hs')).expect(401);
    expect(r.body.message).toContain('khóa');
    const l = await http().post('/api/auth/login').send({ email: 'hs@t.vn', password: 'matkhau123' }).expect(401);
    expect(l.body.message).toContain('khóa');
    expect((await http().get('/api/admin/stats').set(auth('admin')).expect(200)).body.users.locked).toBe(1);
    await http().patch(`/api/users/${ids.hs}`).set(auth('admin')).send({ active: true }).expect(200);
    await http().get('/api/classes').set(auth('hs')).expect(200);
  });

  it('đổi vai trò có hiệu lực ngay với token cũ; gỡ liên kết phụ huynh không còn đúng', async () => {
    await http().post('/api/parent-links').set(auth('admin')).send({ parentId: ids.ph, studentId: ids.hs }).expect(201);
    await http().patch(`/api/users/${ids.ph}`).set(auth('admin')).send({ role: 'teacher', fullName: 'Lê Giáo Viên' }).expect(200);
    await http().post('/api/classes').set(auth('ph')).send({ name: 'Lớp mới' }).expect(201);
    expect((await http().get('/api/parent-links').set(auth('admin')).expect(200)).body).toHaveLength(0);
    const u = (await http().get('/api/users').query({ q: 'le giao' }).set(auth('admin')).expect(200)).body;
    expect(u[0]).toMatchObject({ role: 'teacher', fullName: 'Lê Giáo Viên' });
  });

  it('không đổi vai trò giáo viên còn phụ trách lớp', async () => {
    await http().post('/api/classes').set(auth('gv')).send({ name: 'Lớp 10A' }).expect(201);
    const r = await http().patch(`/api/users/${ids.gv}`).set(auth('admin')).send({ role: 'student' }).expect(409);
    expect(r.body.message).toContain('1 lớp');
  });

  it('admin không tự khóa hay tự bỏ quyền của mình', async () => {
    await http().patch(`/api/users/${ids.admin}`).set(auth('admin')).send({ active: false }).expect(400);
    await http().patch(`/api/users/${ids.admin}/role`).set(auth('admin')).send({ role: 'teacher' }).expect(400);
    await http().patch(`/api/users/${ids.admin}`).set(auth('admin')).send({ fullName: 'Quản trị viên' }).expect(200);
  });

  it('đặt lại mật khẩu', async () => {
    await http().post(`/api/users/${ids.gv}/password`).set(auth('admin')).send({ password: 'ngan' }).expect(400);
    await http().post(`/api/users/${ids.gv}/password`).set(auth('admin')).send({ password: 'matkhaumoi1' }).expect(204);
    await http().post('/api/auth/login').send({ email: 'gv@t.vn', password: 'matkhau123' }).expect(401);
    await http().post('/api/auth/login').send({ email: 'gv@t.vn', password: 'matkhaumoi1' }).expect(200);
  });
});
