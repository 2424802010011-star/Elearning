import { Column, CreateDateColumn, Entity, ManyToOne, PrimaryGeneratedColumn, Unique } from 'typeorm';
import { Classroom } from '../classes/classroom.entity';
import type { FileRef } from '../files/stored-file.entity';
import { User } from '../users/user.entity';

@Entity('assignments')
export class Assignment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Classroom, { onDelete: 'CASCADE', eager: true })
  classroom: Classroom;

  @Column()
  title: string;

  @Column({ type: 'text', default: '' })
  description: string;

  /** Hạn nộp (để trống = không có hạn). */
  @Column({ nullable: true })
  dueAt?: Date;

  @Column({ type: 'real', default: 10 })
  maxScore: number;

  @CreateDateColumn()
  createdAt: Date;
}

@Entity('submissions')
@Unique(['assignment', 'student'])
export class Submission {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Assignment, { onDelete: 'CASCADE' })
  assignment: Assignment;

  @ManyToOne(() => User, { onDelete: 'CASCADE', eager: true })
  student: User;

  @Column({ type: 'text' })
  content: string;

  /** File đính kèm bài nộp (ảnh chụp bài làm, PDF...). */
  @Column({ type: 'simple-json', nullable: true })
  attachments?: FileRef[] | null;

  @Column()
  submittedAt: Date;

  @Column({ default: false })
  late: boolean;

  @Column({ type: 'real', nullable: true })
  score?: number | null;

  @Column({ type: 'text', nullable: true })
  feedback?: string | null;

  @Column({ nullable: true })
  gradedAt?: Date;
}
