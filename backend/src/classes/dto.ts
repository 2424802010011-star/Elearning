import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, Length, MaxLength, MinLength } from 'class-validator';
import { EnrollmentStatus } from './enrollment.entity';

export class CreateClassDto {
  @ApiProperty({ example: 'Toán 10A1' })
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  name: string;

  @ApiPropertyOptional({ example: 'Toán' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  subject?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;
}

export class JoinClassDto {
  @ApiProperty({ example: 'AB12CD' })
  @IsString()
  @Length(6, 8)
  inviteCode: string;
}

export class ReviewEnrollmentDto {
  @ApiProperty({ enum: [EnrollmentStatus.Approved, EnrollmentStatus.Rejected] })
  @IsIn([EnrollmentStatus.Approved, EnrollmentStatus.Rejected])
  status: EnrollmentStatus;
}
