import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { CurrentUser, Roles } from '../common/decorators';
import type { AuthUser } from '../common/decorators';
import { Role } from '../common/role.enum';
import { ClassesService } from './classes.service';
import { CreateClassDto, JoinClassDto, ReviewEnrollmentDto } from './dto';
import { EnrollmentStatus } from './enrollment.entity';

@ApiTags('Lớp học')
@ApiBearerAuth()
@Controller('classes')
export class ClassesController {
  constructor(private readonly classes: ClassesService) {}

  @Post()
  @Roles(Role.Teacher, Role.Admin)
  create(@CurrentUser() me: AuthUser, @Body() dto: CreateClassDto) {
    return this.classes.create(me, dto);
  }

  /** Admin: mọi lớp. Giáo viên: lớp mình dạy. Học sinh: lớp đã được duyệt. Phụ huynh: lớp của con. */
  @Get()
  list(@CurrentUser() me: AuthUser) {
    return this.classes.listFor(me);
  }

  @Post('join')
  @Roles(Role.Student)
  join(@CurrentUser() me: AuthUser, @Body() dto: JoinClassDto) {
    return this.classes.join(me, dto.inviteCode);
  }

  @Get(':id')
  get(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.classes.assertCanView(me, id);
  }

  @Get(':id/enrollments')
  @Roles(Role.Teacher, Role.Admin)
  enrollments(
    @CurrentUser() me: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Query('status') status?: EnrollmentStatus,
  ) {
    return this.classes.listEnrollments(me, id, status);
  }

  @Patch(':id/enrollments/:enrollmentId')
  @Roles(Role.Teacher, Role.Admin)
  review(
    @CurrentUser() me: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('enrollmentId', ParseUUIDPipe) enrollmentId: string,
    @Body() dto: ReviewEnrollmentDto,
  ) {
    return this.classes.review(me, id, enrollmentId, dto.status);
  }

  @Post(':id/invite-code')
  @Roles(Role.Teacher, Role.Admin)
  regenerate(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.classes.regenerateCode(me, id);
  }
}
