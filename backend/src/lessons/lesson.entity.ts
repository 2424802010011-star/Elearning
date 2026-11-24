import { Column, CreateDateColumn, Entity, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Classroom } from '../classes/classroom.entity';
import type { FileRef } from '../files/stored-file.entity';

/** Bài giảng / tài liệu của lớp: nội dung chữ và file đính kèm (PDF, slide, video...). */
@Entity('lessons')
export class Lesson {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Classroom, { onDelete: 'CASCADE', eager: true })
  classroom: Classroom;

  @Column()
  title: string;

  @Column({ type: 'text', default: '' })
  content: string;

  @Column({ type: 'simple-json' })
  attachments: FileRef[];

  @CreateDateColumn()
  createdAt: Date;
}
