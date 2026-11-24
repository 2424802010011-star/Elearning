import { ApiPropertyOptional, ApiProperty } from '@nestjs/swagger';
import { ArrayMaxSize, IsArray, IsBoolean, IsDateString, IsOptional, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

export class CreateMeetingDto {
  @ApiProperty({ example: 'Ôn tập hàm số lượng giác' })
  @IsString()
  @MinLength(1)
  @MaxLength(160)
  title: string;

  @ApiPropertyOptional({ example: '2026-12-08T07:30:00+07:00', description: 'Bỏ trống để họp ngay' })
  @IsOptional()
  @IsDateString()
  scheduledAt?: string;
}

export class BoardPermissionsDto {
  @ApiPropertyOptional({ example: false, description: 'true = cả lớp được viết lên bảng' })
  @IsOptional()
  @IsBoolean()
  allowAll?: boolean;

  @ApiPropertyOptional({ type: [String], description: 'Danh sách id học sinh được viết (thay thế danh sách cũ)' })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(500)
  @IsUUID('all', { each: true })
  studentIds?: string[];
}
