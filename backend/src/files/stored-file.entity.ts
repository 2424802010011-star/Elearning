import { Column, CreateDateColumn, Entity, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Classroom } from '../classes/classroom.entity';
import { User } from '../users/user.entity';

/** Ai được tải file: cả lớp (tài liệu bài giảng) hoặc riêng (bài nộp: người nộp, giáo viên, phụ huynh). */
export enum FileVisibility {
  Class = 'class',
  Private = 'private',
}

/** Thông tin file gắn vào bài giảng/bài nộp. */
export interface FileRef {
  id: string;
  name: string;
  size: number;
  mimeType: string;
}

@Entity('files')
export class StoredFile {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  originalName: string;

  @Column()
  mimeType: string;

  @Column({ type: 'int' })
  size: number;

  /** Tên file trên đĩa (trong UPLOAD_DIR). */
  @Column()
  storageKey: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE', eager: true })
  uploadedBy: User;

  /** Lớp mà file thuộc về (gán khi file được đính kèm vào bài giảng/bài nộp). */
  @ManyToOne(() => Classroom, { onDelete: 'CASCADE', eager: true, nullable: true })
  classroom?: Classroom | null;

  @Column({ type: 'simple-enum', enum: FileVisibility, default: FileVisibility.Private })
  visibility: FileVisibility;

  @CreateDateColumn()
  createdAt: Date;
}
