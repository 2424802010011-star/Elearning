import 'reflect-metadata';
import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { configureApp } from './setup';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
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

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
  new Logger('EduBoard').log(`Đang chạy: http://localhost:${port}/docs`);
}
bootstrap();
