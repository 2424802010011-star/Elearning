import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ClassesModule } from '../classes/classes.module';
import { FilesModule } from '../files/files.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { UsersModule } from '../users/users.module';
import { AssignmentsController } from './assignments.controller';
import { AssignmentsService } from './assignments.service';
import { Assignment, Submission } from './entities';

@Module({
  imports: [TypeOrmModule.forFeature([Assignment, Submission]), ClassesModule, UsersModule, FilesModule, NotificationsModule],
  controllers: [AssignmentsController],
  providers: [AssignmentsService],
  exports: [AssignmentsService],
})
export class AssignmentsModule {}
