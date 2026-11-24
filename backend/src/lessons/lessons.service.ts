import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ClassesService } from '../classes/classes.service';
import { AuthUser } from '../common/decorators';
import { FilesService } from '../files/files.service';
import { FileVisibility } from '../files/stored-file.entity';
import { CreateLessonDto } from './dto';
import { Lesson } from './lesson.entity';

@Injectable()
export class LessonsService {
  constructor(
    @InjectRepository(Lesson) private readonly lessons: Repository<Lesson>,
    private readonly classes: ClassesService,
    private readonly files: FilesService,
  ) {}

  private view(l: Lesson) {
    const { classroom: _c, ...rest } = l;
    return rest;
  }

  async create(me: AuthUser, classId: string, dto: CreateLessonDto) {
    const classroom = await this.classes.assertCanManage(me, classId);
    const attachments = await this.files.claim(me, dto.fileIds, classroom, FileVisibility.Class);
    const saved = await this.lessons.save(
      this.lessons.create({ classroom, title: dto.title.trim(), content: dto.content ?? '', attachments }),
    );
    return this.view(saved);
  }

  async list(me: AuthUser, classId: string) {
    await this.classes.assertCanView(me, classId);
    const list = await this.lessons.find({ where: { classroom: { id: classId } }, order: { createdAt: 'DESC' } });
    return list.map((l) => this.view(l));
  }

  async remove(me: AuthUser, id: string) {
    const l = await this.lessons.findOne({ where: { id } });
    if (!l) throw new NotFoundException('Không tìm thấy bài giảng');
    await this.classes.assertCanManage(me, l.classroom.id);
    await this.lessons.delete({ id });
    await this.files.removeMany(l.attachments.map((a) => a.id));
  }
}
