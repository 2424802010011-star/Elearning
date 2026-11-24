import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { HealthController } from './health.controller';

@Module({ controllers: [AdminController, HealthController] })
export class AdminModule {}
