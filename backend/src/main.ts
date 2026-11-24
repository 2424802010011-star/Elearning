import 'reflect-metadata';
import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { existsSync } from 'fs';
import { join } from 'path';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { configureApp } from './setup';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  configureApp(app);

  const doc = new DocumentBuilder()
    .setTitle('EduBoard API')
    .setDescription(
      'API phần mềm học tập EduBoard. Bấm "Authorize" và dán accessToken lấy từ /api/auth/login để thử các API cần đăng nhập.',
    )
    .setVersion('0.2.0')
    .addBearerAuth()
    .build();
  SwaggerModule.setup('docs', app, SwaggerModule.createDocument(app, doc), {
    swaggerOptions: { persistAuthorization: true },
  });

  // Giao diện web của app (bản build Flutter web) đặt trong thư mục public.
  const web = join(__dirname, '..', 'public');
  const hasWeb = existsSync(join(web, 'index.html'));
  if (hasWeb) app.useStaticAssets(web);

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
  const log = new Logger('EduBoard');
  if (hasWeb) log.log(`Mở app: http://localhost:${port}`);
  log.log(`Thử API: http://localhost:${port}/docs`);
}
bootstrap();
