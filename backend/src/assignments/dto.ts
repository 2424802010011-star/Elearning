import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ArrayMaxSize, IsArray, IsDateString, IsNumber, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength } from 'class-validator';

export class CreateAssignmentDto {
  @ApiProperty({ example: 'Bài tập về hàm số sin' })
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  title: string;

  @ApiPropertyOptional({ example: 'Vẽ đồ thị y = 2sin(x) trên đoạn [0, 2π] và nêu chu kỳ.' })
  @IsOptional()
  @IsString()
  @MaxLength(10000)
  description?: string;

  @ApiPropertyOptional({ example: '2026-12-15T23:59:00+07:00' })
  @IsOptional()
  @IsDateString()
  dueAt?: string;

  @ApiPropertyOptional({ example: 10 })
  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(1000)
  maxScore?: number;
}

export class SubmitDto {
  @ApiPropertyOptional({ example: 'Chu kỳ của y = 2sin(x) là 2π, biên độ là 2.' })
  @IsOptional()
  @IsString()
  @MaxLength(50000)
  content?: string;

  @ApiPropertyOptional({ description: 'Id các file đã tải lên qua POST /files (ảnh chụp bài làm, PDF...)', type: [String] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsUUID('all', { each: true })
  fileIds?: string[];
}

export class GradeDto {
  @ApiProperty({ example: 9 })
  @IsNumber()
  @Min(0)
  score: number;

  @ApiPropertyOptional({ example: 'Làm tốt, cần ghi rõ đơn vị.' })
  @IsOptional()
  @IsString()
  @MaxLength(5000)
  feedback?: string;
}
