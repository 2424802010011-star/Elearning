import { Column, CreateDateColumn, Entity, Index, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { User } from '../users/user.entity';

/** Thông báo gửi tới một người dùng. */
@Entity('notifications')
@Index(['userId', 'createdAt'])
export class Notification {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user?: User;

  @Column()
  userId: string;

  /** Loại: assignment_new, graded, quiz_new, lesson_new, meeting_live, enroll_request... */
  @Column()
  type: string;

  @Column()
  title: string;

  @Column({ type: 'text', default: '' })
  body: string;

  /** Lớp liên quan, để app mở đúng lớp khi bấm vào. */
  @Column({ type: 'varchar', nullable: true })
  classId?: string | null;

  /** Tab nên mở trong lớp: lessons, assignments, quizzes, meetings, students. */
  @Column({ type: 'varchar', nullable: true })
  tab?: string | null;

  @Column({ nullable: true })
  readAt?: Date;

  @CreateDateColumn()
  createdAt: Date;
}
