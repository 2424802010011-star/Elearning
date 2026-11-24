import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsInt, IsOptional, IsString, Matches, Max, MaxLength, Min, MinLength } from 'class-validator';

const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;

export class CreateEntryDto {
  @ApiProperty({ example: 'Đại số' })
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  title: string;

  @ApiProperty({ example: 1, description: '1 = Thứ Hai ... 7 = Chủ Nhật' })
  @IsInt()
  @Min(1)
  @Max(7)
  dayOfWeek: number;

  @ApiProperty({ example: '07:30' })
  @Matches(HHMM, { message: 'startTime phải có dạng HH:mm' })
  startTime: string;

  @ApiProperty({ example: '08:15' })
  @Matches(HHMM, { message: 'endTime phải có dạng HH:mm' })
  endTime: string;

  @ApiProperty({ example: '2026-12-07' })
  @IsDateString({ strict: true })
  startDate: string;

  @ApiPropertyOptional({ example: '2027-05-31' })
  @IsOptional()
  @IsDateString({ strict: true })
  endDate?: string;

  @ApiPropertyOptional({ example: 'Phòng 201 / Học online' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  location?: string;
}
