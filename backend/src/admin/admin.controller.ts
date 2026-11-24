import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { DataSource } from 'typeorm';
import { Assignment, Submission } from '../assignments/entities';
import { Classroom } from '../classes/classroom.entity';
import { Enrollment, EnrollmentStatus } from '../classes/enrollment.entity';
import { Roles } from '../common/decorators';
import { Role } from '../common/role.enum';
import { StoredFile } from '../files/stored-file.entity';
import { Lesson } from '../lessons/lesson.entity';
import { Meeting, MeetingStatus } from '../meetings/meeting.entity';
import { Quiz, QuizAttempt } from '../quizzes/entities';
import { User } from '../users/user.entity';

@ApiTags('Quản trị')
@ApiBearerAuth()
@Controller('admin')
export class AdminController {
  constructor(private readonly db: DataSource) {}

  /** Số liệu tổng quan cho trang quản trị. */
  @Get('stats')
  @Roles(Role.Admin)
  async stats() {
    const m = this.db.manager;
    const byRole = Object.fromEntries(
      await Promise.all(Object.values(Role).map(async (r) => [r, await m.count(User, { where: { role: r } })] as const)),
    ) as Record<Role, number>;
    const [locked, classes, pending, meetings, live, assignments, submissions, quizzes, attempts, lessons, files] = await Promise.all([
      m.count(User, { where: { active: false } }),
      m.count(Classroom),
      m.count(Enrollment, { where: { status: EnrollmentStatus.Pending } }),
      m.count(Meeting),
      m.count(Meeting, { where: { status: MeetingStatus.Live } }),
      m.count(Assignment),
      m.count(Submission),
      m.count(Quiz),
      m.count(QuizAttempt),
      m.count(Lesson),
      m.count(StoredFile),
    ]);
    const bytes = await m.createQueryBuilder(StoredFile, 'f').select('COALESCE(SUM(f.size), 0)', 's').getRawOne<{ s: string | number }>();
    return {
      users: { ...byRole, total: Object.values(byRole).reduce((a, b) => a + b, 0), locked },
      classes,
      pendingEnrollments: pending,
      meetings: { total: meetings, live },
      assignments: { total: assignments, submissions },
      quizzes: { total: quizzes, attempts },
      lessons,
      files: { count: files, bytes: Number(bytes?.s ?? 0) },
    };
  }
}
