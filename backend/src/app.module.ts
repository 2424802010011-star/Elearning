import { Logger, Module, OnApplicationBootstrap } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from './auth/auth.module';
import { ClassesModule } from './classes/classes.module';
import { JwtAuthGuard, RolesGuard } from './common/guards';
import { Role } from './common/role.enum';
import { TimetableModule } from './timetable/timetable.module';
import { UsersModule } from './users/users.module';
import { UsersService } from './users/users.service';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => ({
        type: 'postgres',
        url: cfg.getOrThrow<string>('DATABASE_URL'),
        autoLoadEntities: true,
        synchronize: cfg.get('DB_SYNC') === 'true',
        dropSchema: cfg.get('DB_DROP_SCHEMA') === 'true',
      }),
    }),
    JwtModule.registerAsync({
      global: true,
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => ({
        secret: cfg.getOrThrow<string>('JWT_SECRET'),
        signOptions: { expiresIn: cfg.get('JWT_EXPIRES_IN', '7d') },
      }),
    }),
    UsersModule,
    AuthModule,
    ClassesModule,
    TimetableModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
})
export class AppModule implements OnApplicationBootstrap {
  private readonly log = new Logger('Bootstrap');
  constructor(private readonly users: UsersService, private readonly cfg: ConfigService) {}

  /** Tạo admin đầu tiên từ ADMIN_EMAIL / ADMIN_PASSWORD nếu hệ thống chưa có admin. */
  async onApplicationBootstrap() {
    const email = this.cfg.get<string>('ADMIN_EMAIL');
    const password = this.cfg.get<string>('ADMIN_PASSWORD');
    if (!email || !password || (await this.users.adminExists())) return;
    await this.users.create(email, password, 'Quản trị viên', Role.Admin);
    this.log.log(`Đã tạo tài khoản admin ${email}`);
  }
}
