import { IsDateString, IsInt, IsOptional, IsString, Matches, Max, MaxLength, Min, MinLength } from 'class-validator';

const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;

export class CreateEntryDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  title: string;

  @IsInt()
  @Min(1)
  @Max(7)
  dayOfWeek: number;

  @Matches(HHMM, { message: 'startTime phải có dạng HH:mm' })
  startTime: string;

  @Matches(HHMM, { message: 'endTime phải có dạng HH:mm' })
  endTime: string;

  @IsDateString({ strict: true })
  startDate: string;

  @IsOptional()
  @IsDateString({ strict: true })
  endDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  location?: string;
}
