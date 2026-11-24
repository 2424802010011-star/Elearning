import { Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../common/decorators';
import type { AuthUser } from '../common/decorators';
import { NotificationsService } from './notifications.service';

@ApiTags('Thông báo')
@ApiBearerAuth()
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly svc: NotificationsService) {}

  @Get()
  @ApiOperation({ summary: 'Thông báo của tôi (mới nhất trước) và số chưa đọc' })
  @ApiQuery({ name: 'unread', required: false, type: Boolean })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  list(@CurrentUser() me: AuthUser, @Query('unread') unread?: string, @Query('limit') limit?: string) {
    return this.svc.list(me, unread === 'true', Number(limit) || 50);
  }

  @Get('unread-count')
  @ApiOperation({ summary: 'Số thông báo chưa đọc (app hỏi định kỳ để hiện số trên chuông)' })
  count(@CurrentUser() me: AuthUser) {
    return this.svc.unreadCount(me);
  }

  @Post('read-all')
  @HttpCode(200)
  readAll(@CurrentUser() me: AuthUser) {
    return this.svc.markAllRead(me);
  }

  @Post(':id/read')
  @HttpCode(200)
  read(@CurrentUser() me: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.svc.markRead(me, id);
  }
}
