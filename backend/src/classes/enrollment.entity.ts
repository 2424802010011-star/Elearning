import { Column, CreateDateColumn, Entity, ManyToOne, PrimaryGeneratedColumn, Unique, UpdateDateColumn } from 'typeorm';
import { User } from '../users/user.entity';
import { Classroom } from './classroom.entity';

export enum EnrollmentStatus {
  Pending = 'pending',
  Approved = 'approved',
  Rejected = 'rejected',
}

@Entity('enrollments')
@Unique(['classroom', 'student'])
export class Enrollment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Classroom, { onDelete: 'CASCADE' })
  classroom: Classroom;

  @ManyToOne(() => User, { onDelete: 'CASCADE', eager: true })
  student: User;

  @Column({ type: 'simple-enum', enum: EnrollmentStatus, default: EnrollmentStatus.Pending })
  status: EnrollmentStatus;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
