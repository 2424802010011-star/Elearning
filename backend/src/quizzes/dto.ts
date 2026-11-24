import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsInt,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

export class QuestionDto {
  @ApiPropertyOptional({ description: 'Giữ nguyên id khi sửa đề' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  id?: string;

  @ApiProperty({ example: 'Chu kỳ của hàm số y = sin(2x) là?' })
  @IsString()
  @MinLength(1, { message: 'Câu hỏi không được để trống' })
  @MaxLength(5000)
  text: string;

  @ApiProperty({ example: ['π', '2π', 'π/2', '4π'] })
  @IsArray()
  @ArrayMinSize(2, { message: 'Mỗi câu cần ít nhất 2 lựa chọn' })
  @ArrayMaxSize(8)
  @IsString({ each: true })
  @MinLength(1, { each: true, message: 'Lựa chọn không được để trống' })
  @MaxLength(1000, { each: true })
  options: string[];

  @ApiProperty({ example: [0], description: 'Vị trí đáp án đúng, tính từ 0. Nhiều số = câu nhiều đáp án.' })
  @IsArray()
  @ArrayMinSize(1, { message: 'Mỗi câu cần ít nhất 1 đáp án đúng' })
  @IsInt({ each: true })
  @Min(0, { each: true })
  correct: number[];

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  points?: number;
}

export class CreateQuizDto {
  @ApiProperty({ example: 'Kiểm tra 15 phút: hàm số lượng giác' })
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  title: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(5000)
  description?: string;

  @ApiPropertyOptional({ example: 15 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(600)
  durationMinutes?: number;

  @ApiPropertyOptional({ example: '2026-12-15T23:59:00+07:00' })
  @IsOptional()
  @IsDateString()
  dueAt?: string;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  published?: boolean;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  showAnswers?: boolean;

  @ApiProperty({ type: [QuestionDto] })
  @IsArray()
  @ArrayMinSize(1, { message: 'Đề cần ít nhất 1 câu hỏi' })
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => QuestionDto)
  questions: QuestionDto[];
}

export class UpdateQuizDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  title?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(5000)
  description?: string;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(600)
  durationMinutes?: number | null;

  @ApiPropertyOptional({ nullable: true })
  @IsOptional()
  @IsDateString()
  dueAt?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  published?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  showAnswers?: boolean;

  @ApiPropertyOptional({ type: [QuestionDto], description: 'Chỉ sửa được khi chưa có học sinh làm bài' })
  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => QuestionDto)
  questions?: QuestionDto[];
}

export class SubmitQuizDto {
  @ApiProperty({ example: { q1: [0], q2: [1, 3] }, description: 'id câu hỏi -> vị trí các lựa chọn' })
  @IsObject()
  answers: Record<string, number[]>;
}
