import { Controller, Get, Param, ParseUUIDPipe, Post, Query, Res, StreamableFile, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiBody, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';
import { CurrentUser, Public } from '../common/decorators';
import type { AuthUser } from '../common/decorators';
import { FilesService } from './files.service';

export const MAX_UPLOAD_MB = Number(process.env.MAX_UPLOAD_MB ?? 50);

@ApiTags('File')
@ApiBearerAuth()
@Controller('files')
export class FilesController {
  constructor(private readonly svc: FilesService) {}

  @Post()
  @ApiOperation({ summary: `Tải một file lên (tối đa ${MAX_UPLOAD_MB} MB). Sau đó gửi id file khi đăng bài giảng hoặc nộp bài.` })
  @ApiConsumes('multipart/form-data')
  @ApiBody({ schema: { type: 'object', properties: { file: { type: 'string', format: 'binary' } } } })
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: MAX_UPLOAD_MB * 1024 * 1024, files: 1 } }))
  upload(@CurrentUser() me: AuthUser, @UploadedFile() file: Express.Multer.File) {
    return this.svc.upload(me, file);
  }

  @Get(':id/link')
  @ApiOperation({ summary: 'Lấy link tải file (hết hạn sau 10 phút)' })
  link(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.svc.link(me, id);
  }

  @Get(':id/raw')
  @Public()
  @ApiOperation({ summary: 'Mở/tải file bằng link lấy từ /files/{id}/link' })
  async raw(@Param('id', ParseUUIDPipe) id: string, @Query('t') t: string, @Res({ passthrough: true }) res: Response) {
    const f = await this.svc.open(id, t);
    res.set({
      'Content-Type': f.type,
      'Content-Disposition': f.disposition,
      'Content-Length': String(f.size),
      'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': "default-src 'none'; img-src 'self'; media-src 'self'; style-src 'unsafe-inline'; sandbox",
      'Cache-Control': 'private, max-age=600',
    });
    return new StreamableFile(f.stream);
  }
}
