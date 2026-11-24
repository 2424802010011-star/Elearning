import { Injectable, Logger, OnApplicationBootstrap, OnApplicationShutdown } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, LessThan, LessThanOrEqual, MoreThanOrEqual, Repository } from 'typeorm';
import { ClassesService } from '../classes/classes.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ReminderLog } from './reminder-log.entity';
import { TimetableEntry } from './timetable-entry.entity';

/** Ngày, thứ (1 = Thứ Hai) và số phút trong ngày của [d] theo múi giờ [tz]. */
export function localParts(d: Date, tz: string) {
  const p = Object.fromEntries(
    new Intl.DateTimeFormat('en-CA', {
      timeZone: tz,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      weekday: 'short',
      hourCycle: 'h23',
    })
      .formatToParts(d)
      .map((x) => [x.type, x.value]),
  );
  const dow = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].indexOf(p.weekday) + 1;
  return { date: `${p.year}-${p.month}-${p.day}`, dow, minutes: Number(p.hour) * 60 + Number(p.minute) };
}

const toMinutes = (hhmm: string) => Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3, 5));

/**
 * Nhắc giờ học: mỗi phút kiểm tra các tiết sắp bắt đầu trong REMIND_MINUTES phút tới (mặc định 15, đặt 0 để tắt)
 * và gửi thông báo cho học sinh trong lớp cùng giáo viên.
 */
@Injectable()
export class RemindersService implements OnApplicationBootstrap, OnApplicationShutdown {
  private readonly log = new Logger('Nhắc giờ học');
  private timer?: NodeJS.Timeout;
  readonly lead: number;
  private readonly tz: string;

  constructor(
    @InjectRepository(TimetableEntry) private readonly entries: Repository<TimetableEntry>,
    @InjectRepository(ReminderLog) private readonly logs: Repository<ReminderLog>,
    private readonly classes: ClassesService,
    private readonly notes: NotificationsService,
    cfg: ConfigService,
  ) {
    this.lead = Number(cfg.get('REMIND_MINUTES', 15)) || 0;
    this.tz = cfg.get('DISPLAY_TZ', 'Asia/Ho_Chi_Minh');
  }

  onApplicationBootstrap() {
    if (this.lead <= 0 || process.env.JEST_WORKER_ID) return; // test gọi tick() trực tiếp
    this.timer = setInterval(() => void this.tick().catch((e) => this.log.warn(e.message)), 60_000);
    this.timer.unref();
  }

  onApplicationShutdown() {
    if (this.timer) clearInterval(this.timer);
  }

  /** Gửi nhắc cho các tiết bắt đầu trong khoảng (now, now + lead]. Trả về số tiết đã nhắc. */
  async tick(now = new Date()): Promise<number> {
    if (this.lead <= 0) return 0;
    const { date, dow, minutes } = localParts(now, this.tz);
    const candidates = await this.entries.find({
      where: [
        { dayOfWeek: dow, startDate: LessThanOrEqual(date), endDate: IsNull() },
        { dayOfWeek: dow, startDate: LessThanOrEqual(date), endDate: MoreThanOrEqual(date) },
      ],
    });
    let sent = 0;
    for (const e of candidates) {
      const start = toMinutes(e.startTime);
      if (start <= minutes || start > minutes + this.lead) continue;
      try {
        await this.logs.insert({ entryId: e.id, date });
      } catch {
        continue; // đã nhắc rồi
      }
      const students = await this.classes.approvedStudentIds(e.classroom.id);
      const left = start - minutes;
      await this.notes.notify([...students, e.classroom.teacher.id], {
        type: 'class_soon',
        title: `${left} phút nữa: ${e.title} (${e.classroom.name})`,
        body: `${e.startTime}–${e.endTime}${e.location ? ` · ${e.location}` : ''}`,
        classId: e.classroom.id,
        tab: 'timetable',
      });
      sent++;
    }
    // Dọn nhật ký cũ hơn 30 ngày.
    if (sent) await this.logs.delete({ createdAt: LessThan(new Date(now.getTime() - 30 * 86_400_000)) });
    return sent;
  }
}
