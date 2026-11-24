import { CanActivate, ExecutionContext, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { IS_PUBLIC, ROLES } from './decorators';
import { Role } from './role.enum';
import { UsersService } from '../users/users.service';

/** Mọi route đều cần JWT, trừ route gắn @Public(). */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwt: JwtService,
    private readonly users: UsersService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, [ctx.getHandler(), ctx.getClass()]);
    if (isPublic) return true;
    const req = ctx.switchToHttp().getRequest();
    const [type, token] = (req.headers.authorization ?? '').split(' ');
    if (type !== 'Bearer' || !token) throw new UnauthorizedException('Thiếu token đăng nhập');
    let sub: string;
    try {
      const payload = await this.jwt.verifyAsync(token);
      if (payload.typ) throw new Error('không phải token đăng nhập');
      sub = payload.sub;
    } catch {
      throw new UnauthorizedException('Token không hợp lệ hoặc đã hết hạn');
    }
    // Lấy vai trò hiện tại từ CSDL: admin đổi vai trò hoặc khóa tài khoản thì có hiệu lực ngay.
    const u = await this.users.authInfo(sub);
    if (!u || !u.active) throw new UnauthorizedException('Tài khoản đã bị khóa hoặc không còn tồn tại');
    req.user = { id: u.id, email: u.email, role: u.role };
    return true;
  }
}

/** Kiểm tra vai trò theo @Roles(...). Không gắn @Roles thì mọi vai trò đã đăng nhập đều qua. */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(ctx: ExecutionContext): boolean {
    const roles = this.reflector.getAllAndOverride<Role[]>(ROLES, [ctx.getHandler(), ctx.getClass()]);
    if (!roles || roles.length === 0) return true;
    const user = ctx.switchToHttp().getRequest().user;
    if (!user || !roles.includes(user.role)) throw new ForbiddenException('Bạn không có quyền thực hiện thao tác này');
    return true;
  }
}
