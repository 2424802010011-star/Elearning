import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser, Roles } from '../common/decorators';
import type { AuthUser } from '../common/decorators';
import { Role } from '../common/role.enum';
import { CreateLessonDto } from './dto';
import { LessonsService } from './lessons.service';

@ApiTags('Bài giảng')
@ApiBearerAuth()
@Controller()
export class LessonsController {
  constructor(private readonly svc: LessonsService) {}

  @Post('classes/:id/lessons')
  @Roles(Role.Teacher, Role.Admin)
  @ApiOperation({ summary: 'Đăng bài giảng/tài liệu (kèm file đã tải lên)' })
  create(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: CreateLessonDto) {
    return this.svc.create(me, id, dto);
  }

  @Get('classes/:id/lessons')
  @ApiOperation({ summary: 'Bài giảng của lớp' })
  list(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.svc.list(me, id);
  }

  @Delete('lessons/:id')
  @Roles(Role.Teacher, Role.Admin)
  @HttpCode(204)
  remove(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.svc.remove(me, id);
  }
}
