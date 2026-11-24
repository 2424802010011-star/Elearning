import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { DataSource } from 'typeorm';
import { Public } from '../common/decorators';

@ApiTags('Quản trị')
@Controller('health')
export class HealthController {
  constructor(private readonly db: DataSource) {}

  /** Dùng cho Docker / máy theo dõi: máy chủ chạy và kết nối được CSDL. */
  @Public()
  @Get()
  async health() {
    try {
      await this.db.query('SELECT 1');
    } catch {
      throw new ServiceUnavailableException({ ok: false, db: false });
    }
    return { ok: true, db: true };
  }
}
