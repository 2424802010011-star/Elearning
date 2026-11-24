import { CreateDateColumn, Entity, ManyToOne, PrimaryGeneratedColumn, Unique } from 'typeorm';
import { User } from './user.entity';

/** Liên kết phụ huynh với học sinh (một phụ huynh có thể có nhiều con). */
@Entity('parent_links')
@Unique(['parent', 'student'])
export class ParentLink {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE', eager: true })
  parent: User;

  @ManyToOne(() => User, { onDelete: 'CASCADE', eager: true })
  student: User;

  @CreateDateColumn()
  createdAt: Date;
}
