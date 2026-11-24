import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { AuthUser } from '../common/decorators';
import { UsersService } from '../users/users.service';
import { Notification } from './notification.entity';

export interface NotifyInput {
  type: string;
  title: string;
  body?: string;
  classId?: string;
  tab?: 'lessons' | 'assignments' | 'quizzes' | 'meetings' | 'students' | 'timetable';
}

/** Giờ Việt Nam cho nội dung thông báo. */
export function fmtVN(d: Date | string | undefined | null): string {
  if (!d) return '';
  return new Date(d).toLocaleString('vi-VN', {
    timeZone: process.env.DISPLAY_TZ ?? 'Asia/Ho_Chi_Minh',
    hour: '2-digit',
    minute: '2-digit',
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });
}

@Injectable()
export class NotificationsService {
  private readonly log = new Logger('Thông báo');

  constructor(
    @InjectRepository(Notification) private readonly repo: Repository<Notification>,
    private readonly users: UsersService,
  ) {}

  /**
   * Gửi thông báo. Không bao giờ làm hỏng thao tác chính: lỗi chỉ được ghi log.
   * [withParents] thì gửi thêm cho phụ huynh của các học sinh trong danh sách.
   */
  async notify(userIds: string[], n: NotifyInput, opts: { withParents?: boolean; exclude?: string } = {}) {
    try {
      let ids = [...new Set(userIds)];
      if (opts.withParents && ids.length) ids = [...new Set([...ids, ...(await this.users.parentIdsOf(ids))])];
      if (opts.exclude) ids = ids.filter((i) => i !== opts.exclude);
      if (!ids.length) return;
      await this.repo.insert(
        ids.map((userId) => ({
          userId,
          type: n.type,
          title: n.title.slice(0, 250),
          body: (n.body ?? '').slice(0, 2000),
          classId: n.classId ?? null,
          tab: n.tab ?? null,
        })),
      );
    } catch (e) {
      this.log.warn(`Không gửi được thông báo ${n.type}: ${(e as Error).message}`);
    }
  }

  async list(me: AuthUser, unreadOnly = false, limit = 50) {
    const where = { userId: me.id, ...(unreadOnly ? { readAt: IsNull() } : {}) };
    const [items, unreadCount] = await Promise.all([
      this.repo.find({ where, order: { createdAt: 'DESC' }, take: Math.min(Math.max(limit, 1), 200) }),
      this.repo.count({ where: { userId: me.id, readAt: IsNull() } }),
    ]);
    return { items, unreadCount };
  }

  async unreadCount(me: AuthUser) {
    return { unreadCount: await this.repo.count({ where: { userId: me.id, readAt: IsNull() } }) };
  }

  async markRead(me: AuthUser, id: string) {
    const n = await this.repo.findOne({ where: { id, userId: me.id } });
    if (!n) throw new NotFoundException('Không tìm thấy thông báo');
    if (!n.readAt) {
      n.readAt = new Date();
      await this.repo.save(n);
    }
    return n;
  }

  async markAllRead(me: AuthUser) {
    await this.repo.update({ userId: me.id, readAt: IsNull() }, { readAt: new Date() });
    return { unreadCount: 0 };
  }
}
