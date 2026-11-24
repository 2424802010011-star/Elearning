import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { CurrentUser, Roles } from '../common/decorators';
import type { AuthUser } from '../common/decorators';
import { Role } from '../common/role.enum';
import { CreateEntryDto } from './dto';
import { TimetableService } from './timetable.service';

@ApiTags('Thời khóa biểu')
@ApiBearerAuth()
@Controller()
export class TimetableController {
  constructor(private readonly timetable: TimetableService) {}

  @Post('classes/:id/timetable')
  @Roles(Role.Teacher, Role.Admin)
  create(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: CreateEntryDto) {
    return this.timetable.create(me, id, dto);
  }

  @Get('classes/:id/timetable')
  list(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.timetable.listForClass(me, id);
  }

  @Delete('classes/:id/timetable/:entryId')
  @Roles(Role.Teacher, Role.Admin)
  @HttpCode(204)
  remove(
    @CurrentUser() me: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('entryId', ParseUUIDPipe) entryId: string,
  ) {
    return this.timetable.remove(me, id, entryId);
  }

  /** ?date=YYYY-MM-DD, mặc định là tuần hiện tại. */
  @Get('timetable/week')
  week(@CurrentUser() me: AuthUser, @Query('date') date?: string) {
    return this.timetable.week(me, date);
  }
}
