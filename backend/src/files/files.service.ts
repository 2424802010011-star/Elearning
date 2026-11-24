import { BadRequestException, ForbiddenException, Injectable, NotFoundException, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { randomUUID } from 'crypto';
import { createReadStream, existsSync, mkdirSync } from 'fs';
import { unlink, writeFile } from 'fs/promises';
import { isAbsolute, join } from 'path';
import { In, Repository } from 'typeorm';
import { Classroom } from '../classes/classroom.entity';
import { ClassesService } from '../classes/classes.service';
import { AuthUser } from '../common/decorators';
import { Role } from '../common/role.enum';
import { UsersService } from '../users/users.service';
import { FileRef, FileVisibility, StoredFile } from './stored-file.entity';

/** Loại file trình duyệt có thể chạy mã: luôn bắt tải về, không mở trực tiếp. */
const RISKY = /html|xml|svg|javascript|ecmascript|x-sh|msdownload/i;
const INLINE = /^(image\/(png|jpe?g|gif|webp)|application\/pdf|video\/|audio\/|text\/plain)/i;

export const toRef = (f: StoredFile): FileRef => ({ id: f.id, name: f.originalName, size: f.size, mimeType: f.mimeType });

@Injectable()
export class FilesService implements OnModuleInit {
  readonly dir: string;
  private readonly linkSecret: string;

  constructor(
    @InjectRepository(StoredFile) private readonly files: Repository<StoredFile>,
    private readonly classes: ClassesService,
    private readonly users: UsersService,
    private readonly jwt: JwtService,
    cfg: ConfigService,
  ) {
    const d = cfg.get<string>('UPLOAD_DIR', 'uploads');
    this.dir = isAbsolute(d) ? d : join(process.cwd(), d);
    // Khóa riêng cho link tải file, để link này không dùng thay token đăng nhập được.
    this.linkSecret = `${cfg.get<string>('JWT_SECRET') ?? 'dev-only-secret-change-me'}#files`;
  }

  onModuleInit() {
    if (!existsSync(this.dir)) mkdirSync(this.dir, { recursive: true });
  }

  async upload(me: AuthUser, file: Express.Multer.File | undefined) {
    if (!file) throw new BadRequestException('Chưa chọn file');
    if (!file.size) throw new BadRequestException('File rỗng');
    // multer đọc tên file theo latin1; đổi lại sang UTF-8 để giữ tên tiếng Việt.
    let name = Buffer.from(file.originalname, 'latin1').toString('utf8');
    if (name.includes('�')) name = file.originalname;
    name = name.replace(/[\\/\0\r\n]/g, '_').trim().slice(0, 200) || 'file';
    const key = randomUUID();
    await writeFile(join(this.dir, key), file.buffer);
    const saved = await this.files.save(
      this.files.create({
        originalName: name,
        mimeType: (file.mimetype || 'application/octet-stream').slice(0, 100),
        size: file.size,
        storageKey: key,
        uploadedBy: await this.users.findById(me.id),
        visibility: FileVisibility.Private,
      }),
    );
    return toRef(saved);
  }

  /** Gắn các file vừa tải lên vào một lớp (khi đăng bài giảng hoặc nộp bài). Chỉ gắn được file của chính mình. */
  async claim(me: AuthUser, ids: string[] | undefined, classroom: Classroom, visibility: FileVisibility): Promise<FileRef[]> {
    const unique = [...new Set(ids ?? [])];
    if (!unique.length) return [];
    const found = await this.files.find({ where: { id: In(unique) } });
    if (found.length !== unique.length) throw new BadRequestException('Có file không tồn tại');
    for (const f of found) {
      if (f.uploadedBy.id !== me.id) throw new ForbiddenException('Chỉ đính kèm được file do bạn tải lên');
      if (f.classroom && f.classroom.id !== classroom.id) throw new BadRequestException('File đã thuộc lớp khác');
      f.classroom = classroom;
      f.visibility = visibility;
    }
    await this.files.save(found);
    return unique.map((id) => toRef(found.find((f) => f.id === id)!));
  }

  private async canRead(me: AuthUser, f: StoredFile): Promise<boolean> {
    if (me.role === Role.Admin || f.uploadedBy.id === me.id) return true;
    if (!f.classroom) return false;
    if (f.classroom.teacher.id === me.id) return true;
    if (f.visibility === FileVisibility.Class) {
      const ids = await this.classes.visibleClassIds(me);
      return ids === 'all' || ids.includes(f.classroom.id);
    }
    if (me.role === Role.Parent) return (await this.users.childrenOf(me.id)).some((c) => c.id === f.uploadedBy.id);
    return false;
  }

  /** Tạo link tải có hạn 10 phút (mở được trong trình duyệt mà không cần gửi token đăng nhập). */
  async link(me: AuthUser, id: string) {
    const f = await this.files.findOne({ where: { id } });
    if (!f) throw new NotFoundException('Không tìm thấy file');
    if (!(await this.canRead(me, f))) throw new ForbiddenException('Bạn không có quyền xem file này');
    const t = await this.jwt.signAsync({ fid: f.id, typ: 'file' }, { secret: this.linkSecret, expiresIn: '10m' });
    return { url: `/api/files/${f.id}/raw?t=${encodeURIComponent(t)}`, ...toRef(f) };
  }

  /** Mở file từ link có hạn. */
  async open(id: string, token: string | undefined) {
    let payload: { fid?: string; typ?: string };
    try {
      payload = await this.jwt.verifyAsync(token ?? '', { secret: this.linkSecret });
    } catch {
      throw new ForbiddenException('Link tải đã hết hạn, hãy mở lại từ app');
    }
    if (payload.typ !== 'file' || payload.fid !== id) throw new ForbiddenException('Link tải không hợp lệ');
    const f = await this.files.findOne({ where: { id } });
    const path = f && join(this.dir, f.storageKey);
    if (!f || !existsSync(path!)) throw new NotFoundException('Không tìm thấy file');
    const risky = RISKY.test(f.mimeType);
    return {
      stream: createReadStream(path!),
      type: risky ? 'application/octet-stream' : f.mimeType,
      disposition: `${!risky && INLINE.test(f.mimeType) ? 'inline' : 'attachment'}; filename*=UTF-8''${encodeURIComponent(f.originalName)}`,
      size: f.size,
    };
  }

  async removeMany(ids: string[]) {
    if (!ids.length) return;
    const found = await this.files.find({ where: { id: In(ids) } });
    await this.files.delete({ id: In(ids) });
    await Promise.all(found.map((f) => unlink(join(this.dir, f.storageKey)).catch(() => undefined)));
  }
}
