import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { IncomingMessage, Server } from 'http';
import { Duplex } from 'stream';
import { WebSocket, WebSocketServer } from 'ws';
import { AuthUser } from '../common/decorators';

/** Một nét trên bảng. Toạ độ theo "đơn vị bảng": chiều ngang bảng = 1000 đơn vị. */
export interface BoardStroke {
  id: string;
  points: number[]; // [x0, y0, x1, y1, ...]
  color: number;
  width: number;
  kind?: string;
  author?: string;
}

interface Client {
  ws: WebSocket;
  user: AuthUser;
  isHost: boolean;
}

interface Room {
  strokes: Map<string, BoardStroke>;
  clients: Set<Client>;
  allowAll: boolean;
  writers: Set<string>;
}

/** Kết quả kiểm tra khi một người kết nối vào bảng của cuộc họp. */
export interface BoardAccess {
  isHost: boolean;
  allowAll: boolean;
  writers: string[];
}

export type AccessChecker = (user: AuthUser, meetingId: string) => Promise<BoardAccess>;

const MAX_POINTS = 20000;
const MAX_STROKES = 5000;

/**
 * Đồng bộ bảng trắng thời gian thực qua WebSocket: ws://<máy chủ>/ws/board?meetingId=...&token=...
 * Máy chủ giữ trạng thái bảng của mỗi cuộc họp trong bộ nhớ, người vào sau nhận ngay toàn bộ bảng.
 */
@Injectable()
export class BoardHub implements OnModuleDestroy {
  private readonly log = new Logger('Board');
  private readonly rooms = new Map<string, Room>();
  private readonly wss = new WebSocketServer({ noServer: true, maxPayload: 1024 * 1024 });
  private checker?: AccessChecker;

  constructor(private readonly jwt: JwtService) {}

  setAccessChecker(fn: AccessChecker) {
    this.checker = fn;
  }

  attach(server: Server) {
    server.on('upgrade', (req: IncomingMessage, socket: Duplex, head: Buffer) => {
      const url = new URL(req.url ?? '/', 'http://x');
      if (url.pathname !== '/ws/board') return;
      this.handleUpgrade(req, socket, head, url).catch(() => socket.destroy());
    });
  }

  private reject(socket: Duplex, code: number, msg: string) {
    socket.write(`HTTP/1.1 ${code} ${msg}\r\nConnection: close\r\n\r\n`);
    socket.destroy();
  }

  private async handleUpgrade(req: IncomingMessage, socket: Duplex, head: Buffer, url: URL) {
    const meetingId = url.searchParams.get('meetingId') ?? '';
    let user: AuthUser;
    try {
      const p = await this.jwt.verifyAsync(url.searchParams.get('token') ?? '');
      user = { id: p.sub, email: p.email, role: p.role };
    } catch {
      return this.reject(socket, 401, 'Unauthorized');
    }
    let access: BoardAccess;
    try {
      if (!this.checker) throw new Error('no checker');
      access = await this.checker(user, meetingId);
    } catch {
      return this.reject(socket, 403, 'Forbidden');
    }
    this.wss.handleUpgrade(req, socket, head, (ws) => this.onConnect(ws, user, meetingId, access));
  }

  private room(meetingId: string, access?: BoardAccess): Room {
    let r = this.rooms.get(meetingId);
    if (!r) {
      r = { strokes: new Map(), clients: new Set(), allowAll: false, writers: new Set() };
      this.rooms.set(meetingId, r);
    }
    if (access) {
      r.allowAll = access.allowAll;
      r.writers = new Set(access.writers);
    }
    return r;
  }

  private canWrite(room: Room, c: Client) {
    return c.isHost || room.allowAll || room.writers.has(c.user.id);
  }

  private send(ws: WebSocket, msg: unknown) {
    if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(msg));
  }

  private onConnect(ws: WebSocket, user: AuthUser, meetingId: string, access: BoardAccess) {
    const room = this.room(meetingId, access);
    const client: Client = { ws, user, isHost: access.isHost };
    room.clients.add(client);
    this.send(ws, {
      type: 'snapshot',
      strokes: [...room.strokes.values()],
      canWrite: this.canWrite(room, client),
      isHost: client.isHost,
    });

    ws.on('message', (data) => {
      let msg: any;
      try {
        msg = JSON.parse(data.toString());
      } catch {
        return;
      }
      this.onMessage(meetingId, room, client, msg);
    });
    ws.on('close', () => {
      room.clients.delete(client);
    });
  }

  private onMessage(meetingId: string, room: Room, c: Client, msg: any) {
    if (msg?.type === 'ping') return this.send(c.ws, { type: 'pong' });
    if (!this.canWrite(room, c)) return this.send(c.ws, { type: 'error', message: 'Bạn chưa được phép viết lên bảng' });

    if (msg.type === 'patch') {
      const upserts: BoardStroke[] = [];
      for (const s of Array.isArray(msg.upserts) ? msg.upserts : []) {
        const clean = this.sanitize(s, c.user.id);
        if (!clean) continue;
        if (!room.strokes.has(clean.id) && room.strokes.size >= MAX_STROKES) continue;
        room.strokes.set(clean.id, clean);
        upserts.push(clean);
      }
      const removed: string[] = [];
      for (const id of Array.isArray(msg.removed) ? msg.removed : []) {
        if (typeof id === 'string' && room.strokes.delete(id)) removed.push(id);
      }
      if (upserts.length || removed.length) this.broadcast(room, { type: 'patch', upserts, removed }, c);
      return;
    }
    if (msg.type === 'clear' && c.isHost) {
      room.strokes.clear();
      this.broadcast(room, { type: 'clear' }, c);
    }
  }

  private sanitize(s: any, author: string): BoardStroke | null {
    if (!s || typeof s.id !== 'string' || s.id.length > 64 || !Array.isArray(s.points)) return null;
    if (s.points.length > MAX_POINTS || s.points.some((n: unknown) => typeof n !== 'number' || !Number.isFinite(n))) return null;
    return {
      id: s.id,
      points: s.points.map((n: number) => Math.round(n * 10) / 10),
      color: Number.isInteger(s.color) ? s.color : 0xff000000,
      width: typeof s.width === 'number' ? Math.min(Math.max(s.width, 0.5), 40) : 3,
      kind: typeof s.kind === 'string' ? s.kind.slice(0, 20) : undefined,
      author,
    };
  }

  private broadcast(room: Room, msg: unknown, except?: Client) {
    const text = JSON.stringify(msg);
    for (const c of room.clients) {
      if (c !== except && c.ws.readyState === WebSocket.OPEN) c.ws.send(text);
    }
  }

  /** Giáo viên đổi quyền viết: báo ngay cho từng người trong phòng. */
  permissionsChanged(meetingId: string, allowAll: boolean, writers: string[]) {
    const room = this.rooms.get(meetingId);
    if (!room) return;
    room.allowAll = allowAll;
    room.writers = new Set(writers);
    for (const c of room.clients) this.send(c.ws, { type: 'permissions', canWrite: this.canWrite(room, c), allowAll });
  }

  /** Kết thúc cuộc họp: báo mọi người rời phòng và xóa bảng khỏi bộ nhớ. */
  meetingEnded(meetingId: string) {
    const room = this.rooms.get(meetingId);
    if (!room) return;
    for (const c of room.clients) {
      this.send(c.ws, { type: 'ended' });
      c.ws.close(1000, 'ended');
    }
    this.rooms.delete(meetingId);
    this.log.log(`Đã đóng bảng của cuộc họp ${meetingId}`);
  }

  onModuleDestroy() {
    for (const room of this.rooms.values()) for (const c of room.clients) c.ws.terminate();
    this.rooms.clear();
    this.wss.close();
  }
}
