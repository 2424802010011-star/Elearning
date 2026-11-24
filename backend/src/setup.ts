import { INestApplication, ValidationPipe } from '@nestjs/common';
import { BoardHub } from './board/board.hub';

export function configureApp(app: INestApplication) {
  app.setGlobalPrefix('api');
  app.enableCors();
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
  app.enableShutdownHooks();
  // Bảng trắng thời gian thực: ws://<máy chủ>/ws/board
  const hub = app.get(BoardHub);
  hub.attach(app.getHttpServer());
}
