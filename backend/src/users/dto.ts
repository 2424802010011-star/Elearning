import { IsEmail, IsEnum, IsString, IsUUID, MinLength } from 'class-validator';
import { Role } from '../common/role.enum';

export class CreateUserDto {
  @IsEmail({}, { message: 'Email không hợp lệ' })
  email: string;

  @IsString()
  @MinLength(8, { message: 'Mật khẩu tối thiểu 8 ký tự' })
  password: string;

  @IsString()
  @MinLength(2)
  fullName: string;

  @IsEnum(Role)
  role: Role;
}

export class UpdateRoleDto {
  @IsEnum(Role)
  role: Role;
}

export class CreateParentLinkDto {
  @IsUUID()
  parentId: string;

  @IsUUID()
  studentId: string;
}
