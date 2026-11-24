// Bảng trắng thời gian thực qua WebSocket (chạy trên SQLite trong bộ nhớ).
delete process.env.DATABASE_URL;
process.env.SQLITE_FILE = ':memory:';
process.env.SEED_DEMO = 'false';
process.env.ADMIN_EMAIL = 'admin@test.vn';
process.env.ADMIN_PASSWORD = 'admin12345';

import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { WebSocket } from 'ws';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/setup';

/** Kết nối WS và gom mọi tin nhận được để kiểm tra. */
class Peer {
  msgs: any[] = [];
  private waiters: Array<() => void> = [];
  constructor(public ws: WebSocket) {
    ws.on('message', (d) => {
      this.msgs.push(JSON.parse(d.toString()));
      this.waiters.splice(0).forEach((w) => w());
    });
  }
  send(m: unknown) {
    this.ws.send(JSON.stringify(m));
  }
  async next(type: string, timeout = 3000): Promise<any> {
    const deadline = Date.now() + timeout;
    for (;;) {
      const i = this.msgs.findIndex((m) => m.type === type);
      if (i >= 0) return this.msgs.splice(i, 1)[0];
      if (Date.now() > deadline) throw new Error(`Không nhận được "${type}". Đã nhận: ${JSON.stringify(this.msgs)}`);
      await new Promise<void>((r) => {
        this.waiters.push(r);
        setTimeout(r, 100);
      });
    }
  }
}

describe('Bảng trắng thời gian thực', () => {
  let app: INestApplication;
  let port: number;
  const tok: Record<string, string> = {};
  const ids: Record<string, string> = {};
  let meetingId: string;
  const peers: Peer[] = [];
  const http = () => request(app.getHttpServer());
  const auth = (w: string) => ({ Authorization: `Bearer ${tok[w]}` });

  const connect = (who: string, mid = meetingId, token = tok[who]) =>
    new Promise<Peer>((resolve, reject) => {
      const ws = new WebSocket(`ws://127.0.0.1:${port}/ws/board?meetingId=${mid}&token=${token}`);
      const p = new Peer(ws);
      ws.once('open', () => {
        peers.push(p);
        resolve(p);
      });
      ws.once('unexpected-response', (_req, res) => reject(new Error(String(res.statusCode))));
      ws.once('error', reject);
    });

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication();
    configureApp(app);
    await app.listen(0);
    port = (app.getHttpServer().address() as any).port;

    for (const [who, role] of [['gv', 'teacher'], ['hs1', 'student'], ['hs2', 'student'], ['ngoai', 'student']]) {
      const r = await http()
        .post('/api/auth/register')
        .send({ email: `${who}@t.vn`, password: 'matkhau123', fullName: who, role })
        .expect(201);
      tok[who] = r.body.accessToken;
      ids[who] = r.body.user.id;
    }
    const c = await http().post('/api/classes').set(auth('gv')).send({ name: 'Lớp thử' }).expect(201);
    for (const hs of ['hs1', 'hs2']) {
      const e = await http().post('/api/classes/join').set(auth(hs)).send({ inviteCode: c.body.inviteCode }).expect(201);
      await http().patch(`/api/classes/${c.body.id}/enrollments/${e.body.id}`).set(auth('gv')).send({ status: 'approved' }).expect(200);
    }
    const m = await http().post(`/api/classes/${c.body.id}/meetings`).set(auth('gv')).send({ title: 'Buổi 1' }).expect(201);
    meetingId = m.body.id;
  });

  afterAll(async () => {
    peers.forEach((p) => p.ws.terminate());
    await app?.close();
  });

  it('không cho kết nối khi phòng chưa mở, sai token, hoặc không thuộc lớp', async () => {
    await expect(connect('hs1')).rejects.toThrow('403');
    await http().post(`/api/meetings/${meetingId}/join`).set(auth('gv')).expect(200); // giáo viên mở phòng
    await expect(connect('hs1', meetingId, 'sai-token')).rejects.toThrow('401');
    await expect(connect('ngoai')).rejects.toThrow('403');
  });

  let gv: Peer, hs1: Peer;
  const stroke = { id: 's1', points: [10, 10, 200, 10], color: 0xff000000, width: 3, kind: 'line' };

  it('giáo viên vẽ, học sinh thấy ngay', async () => {
    gv = await connect('gv');
    hs1 = await connect('hs1');
    const snapGv = await gv.next('snapshot');
    expect(snapGv.isHost).toBe(true);
    const snapHs = await hs1.next('snapshot');
    expect(snapHs.canWrite).toBe(false);

    gv.send({ type: 'patch', upserts: [stroke] });
    const p = await hs1.next('patch');
    expect(p.upserts[0]).toMatchObject({ id: 's1', points: [10, 10, 200, 10], author: ids.gv });
  });

  it('học sinh chưa được phép thì không vẽ được', async () => {
    hs1.send({ type: 'patch', upserts: [{ ...stroke, id: 'hs-x' }] });
    const e = await hs1.next('error');
    expect(e.message).toContain('chưa được phép');
  });

  it('giáo viên cấp quyền: học sinh được báo ngay và vẽ được', async () => {
    await http()
      .put(`/api/meetings/${meetingId}/whiteboard/permissions`)
      .set(auth('gv'))
      .send({ studentIds: [ids.hs1] })
      .expect(200);
    expect((await hs1.next('permissions')).canWrite).toBe(true);
    hs1.send({ type: 'patch', upserts: [{ ...stroke, id: 's2', points: [0, 0, 50, 50] }] });
    const p = await gv.next('patch');
    expect(p.upserts[0].id).toBe('s2');
  });

  it('người vào sau nhận toàn bộ bảng; xóa nét được đồng bộ', async () => {
    gv.send({ type: 'patch', removed: ['s1'] });
    expect((await hs1.next('patch')).removed).toEqual(['s1']);
    const hs2 = await connect('hs2');
    const snap = await hs2.next('snapshot');
    expect(snap.strokes.map((s: any) => s.id)).toEqual(['s2']);
    expect(snap.canWrite).toBe(false);
  });

  it('dữ liệu xấu bị bỏ qua', async () => {
    gv.send({ type: 'patch', upserts: [{ id: 'bad', points: ['x', 1] }, { id: 42, points: [] }] });
    gv.send('không phải json' as any);
    gv.send({ type: 'ping' });
    await gv.next('pong');
    expect(hs1.msgs.filter((m) => m.type === 'patch')).toHaveLength(0);
  });

  it('chỉ giáo viên được xóa bảng', async () => {
    hs1.send({ type: 'clear' });
    gv.send({ type: 'clear' });
    await hs1.next('clear');
    const hs3 = await connect('hs1');
    expect((await hs3.next('snapshot')).strokes).toHaveLength(0);
  });

  it('kết thúc họp: mọi người nhận "ended" và bị ngắt', async () => {
    const closed = new Promise((r) => hs1.ws.once('close', r));
    await http().post(`/api/meetings/${meetingId}/end`).set(auth('gv')).expect(200);
    await hs1.next('ended');
    await closed;
    await expect(connect('hs1')).rejects.toThrow('403');
  });
});
