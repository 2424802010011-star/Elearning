import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import * as bcrypt from 'bcryptjs';
import { Repository } from 'typeorm';
import { Role } from '../common/role.enum';
import { ParentLink } from './parent-link.entity';
import { User } from './user.entity';

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

  list(role?: Role): Promise<User[]> {
    return this.users.find({ where: role ? { role } : {}, order: { createdAt: 'ASC' } });
  }

  async updateRole(id: string, role: Role): Promise<User> {
    const user = await this.findById(id);
    user.role = role;
    await this.users.save(user);
    return user;
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

  async childrenOf(parentId: string): Promise<User[]> {
    const links = await this.links.find({ where: { parent: { id: parentId } } });
    return links.map((l) => l.student);
  }
}
