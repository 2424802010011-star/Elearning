import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser, Roles } from '../common/decorators';
import type { AuthUser } from '../common/decorators';
import { Role } from '../common/role.enum';
import { AssignmentsService } from './assignments.service';
import { CreateAssignmentDto, GradeDto, SubmitDto } from './dto';

@ApiTags('Bài tập')
@ApiBearerAuth()
@Controller()
export class AssignmentsController {
  constructor(private readonly svc: AssignmentsService) {}

  @Post('classes/:id/assignments')
  @Roles(Role.Teacher, Role.Admin)
  @ApiOperation({ summary: 'Giao bài tập cho lớp' })
  create(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: CreateAssignmentDto) {
    return this.svc.create(me, id, dto);
  }

  @Get('classes/:id/assignments')
  @ApiOperation({ summary: 'Bài tập của lớp (GV: kèm số bài đã nộp; HS/PH: kèm bài nộp của mình/con)' })
  list(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.svc.listForClass(me, id);
  }

  @Post('assignments/:id/submit')
  @Roles(Role.Student)
  @ApiOperation({ summary: 'Học sinh nộp bài (nộp lại được khi chưa chấm)' })
  submit(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: SubmitDto) {
    return this.svc.submit(me, id, dto);
  }

  @Get('assignments/:id/submissions')
  @Roles(Role.Teacher, Role.Admin)
  submissions(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.svc.listSubmissions(me, id);
  }

  @Patch('assignments/:id/submissions/:subId')
  @Roles(Role.Teacher, Role.Admin)
  @ApiOperation({ summary: 'Chấm điểm và nhận xét' })
  grade(
    @CurrentUser() me: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('subId', ParseUUIDPipe) subId: string,
    @Body() dto: GradeDto,
  ) {
    return this.svc.grade(me, id, subId, dto);
  }

  @Delete('assignments/:id')
  @Roles(Role.Teacher, Role.Admin)
  @HttpCode(204)
  remove(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.svc.remove(me, id);
  }
}
