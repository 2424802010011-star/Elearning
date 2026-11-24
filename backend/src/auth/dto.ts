import { IsEmail, IsIn, IsString, MinLength } from 'class-validator';
import { Role } from '../common/role.enum';

export class RegisterDto {
  @IsEmail({}, { message: 'Email không hợp lệ' })
  email: string;

  @IsString()
  @MinLength(8, { message: 'Mật khẩu tối thiểu 8 ký tự' })
  password: string;

  @IsString()
  @MinLength(2)
  fullName: string;

  /** Tự đăng ký chỉ được chọn học sinh, giáo viên hoặc phụ huynh. Admin do admin khác tạo. */
  @IsIn([Role.Student, Role.Teacher, Role.Parent], { message: 'Vai trò không hợp lệ' })
  role: Role;
}

export class LoginDto {
  @IsEmail()
  email: string;

  @IsString()
  password: string;
}
