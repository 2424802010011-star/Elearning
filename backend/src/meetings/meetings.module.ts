import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BoardHub } from '../board/board.hub';
import { ClassesModule } from '../classes/classes.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { UsersModule } from '../users/users.module';
import { Meeting } from './meeting.entity';
import { MeetingsController } from './meetings.controller';
import { MeetingsService } from './meetings.service';

@Module({
  imports: [TypeOrmModule.forFeature([Meeting]), ClassesModule, UsersModule, NotificationsModule],
  controllers: [MeetingsController],
  providers: [MeetingsService, BoardHub],
  exports: [MeetingsService, BoardHub],
})
export class MeetingsModule {}
