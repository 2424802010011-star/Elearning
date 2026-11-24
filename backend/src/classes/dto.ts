import { IsIn, IsOptional, IsString, Length, MaxLength, MinLength } from 'class-validator';
import { EnrollmentStatus } from './enrollment.entity';

export class CreateClassDto {
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  subject?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;
}

export class JoinClassDto {
  @IsString()
  @Length(6, 8)
  inviteCode: string;
}

export class ReviewEnrollmentDto {
  @IsIn([EnrollmentStatus.Approved, EnrollmentStatus.Rejected])
  status: EnrollmentStatus;
}
