import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser, Roles } from '../common/decorators';
import type { AuthUser } from '../common/decorators';
import { Role } from '../common/role.enum';
import { BoardPermissionsDto, CreateMeetingDto } from './dto';
import { MeetingsService } from './meetings.service';

@ApiTags('Họp trực tuyến & bảng trắng')
@ApiBearerAuth()
@Controller()
export class MeetingsController {
  constructor(private readonly meetings: MeetingsService) {}

  @Post('classes/:id/meetings')
  @Roles(Role.Teacher, Role.Admin)
  @ApiOperation({ summary: 'Tạo cuộc họp cho lớp (họp ngay hoặc lên lịch)' })
  create(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: CreateMeetingDto) {
    return this.meetings.create(me, id, dto);
  }

  @Get('classes/:id/meetings')
  @ApiOperation({ summary: 'Danh sách cuộc họp của lớp' })
  list(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.meetings.listForClass(me, id);
  }

  @Get('meetings/:id')
  get(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.meetings.get(me, id);
  }

  @Post('meetings/:id/join')
  @HttpCode(200)
  @ApiOperation({ summary: 'Vào phòng: trả về token LiveKit và quyền viết bảng' })
  join(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.meetings.join(me, id);
  }

  @Post('meetings/:id/end')
  @HttpCode(200)
  @Roles(Role.Teacher, Role.Admin)
  @ApiOperation({ summary: 'Kết thúc cuộc họp' })
  end(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.meetings.end(me, id);
  }

  @Get('meetings/:id/whiteboard/permissions')
  @ApiOperation({ summary: 'Xem ai được viết lên bảng' })
  permissions(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.meetings.boardPermissions(me, id);
  }

  @Put('meetings/:id/whiteboard/permissions')
  @Roles(Role.Teacher, Role.Admin)
  @ApiOperation({ summary: 'Giáo viên cấp/thu quyền viết bảng cho học sinh' })
  setPermissions(
    @CurrentUser() me: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: BoardPermissionsDto,
  ) {
    return this.meetings.setBoardPermissions(me, id, dto);
  }
}
