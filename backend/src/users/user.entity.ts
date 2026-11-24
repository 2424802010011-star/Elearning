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

  @Column({ type: 'enum', enum: Role })
  role: Role;

  @CreateDateColumn()
  createdAt: Date;
}
