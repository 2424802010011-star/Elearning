import { Column, CreateDateColumn, Entity, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Classroom } from '../classes/classroom.entity';
import { User } from '../users/user.entity';

export enum MeetingStatus {
  Scheduled = 'scheduled',
  Live = 'live',
  Ended = 'ended',
}

@Entity('meetings')
export class Meeting {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Classroom, { onDelete: 'CASCADE', eager: true })
  classroom: Classroom;

  @ManyToOne(() => User, { onDelete: 'SET NULL', eager: true, nullable: true })
  host: User;

  @Column()
  title: string;

  /** Thời điểm dự kiến bắt đầu (để trống = họp ngay). */
  @Column({ nullable: true })
  scheduledAt?: Date;

  @Column({ type: 'simple-enum', enum: MeetingStatus, default: MeetingStatus.Scheduled })
  status: MeetingStatus;

  /** Tên phòng trên máy chủ LiveKit. */
  @Column({ unique: true })
  roomName: string;

  @Column({ nullable: true })
  startedAt?: Date;

  @Column({ nullable: true })
  endedAt?: Date;

  /** Bảng trắng: true = cả lớp được viết. */
  @Column({ default: false })
  boardAllowAll: boolean;

  /** Bảng trắng: id các học sinh được giáo viên cho phép viết. */
  @Column({ type: 'simple-array', default: '' })
  boardWriters: string[];

  @CreateDateColumn()
  createdAt: Date;
}
