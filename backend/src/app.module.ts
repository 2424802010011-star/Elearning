import { Logger, Module, OnApplicationBootstrap } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule, TypeOrmModuleOptions } from '@nestjs/typeorm';
import { AssignmentsModule } from './assignments/assignments.module';
import { AssignmentsService } from './assignments/assignments.service';
import { AuthModule } from './auth/auth.module';
import { ClassesModule } from './classes/classes.module';
import { ClassesService } from './classes/classes.service';
import { JwtAuthGuard, RolesGuard } from './common/guards';
import { Role } from './common/role.enum';
import { MeetingsModule } from './meetings/meetings.module';
import { MeetingsService } from './meetings/meetings.service';
import { QuizzesModule } from './quizzes/quizzes.module';
import { QuizzesService } from './quizzes/quizzes.service';
import { seedDemo } from './seed';
import { TimetableModule } from './timetable/timetable.module';
import { TimetableService } from './timetable/timetable.service';
import { UsersModule } from './users/users.module';
import { UsersService } from './users/users.service';

/**
 * Có DATABASE_URL thì dùng PostgreSQL (môi trường thật).
 * Không có thì dùng SQLite trong file (sql.js), không cần cài gì thêm, phù hợp để chạy thử.
 */
function dbOptions(cfg: ConfigService): TypeOrmModuleOptions {
  const url = cfg.get<string>('DATABASE_URL');
  if (url) {
    return {
      type: 'postgres',
      url,
      autoLoadEntities: true,
      synchronize: cfg.get('DB_SYNC') === 'true',
      dropSchema: cfg.get('DB_DROP_SCHEMA') === 'true',
    };
  }
  const file = cfg.get<string>('SQLITE_FILE', 'eduboard-demo.sqlite');
  return {
    type: 'sqljs',
    location: file === ':memory:' ? undefined : file,
    autoSave: file !== ':memory:',
    autoLoadEntities: true,
    synchronize: true,
  };
}

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({ inject: [ConfigService], useFactory: dbOptions }),
    JwtModule.registerAsync({
      global: true,
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => {
        const secret = cfg.get<string>('JWT_SECRET');
        if (!secret && cfg.get('NODE_ENV') === 'production') throw new Error('Thiếu JWT_SECRET');
        return {
          secret: secret ?? 'dev-only-secret-change-me',
          signOptions: { expiresIn: cfg.get('JWT_EXPIRES_IN', '7d') },
        };
      },
    }),
    UsersModule,
    AuthModule,
    ClassesModule,
    TimetableModule,
    MeetingsModule,
    AssignmentsModule,
    QuizzesModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
})
export class AppModule implements OnApplicationBootstrap {
  private readonly log = new Logger('Bootstrap');
  constructor(
    private readonly cfg: ConfigService,
    private readonly users: UsersService,
    private readonly classes: ClassesService,
    private readonly timetable: TimetableService,
    private readonly meetings: MeetingsService,
    private readonly assignments: AssignmentsService,
    private readonly quizzes: QuizzesService,
  ) {}

  async onApplicationBootstrap() {
    // Admin đầu tiên. Chạy thử bằng SQLite thì mặc định admin@demo.vn / demo1234.
    const demo = !this.cfg.get('DATABASE_URL');
    const email = this.cfg.get<string>('ADMIN_EMAIL', demo ? 'admin@demo.vn' : '');
    const password = this.cfg.get<string>('ADMIN_PASSWORD', demo ? 'demo1234' : '');
    if (email && password && !(await this.users.adminExists())) {
      await this.users.create(email, password, 'Quản trị viên', Role.Admin);
      this.log.log(`Đã tạo tài khoản admin ${email}`);
    }
    if (this.cfg.get('SEED_DEMO', demo ? 'true' : 'false') === 'true') {
      await seedDemo(this.users, this.classes, this.timetable, this.meetings, this.assignments, this.quizzes);
    }
  }
}
