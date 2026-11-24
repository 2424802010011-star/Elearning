import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { ClassesService } from '../classes/classes.service';
import { AuthUser } from '../common/decorators';
import { CreateEntryDto } from './dto';
import { TimetableEntry } from './timetable-entry.entity';

const DAY_MS = 24 * 60 * 60 * 1000;

function parseDate(s: string): Date {
  const d = new Date(`${s.slice(0, 10)}T00:00:00Z`);
  if (Number.isNaN(d.getTime())) throw new BadRequestException('Ngày không hợp lệ');
  return d;
}
const fmt = (d: Date) => d.toISOString().slice(0, 10);
const isoDay = (d: Date) => ((d.getUTCDay() + 6) % 7) + 1; // 1 = Thứ Hai

/** Hai khoảng ngày (endDate rỗng = không giới hạn) có giao nhau không. */
function datesOverlap(aStart: string, aEnd: string | null | undefined, bStart: string, bEnd: string | null | undefined) {
  return (!aEnd || bStart <= aEnd) && (!bEnd || aStart <= bEnd);
}

@Injectable()
export class TimetableService {
  constructor(
    @InjectRepository(TimetableEntry) private readonly entries: Repository<TimetableEntry>,
    private readonly classes: ClassesService,
  ) {}

  async create(me: AuthUser, classId: string, dto: CreateEntryDto): Promise<TimetableEntry> {
    const classroom = await this.classes.assertCanManage(me, classId);
    if (dto.endTime <= dto.startTime) throw new BadRequestException('Giờ kết thúc phải sau giờ bắt đầu');
    if (dto.endDate && dto.endDate < dto.startDate) throw new BadRequestException('Ngày kết thúc phải sau ngày bắt đầu');

    // Không cho một giáo viên có hai tiết trùng giờ.
    const sameDay = await this.entries.find({
      where: { dayOfWeek: dto.dayOfWeek, classroom: { teacher: { id: classroom.teacher.id } } },
    });
    const clash = sameDay.find(
      (e) =>
        dto.startTime < e.endTime &&
        e.startTime < dto.endTime &&
        datesOverlap(dto.startDate, dto.endDate, e.startDate, e.endDate),
    );
    if (clash) {
      throw new ConflictException(
        `Trùng lịch với "${clash.title}" (${clash.classroom.name}) ${clash.startTime}-${clash.endTime}`,
      );
    }
    return this.entries.save(this.entries.create({ ...dto, endDate: dto.endDate ?? null, classroom }));
  }

  async listForClass(me: AuthUser, classId: string): Promise<TimetableEntry[]> {
    await this.classes.assertCanView(me, classId);
    return this.entries.find({
      where: { classroom: { id: classId } },
      order: { dayOfWeek: 'ASC', startTime: 'ASC' },
    });
  }

  async remove(me: AuthUser, classId: string, entryId: string): Promise<void> {
    await this.classes.assertCanManage(me, classId);
    const res = await this.entries.delete({ id: entryId, classroom: { id: classId } });
    if (!res.affected) throw new NotFoundException('Không tìm thấy tiết học');
  }

  /** Lịch cả tuần (Thứ Hai đến Chủ Nhật) chứa ngày `date`, gộp mọi lớp người dùng được xem. */
  async week(me: AuthUser, date?: string) {
    const ref = date ? parseDate(date) : parseDate(fmt(new Date()));
    const monday = new Date(ref.getTime() - (isoDay(ref) - 1) * DAY_MS);
    const days = Array.from({ length: 7 }, (_, i) => fmt(new Date(monday.getTime() + i * DAY_MS)));

    const ids = await this.classes.visibleClassIds(me);
    const all =
      ids === 'all'
        ? await this.entries.find()
        : ids.length
          ? await this.entries.find({ where: { classroom: { id: In(ids) } } })
          : [];

    const sessions = all
      .map((e) => ({ e, date: days[e.dayOfWeek - 1] }))
      .filter(({ e, date }) => e.startDate <= date && (!e.endDate || date <= e.endDate))
      .map(({ e, date }) => ({
        entryId: e.id,
        date,
        dayOfWeek: e.dayOfWeek,
        startTime: e.startTime,
        endTime: e.endTime,
        title: e.title,
        location: e.location ?? null,
        classroom: { id: e.classroom.id, name: e.classroom.name, subject: e.classroom.subject ?? null },
      }))
      .sort((a, b) => (a.date + a.startTime).localeCompare(b.date + b.startTime));

    return { weekStart: days[0], weekEnd: days[6], sessions };
  }
}
