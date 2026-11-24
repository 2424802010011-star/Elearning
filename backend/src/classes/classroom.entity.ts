import { Column, CreateDateColumn, Entity, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { User } from '../users/user.entity';

@Entity('classrooms')
export class Classroom {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ nullable: true })
  subject?: string;

  @Column({ type: 'text', nullable: true })
  description?: string;

  /** Mã mời để học sinh xin vào lớp. */
  @Column({ unique: true, length: 8 })
  inviteCode: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE', eager: true })
  teacher: User;

  @CreateDateColumn()
  createdAt: Date;
}
