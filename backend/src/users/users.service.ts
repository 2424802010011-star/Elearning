import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import type { AuthUser } from '../common/decorators';
import { InjectRepository } from '@nestjs/typeorm';
import * as bcrypt from 'bcryptjs';
import { Repository, In } from 'typeorm';
import { Classroom } from '../classes/classroom.entity';
import { Role } from '../common/role.enum';
import { ParentLink } from './parent-link.entity';
import { User } from './user.entity';
import { UpdateUserDto } from './dto';

type AuthInfo = Pick<User, 'id' | 'email' | 'role' | 'active'>;

/** Bỏ dấu tiếng Việt để tìm "nguyen" ra "Nguyễn". */
export const fold = (s: string) =>
  s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/đ/g, 'd').replace(/Đ/g, 'D').toLowerCase();

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
    @InjectRepository(ParentLink) private readonly links: Repository<ParentLink>,
  ) {}

  async create(email: string, password: string, fullName: string, role: Role): Promise<User> {
    email = email.trim().toLowerCase();
    if (await this.users.exist({ where: { email } })) throw new ConflictException('Email đã được sử dụng');
    const passwordHash = await bcrypt.hash(password, 10);
    const saved = await this.users.save(this.users.create({ email, passwordHash, fullName, role }));
    return this.findById(saved.id);
  }

  async findById(id: string): Promise<User> {
    const user = await this.users.findOne({ where: { id } });
    if (!user) throw new NotFoundException('Không tìm thấy người dùng');
    return user;
  }

  findByEmailWithPassword(email: string): Promise<User | null> {
    return this.users
      .createQueryBuilder('u')
      .addSelect('u.passwordHash')
      .where('u.email = :email', { email: email.trim().toLowerCase() })
      .getOne();
  }

  /** Thông tin cho guard: kiểm tra vai trò hiện tại và tài khoản còn mở. Lưu đệm 10 giây. */
  private readonly authCache = new Map<string, { at: number; info: AuthInfo | null }>();

  async authInfo(id: string): Promise<AuthInfo | null> {
    const hit = this.authCache.get(id);
    if (hit && Date.now() - hit.at < 10_000) return hit.info;
    const u = await this.users.findOne({ where: { id }, select: { id: true, email: true, role: true, active: true } });
    const info = u ? { id: u.id, email: u.email, role: u.role, active: u.active } : null;
    if (this.authCache.size > 5000) this.authCache.clear();
    this.authCache.set(id, { at: Date.now(), info });
    return info;
  }

  async list(role?: Role, q?: string): Promise<User[]> {
    const all = await this.users.find({ where: role ? { role } : {}, order: { createdAt: 'ASC' } });
    const needle = fold(q?.trim() ?? '');
    return needle ? all.filter((u) => fold(`${u.fullName} ${u.email}`).includes(needle)) : all;
  }

  updateRole(id: string, role: Role, me?: AuthUser): Promise<User> {
    return this.update(id, { role }, me);
  }

  /** Admin sửa tên, đổi vai trò, khóa / mở khóa tài khoản. */
  async update(id: string, dto: UpdateUserDto, me?: AuthUser): Promise<User> {
    const user = await this.findById(id);
    if (me?.id === id && (dto.active === false || (dto.role && dto.role !== Role.Admin))) {
      throw new BadRequestException('Không thể tự khóa hoặc tự bỏ quyền admin của chính mình');
    }
    if (dto.role && dto.role !== user.role) {
      if (user.role === Role.Teacher) {
        const n = await this.users.manager.count(Classroom, { where: { teacher: { id } } });
        if (n) throw new ConflictException(`Giáo viên đang phụ trách ${n} lớp, hãy chuyển lớp cho giáo viên khác trước`);
      }
      // Liên kết phụ huynh - học sinh không còn đúng khi đổi vai trò.
      if (user.role === Role.Parent) await this.links.delete({ parent: { id } });
      if (user.role === Role.Student) await this.links.delete({ student: { id } });
      user.role = dto.role;
    }
    if (dto.fullName !== undefined) user.fullName = dto.fullName.trim();
    if (dto.active !== undefined) user.active = dto.active;
    await this.users.save(user);
    this.authCache.delete(id);
    return user;
  }

  async resetPassword(id: string, password: string): Promise<void> {
    await this.findById(id);
    await this.users.update(id, { passwordHash: await bcrypt.hash(password, 10) });
  }

  async adminExists(): Promise<boolean> {
    return this.users.exist({ where: { role: Role.Admin } });
  }

  async linkParent(parentId: string, studentId: string): Promise<ParentLink> {
    const parent = await this.findById(parentId);
    const student = await this.findById(studentId);
    if (parent.role !== Role.Parent) throw new BadRequestException('Tài khoản thứ nhất không phải phụ huynh');
    if (student.role !== Role.Student) throw new BadRequestException('Tài khoản thứ hai không phải học sinh');
    const existing = await this.links.findOne({ where: { parent: { id: parentId }, student: { id: studentId } } });
    if (existing) throw new ConflictException('Đã liên kết từ trước');
    return this.links.save(this.links.create({ parent, student }));
  }

  listLinks(): Promise<ParentLink[]> {
    return this.links.find({ order: { createdAt: 'ASC' } });
  }

  async unlink(id: string): Promise<void> {
    const r = await this.links.delete({ id });
    if (!r.affected) throw new NotFoundException('Không tìm thấy liên kết');
  }

  /** Id phụ huynh của các học sinh. */
  async parentIdsOf(studentIds: string[]): Promise<string[]> {
    if (!studentIds.length) return [];
    const links = await this.links.find({ where: { student: { id: In(studentIds) } } });
    return [...new Set(links.map((l) => l.parent.id))];
  }

  async childrenOf(parentId: string): Promise<User[]> {
    const links = await this.links.find({ where: { parent: { id: parentId } } });
    return links.map((l) => l.student);
  }
}
