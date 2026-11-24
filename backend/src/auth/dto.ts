import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsIn, IsString, MinLength } from 'class-validator';
import { Role } from '../common/role.enum';

export class RegisterDto {
  @ApiProperty({ example: 'hocsinh@example.com' })
  @IsEmail({}, { message: 'Email không hợp lệ' })
  email: string;

  @ApiProperty({ example: 'matkhau123', minLength: 8 })
  @IsString()
  @MinLength(8, { message: 'Mật khẩu tối thiểu 8 ký tự' })
  password: string;

  @ApiProperty({ example: 'Nguyễn Văn A' })
  @IsString()
  @MinLength(2)
  fullName: string;

  /** Tự đăng ký chỉ được chọn học sinh, giáo viên hoặc phụ huynh. Admin do admin khác tạo. */
  @ApiProperty({ enum: [Role.Student, Role.Teacher, Role.Parent], example: Role.Student })
  @IsIn([Role.Student, Role.Teacher, Role.Parent], { message: 'Vai trò không hợp lệ' })
  role: Role;
}

export class LoginDto {
  @ApiProperty({ example: 'giaovien@demo.vn' })
  @IsEmail()
  email: string;

  @ApiProperty({ example: 'demo1234' })
  @IsString()
  password: string;
}
