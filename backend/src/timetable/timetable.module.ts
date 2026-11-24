import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ClassesModule } from '../classes/classes.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { ReminderLog } from './reminder-log.entity';
import { RemindersService } from './reminders.service';
import { TimetableEntry } from './timetable-entry.entity';
import { TimetableController } from './timetable.controller';
import { TimetableService } from './timetable.service';

@Module({
  imports: [TypeOrmModule.forFeature([TimetableEntry, ReminderLog]), ClassesModule, NotificationsModule],
  controllers: [TimetableController],
  providers: [TimetableService, RemindersService],
  exports: [TimetableService, RemindersService],
})
export class TimetableModule {}
