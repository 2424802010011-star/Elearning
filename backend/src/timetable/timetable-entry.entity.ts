import { Column, CreateDateColumn, Entity, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Classroom } from '../classes/classroom.entity';

/** Một tiết học lặp lại hằng tuần trong khoảng [startDate, endDate]. */
@Entity('timetable_entries')
export class TimetableEntry {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Classroom, { onDelete: 'CASCADE', eager: true })
  classroom: Classroom;

  @Column()
  title: string;

  /** 1 = Thứ Hai ... 7 = Chủ Nhật (chuẩn ISO). */
  @Column({ type: 'smallint' })
  dayOfWeek: number;

  /** 'HH:mm' */
  @Column({ length: 5 })
  startTime: string;

  @Column({ length: 5 })
  endTime: string;

  /** 'YYYY-MM-DD' */
  @Column({ type: 'date' })
  startDate: string;

  @Column({ type: 'date', nullable: true })
  endDate?: string | null;

  /** Phòng học hoặc ghi chú (ví dụ "Học online"). */
  @Column({ nullable: true })
  location?: string;

  @CreateDateColumn()
  createdAt: Date;
}
