import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsEmail, IsEnum, IsOptional, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';
import { Role } from '../common/role.enum';

export class CreateUserDto {
  @ApiProperty({ example: 'giaovien2@example.com' })
  @IsEmail({}, { message: 'Email không hợp lệ' })
  email: string;

  @ApiProperty({ example: 'matkhau123', minLength: 8 })
  @IsString()
  @MinLength(8, { message: 'Mật khẩu tối thiểu 8 ký tự' })
  password: string;

  @ApiProperty({ example: 'Trần Thị B' })
  @IsString()
  @MinLength(2)
  fullName: string;

  @ApiProperty({ enum: Role })
  @IsEnum(Role)
  role: Role;
}

export class UpdateRoleDto {
  @ApiProperty({ enum: Role })
  @IsEnum(Role)
  role: Role;
}

export class CreateParentLinkDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  parentId: string;

  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  studentId: string;
}

export class UpdateUserDto {
  @ApiPropertyOptional({ example: 'Trần Thị B' })
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(100)
  fullName?: string;

  @ApiPropertyOptional({ enum: Role })
  @IsOptional()
  @IsEnum(Role)
  role?: Role;

  @ApiPropertyOptional({ description: 'false để khóa tài khoản' })
  @IsOptional()
  @IsBoolean()
  active?: boolean;
}

export class ResetPasswordDto {
  @ApiProperty({ example: 'matkhaumoi123', minLength: 8 })
  @IsString()
  @MinLength(8, { message: 'Mật khẩu tối thiểu 8 ký tự' })
  password: string;
}
