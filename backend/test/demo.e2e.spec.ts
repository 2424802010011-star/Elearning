// Kiểm tra chế độ chạy thử: SQLite + dữ liệu mẫu, không cần cấu hình gì.
delete process.env.DATABASE_URL;
delete process.env.ADMIN_EMAIL;
delete process.env.ADMIN_PASSWORD;
delete process.env.SEED_DEMO;
process.env.SQLITE_FILE = ':memory:';

import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/setup';

describe('Chế độ chạy thử (SQLite + dữ liệu mẫu)', () => {
  let app: INestApplication;
  const login = async (email: string) =>
    (await request(app.getHttpServer()).post('/api/auth/login').send({ email, password: 'demo1234' }).expect(200)).body
      .accessToken as string;

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication();
    configureApp(app);
    await app.init();
  });
  afterAll(async () => app?.close());

  it('đăng nhập được mọi tài khoản demo và thấy dữ liệu mẫu', async () => {
    const admin = await login('admin@demo.vn');
    const users = await request(app.getHttpServer()).get('/api/users').set('Authorization', `Bearer ${admin}`).expect(200);
    expect(users.body).toHaveLength(6);

    const gv = await login('giaovien@demo.vn');
    const classes = await request(app.getHttpServer()).get('/api/classes').set('Authorization', `Bearer ${gv}`).expect(200);
    expect(classes.body.map((c: any) => c.name)).toEqual(['Toán 10A1']);
    const pending = await request(app.getHttpServer())
      .get(`/api/classes/${classes.body[0].id}/enrollments?status=pending`)
      .set('Authorization', `Bearer ${gv}`)
      .expect(200);
    expect(pending.body).toHaveLength(1);

    const ph = await login('phuhuynh@demo.vn');
    const week = await request(app.getHttpServer())
      .get('/api/timetable/week')
      .set('Authorization', `Bearer ${ph}`)
      .expect(200);
    expect(week.body.sessions.map((s: any) => s.title)).toEqual(['Đại số', 'Hình học', 'Luyện đề']);
  });
});
