import { CreateDateColumn, Entity, PrimaryGeneratedColumn, Column, Unique } from 'typeorm';

/** Đánh dấu đã nhắc giờ học cho một tiết trong một ngày, để không nhắc hai lần (kể cả khi chạy nhiều máy chủ). */
@Entity('reminder_logs')
@Unique(['entryId', 'date'])
export class ReminderLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  entryId: string;

  /** 'YYYY-MM-DD' theo giờ địa phương */
  @Column({ length: 10 })
  date: string;

  @CreateDateColumn()
  createdAt: Date;
}
