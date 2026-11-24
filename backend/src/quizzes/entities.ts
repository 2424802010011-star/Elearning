import { Column, CreateDateColumn, Entity, ManyToOne, PrimaryGeneratedColumn, Unique } from 'typeorm';
import { Classroom } from '../classes/classroom.entity';
import { User } from '../users/user.entity';

export interface QuizQuestion {
  id: string;
  text: string;
  options: string[];
  /** Vị trí các đáp án đúng (một hoặc nhiều). */
  correct: number[];
  points: number;
}

@Entity('quizzes')
export class Quiz {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Classroom, { onDelete: 'CASCADE', eager: true })
  classroom: Classroom;

  @Column()
  title: string;

  @Column({ type: 'text', default: '' })
  description: string;

  /** Thời gian làm bài (phút). Để trống = không giới hạn. */
  @Column({ type: 'int', nullable: true })
  durationMinutes?: number | null;

  /** Hạn chót để bắt đầu và nộp bài. */
  @Column({ nullable: true })
  dueAt?: Date;

  /** Chưa phát hành thì học sinh không thấy đề. */
  @Column({ default: false })
  published: boolean;

  /** Cho học sinh xem đáp án đúng sau khi nộp. */
  @Column({ default: true })
  showAnswers: boolean;

  @Column({ type: 'simple-json' })
  questions: QuizQuestion[];

  @CreateDateColumn()
  createdAt: Date;
}

@Entity('quiz_attempts')
@Unique(['quiz', 'student'])
export class QuizAttempt {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Quiz, { onDelete: 'CASCADE' })
  quiz: Quiz;

  @ManyToOne(() => User, { onDelete: 'CASCADE', eager: true })
  student: User;

  @Column()
  startedAt: Date;

  /** Câu trả lời: id câu hỏi -> các lựa chọn. */
  @Column({ type: 'simple-json', nullable: true })
  answers?: Record<string, number[]> | null;

  @Column({ nullable: true })
  submittedAt?: Date;

  @Column({ type: 'real', nullable: true })
  score?: number | null;

  @Column({ type: 'real' })
  maxScore: number;

  /** Nộp sau khi hết giờ hoặc quá hạn. */
  @Column({ default: false })
  late: boolean;
}
