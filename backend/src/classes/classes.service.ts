import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { randomInt } from 'crypto';
import { In, Repository } from 'typeorm';
import { AuthUser } from '../common/decorators';
import { Role } from '../common/role.enum';
import { UsersService } from '../users/users.service';
import { Classroom } from './classroom.entity';
import { CreateClassDto } from './dto';
import { Enrollment, EnrollmentStatus } from './enrollment.entity';

// Bỏ các ký tự dễ nhầm (0/O, 1/I/L) để học sinh nhập mã không bị sai.
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

@Injectable()
export class ClassesService {
  constructor(
    @InjectRepository(Classroom) private readonly classes: Repository<Classroom>,
    @InjectRepository(Enrollment) private readonly enrollments: Repository<Enrollment>,
    private readonly users: UsersService,
  ) {}

  private async newInviteCode(): Promise<string> {
    for (let attempt = 0; attempt < 10; attempt++) {
      const code = Array.from({ length: 6 }, () => CODE_ALPHABET[randomInt(CODE_ALPHABET.length)]).join('');
      if (!(await this.classes.exist({ where: { inviteCode: code } }))) return code;
    }
    throw new ConflictException('Không tạo được mã mời, vui lòng thử lại');
  }

  async create(me: AuthUser, dto: CreateClassDto): Promise<Classroom> {
    const teacher = await this.users.findById(me.id);
    const inviteCode = await this.newInviteCode();
    return this.classes.save(this.classes.create({ ...dto, inviteCode, teacher }));
  }

  async get(id: string): Promise<Classroom> {
    const c = await this.classes.findOne({ where: { id } });
    if (!c) throw new NotFoundException('Không tìm thấy lớp học');
    return c;
  }

  /** Danh sách id lớp mà người dùng được xem, theo vai trò. */
  async visibleClassIds(me: AuthUser): Promise<string[] | 'all'> {
    switch (me.role) {
      case Role.Admin:
        return 'all';
      case Role.Teacher:
        return (await this.classes.find({ where: { teacher: { id: me.id } }, select: { id: true } })).map((c) => c.id);
      case Role.Student:
        return this.approvedClassIdsFor([me.id]);
      case Role.Parent: {
        const children = await this.users.childrenOf(me.id);
        return children.length ? this.approvedClassIdsFor(children.map((c) => c.id)) : [];
      }
    }
  }

  private async approvedClassIdsFor(studentIds: string[]): Promise<string[]> {
    const rows = await this.enrollments.find({
      where: { student: { id: In(studentIds) }, status: EnrollmentStatus.Approved },
      relations: { classroom: true },
    });
    return [...new Set(rows.map((r) => r.classroom.id))];
  }

  async listFor(me: AuthUser): Promise<Classroom[]> {
    const ids = await this.visibleClassIds(me);
    if (ids === 'all') return this.classes.find({ order: { createdAt: 'DESC' } });
    if (ids.length === 0) return [];
    return this.classes.find({ where: { id: In(ids) }, order: { createdAt: 'DESC' } });
  }

  async assertCanView(me: AuthUser, classId: string): Promise<Classroom> {
    const c = await this.get(classId);
    const ids = await this.visibleClassIds(me);
    if (ids !== 'all' && !ids.includes(classId)) throw new ForbiddenException('Bạn không thuộc lớp này');
    return c;
  }

  async assertCanManage(me: AuthUser, classId: string): Promise<Classroom> {
    const c = await this.get(classId);
    if (me.role !== Role.Admin && c.teacher.id !== me.id) {
      throw new ForbiddenException('Chỉ giáo viên chủ lớp hoặc admin được thao tác');
    }
    return c;
  }

  /** Học sinh nhập mã mời: tạo yêu cầu chờ duyệt. Bị từ chối trước đó thì gửi lại được. */
  async join(me: AuthUser, inviteCode: string): Promise<Enrollment> {
    const classroom = await this.classes.findOne({ where: { inviteCode: inviteCode.trim().toUpperCase() } });
    if (!classroom) throw new NotFoundException('Mã mời không đúng');
    const existing = await this.enrollments.findOne({
      where: { classroom: { id: classroom.id }, student: { id: me.id } },
    });
    if (existing) {
      if (existing.status === EnrollmentStatus.Rejected) {
        existing.status = EnrollmentStatus.Pending;
        return this.enrollments.save(existing);
      }
      throw new ConflictException(
        existing.status === EnrollmentStatus.Approved ? 'Bạn đã ở trong lớp này' : 'Yêu cầu đang chờ giáo viên duyệt',
      );
    }
    const student = await this.users.findById(me.id);
    const saved = await this.enrollments.save(this.enrollments.create({ classroom, student }));
    return { ...saved, classroom } as Enrollment;
  }

  async listEnrollments(me: AuthUser, classId: string, status?: EnrollmentStatus): Promise<Enrollment[]> {
    await this.assertCanManage(me, classId);
    return this.enrollments.find({
      where: { classroom: { id: classId }, ...(status ? { status } : {}) },
      order: { createdAt: 'ASC' },
    });
  }

  async review(me: AuthUser, classId: string, enrollmentId: string, status: EnrollmentStatus): Promise<Enrollment> {
    await this.assertCanManage(me, classId);
    const e = await this.enrollments.findOne({ where: { id: enrollmentId, classroom: { id: classId } } });
    if (!e) throw new NotFoundException('Không tìm thấy yêu cầu');
    e.status = status;
    return this.enrollments.save(e);
  }

  async regenerateCode(me: AuthUser, classId: string): Promise<Classroom> {
    const c = await this.assertCanManage(me, classId);
    c.inviteCode = await this.newInviteCode();
    return this.classes.save(c);
  }

  /** Id các học sinh đã được duyệt vào lớp. */
  async approvedStudentIds(classId: string): Promise<string[]> {
    const rows = await this.enrollments.find({
      where: { classroom: { id: classId }, status: EnrollmentStatus.Approved },
    });
    return rows.map((r) => r.student.id);
  }
}
