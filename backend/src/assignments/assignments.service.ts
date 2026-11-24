import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { ClassesService } from '../classes/classes.service';
import { AuthUser } from '../common/decorators';
import { Role } from '../common/role.enum';
import { UsersService } from '../users/users.service';
import { CreateAssignmentDto, GradeDto, SubmitDto } from './dto';
import { Assignment, Submission } from './entities';

@Injectable()
export class AssignmentsService {
  constructor(
    @InjectRepository(Assignment) private readonly assignments: Repository<Assignment>,
    @InjectRepository(Submission) private readonly submissions: Repository<Submission>,
    private readonly classes: ClassesService,
    private readonly users: UsersService,
  ) {}

  async create(me: AuthUser, classId: string, dto: CreateAssignmentDto) {
    const classroom = await this.classes.assertCanManage(me, classId);
    return this.assignments.save(
      this.assignments.create({
        classroom,
        title: dto.title,
        description: dto.description ?? '',
        dueAt: dto.dueAt ? new Date(dto.dueAt) : undefined,
        maxScore: dto.maxScore ?? 10,
      }),
    );
  }

  /** Học sinh/phụ huynh chỉ thấy bài nộp của mình/con mình. */
  private async visibleStudentIds(me: AuthUser): Promise<string[] | 'all'> {
    if (me.role === Role.Student) return [me.id];
    if (me.role === Role.Parent) return (await this.users.childrenOf(me.id)).map((c) => c.id);
    return 'all';
  }

  async listForClass(me: AuthUser, classId: string) {
    const classroom = await this.classes.assertCanView(me, classId);
    const list = await this.assignments.find({ where: { classroom: { id: classId } }, order: { createdAt: 'DESC' } });
    if (!list.length) return [];
    const who = await this.visibleStudentIds(me);
    const subs = await this.submissions.find({
      where: {
        assignment: { id: In(list.map((a) => a.id)) },
        ...(who === 'all' ? {} : { student: { id: In(who.length ? who : ['00000000-0000-0000-0000-000000000000']) } }),
      },
      relations: { assignment: true },
    });
    const totalStudents = who === 'all' ? (await this.classes.approvedStudentIds(classroom.id)).length : undefined;
    return list.map((a) => {
      const mine = subs.filter((s) => s.assignment.id === a.id).map(({ assignment: _a, ...s }) => s);
      return who === 'all'
        ? {
            ...a,
            submittedCount: mine.length,
            gradedCount: mine.filter((s) => s.score != null).length,
            totalStudents,
          }
        : { ...a, submissions: mine };
    });
  }

  private async load(id: string) {
    const a = await this.assignments.findOne({ where: { id } });
    if (!a) throw new NotFoundException('Không tìm thấy bài tập');
    return a;
  }

  async submit(me: AuthUser, id: string, dto: SubmitDto) {
    const a = await this.load(id);
    await this.classes.assertCanView(me, a.classroom.id); // học sinh phải đã được duyệt vào lớp
    const now = new Date();
    let sub = await this.submissions.findOne({ where: { assignment: { id }, student: { id: me.id } } });
    if (sub?.score != null) throw new BadRequestException('Bài đã được chấm, không nộp lại được');
    if (!sub) sub = this.submissions.create({ assignment: a, student: await this.users.findById(me.id) });
    sub.content = dto.content;
    sub.submittedAt = now;
    sub.late = !!a.dueAt && now > a.dueAt;
    const saved = await this.submissions.save(sub);
    const { assignment: _a, ...rest } = saved;
    return rest;
  }

  async listSubmissions(me: AuthUser, id: string) {
    const a = await this.load(id);
    await this.classes.assertCanManage(me, a.classroom.id);
    return this.submissions.find({ where: { assignment: { id } }, order: { submittedAt: 'ASC' } });
  }

  async grade(me: AuthUser, id: string, subId: string, dto: GradeDto) {
    const a = await this.load(id);
    await this.classes.assertCanManage(me, a.classroom.id);
    if (dto.score > a.maxScore) throw new BadRequestException(`Điểm tối đa là ${a.maxScore}`);
    const sub = await this.submissions.findOne({ where: { id: subId, assignment: { id } } });
    if (!sub) throw new NotFoundException('Không tìm thấy bài nộp');
    sub.score = dto.score;
    sub.feedback = dto.feedback ?? null;
    sub.gradedAt = new Date();
    return this.submissions.save(sub);
  }

  async remove(me: AuthUser, id: string) {
    const a = await this.load(id);
    if (me.role !== Role.Admin && a.classroom.teacher.id !== me.id) throw new ForbiddenException();
    await this.assignments.delete({ id });
  }
}
