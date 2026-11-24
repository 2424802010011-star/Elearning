import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersModule } from '../users/users.module';
import { ClassesController } from './classes.controller';
import { ClassesService } from './classes.service';
import { Classroom } from './classroom.entity';
import { Enrollment } from './enrollment.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Classroom, Enrollment]), UsersModule],
  controllers: [ClassesController],
  providers: [ClassesService],
  exports: [ClassesService],
})
export class ClassesModule {}
