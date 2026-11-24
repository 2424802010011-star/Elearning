import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { User } from '../users/user.entity';
import { UsersService } from '../users/users.service';
import { LoginDto, RegisterDto } from './dto';

@Injectable()
export class AuthService {
  constructor(private readonly users: UsersService, private readonly jwt: JwtService) {}

  async register(dto: RegisterDto) {
    const user = await this.users.create(dto.email, dto.password, dto.fullName, dto.role);
    return this.issue(user);
  }

  async login(dto: LoginDto) {
    const user = await this.users.findByEmailWithPassword(dto.email);
    if (!user || !(await bcrypt.compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException('Sai email hoặc mật khẩu');
    }
    return this.issue(await this.users.findById(user.id));
  }

  private async issue(user: User) {
    const accessToken = await this.jwt.signAsync({ sub: user.id, email: user.email, role: user.role });
    return { accessToken, user };
  }
}
