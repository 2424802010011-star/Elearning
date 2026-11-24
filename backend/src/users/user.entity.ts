import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn } from 'typeorm';
import { Role } from '../common/role.enum';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  email: string;

  @Column({ select: false })
  passwordHash: string;

  @Column()
  fullName: string;

  @Column({ type: 'simple-enum', enum: Role })
  role: Role;

  /** false = tài khoản bị admin khóa, không đăng nhập và không gọi API được. */
  @Column({ default: true })
  active: boolean;

  @CreateDateColumn()
  createdAt: Date;
}
