import 'reflect-metadata';
import { join } from 'path';
import { DataSource } from 'typeorm';
import { ENTITIES } from './entities';

/**
 * Cấu hình cho lệnh migration của TypeORM (chỉ PostgreSQL):
 *   npm run migration:generate -- src/migrations/TenThayDoi
 *   npm run migration:run
 *   npm run migration:revert
 * Đọc DATABASE_URL từ biến môi trường hoặc file .env.
 */
try {
  // Node 20.12+ có sẵn hàm đọc .env; bản cũ hơn thì bỏ qua.
  (process as unknown as { loadEnvFile?: (p?: string) => void }).loadEnvFile?.('.env');
} catch {
  /* không có .env */
}

export const MIGRATIONS = join(__dirname, 'migrations', '*.{ts,js}');

export default new DataSource({
  type: 'postgres',
  url: process.env.DATABASE_URL ?? 'postgres://eduboard:eduboard@localhost:5432/eduboard',
  entities: ENTITIES,
  migrations: [MIGRATIONS],
});
