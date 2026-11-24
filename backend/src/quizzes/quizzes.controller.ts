import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser, Roles } from '../common/decorators';
import type { AuthUser } from '../common/decorators';
import { Role } from '../common/role.enum';
import { CreateQuizDto, SubmitQuizDto, UpdateQuizDto } from './dto';
import { QuizzesService } from './quizzes.service';

@ApiTags('Kiểm tra trắc nghiệm')
@ApiBearerAuth()
@Controller()
export class QuizzesController {
  constructor(private readonly svc: QuizzesService) {}

  @Post('classes/:id/quizzes')
  @Roles(Role.Teacher, Role.Admin)
  @ApiOperation({ summary: 'Soạn đề trắc nghiệm cho lớp' })
  create(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: CreateQuizDto) {
    return this.svc.create(me, id, dto);
  }

  @Get('classes/:id/quizzes')
  @ApiOperation({ summary: 'Bài kiểm tra của lớp (GV: kèm thống kê; HS/PH: kèm lượt làm của mình/con)' })
  list(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.svc.listForClass(me, id);
  }

  @Get('quizzes/:id')
  @ApiOperation({ summary: 'Xem đề (HS không thấy đáp án khi đang làm)' })
  get(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.svc.get(me, id);
  }

  @Post('quizzes/:id/start')
  @Roles(Role.Student)
  @HttpCode(200)
  @ApiOperation({ summary: 'Học sinh bắt đầu (hoặc tiếp tục) làm bài, đồng hồ bắt đầu chạy' })
  start(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.svc.start(me, id);
  }

  @Post('quizzes/:id/submit')
  @Roles(Role.Student)
  @HttpCode(200)
  @ApiOperation({ summary: 'Nộp bài, chấm điểm tự động' })
  submit(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: SubmitQuizDto) {
    return this.svc.submit(me, id, dto);
  }

  @Get('quizzes/:id/results')
  @Roles(Role.Teacher, Role.Admin)
  @ApiOperation({ summary: 'Điểm cả lớp và tỉ lệ đúng từng câu' })
  results(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.svc.results(me, id);
  }

  @Patch('quizzes/:id')
  @Roles(Role.Teacher, Role.Admin)
  @ApiOperation({ summary: 'Sửa đề, phát hành/ẩn (câu hỏi chỉ sửa được khi chưa ai làm)' })
  update(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateQuizDto) {
    return this.svc.update(me, id, dto);
  }

  @Delete('quizzes/:id')
  @Roles(Role.Teacher, Role.Admin)
  @HttpCode(204)
  remove(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.svc.remove(me, id);
  }
}
