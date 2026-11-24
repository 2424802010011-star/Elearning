import { Assignment, Submission } from './assignments/entities';
import { Classroom } from './classes/classroom.entity';
import { Enrollment } from './classes/enrollment.entity';
import { StoredFile } from './files/stored-file.entity';
import { Lesson } from './lessons/lesson.entity';
import { Meeting } from './meetings/meeting.entity';
import { Notification } from './notifications/notification.entity';
import { Quiz, QuizAttempt } from './quizzes/entities';
import { TimetableEntry } from './timetable/timetable-entry.entity';
import { ParentLink } from './users/parent-link.entity';
import { User } from './users/user.entity';

/** Mọi bảng trong CSDL. Thêm entity mới thì thêm vào đây rồi tạo migration (xem README). */
export const ENTITIES = [
  User,
  ParentLink,
  Classroom,
  Enrollment,
  TimetableEntry,
  Meeting,
  Assignment,
  Submission,
  Quiz,
  QuizAttempt,
  Lesson,
  StoredFile,
  Notification,
];
