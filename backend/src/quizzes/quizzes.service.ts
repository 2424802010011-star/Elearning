import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { ClassesService } from '../classes/classes.service';
import { AuthUser } from '../common/decorators';
import { Role } from '../common/role.enum';
import { UsersService } from '../users/users.service';
import { CreateQuizDto, QuestionDto, SubmitQuizDto, UpdateQuizDto } from './dto';
import { Quiz, QuizAttempt, QuizQuestion } from './entities';

/** Nộp chậm trong khoảng này (mạng chậm) vẫn tính là đúng giờ. */
const GRACE_MS = 30_000;

const NO_ID = '00000000-0000-0000-0000-000000000000';

function normalizeQuestions(list: QuestionDto[]): QuizQuestion[] {
  const used = new Set<string>();
  return list.map((q, i) => {
    let id = q.id?.trim() || `c${i + 1}`;
    while (used.has(id)) id = `${id}_${i + 1}`;
    used.add(id);
    const correct = [...new Set(q.correct)].sort((a, b) => a - b);
    if (correct.some((c) => c >= q.options.length)) {
      throw new BadRequestException(`Câu ${i + 1}: đáp án đúng phải là một trong các lựa chọn`);
    }
    return { id, text: q.text.trim(), options: q.options.map((o) => o.trim()), correct, points: q.points ?? 1 };
  });
}

const maxScoreOf = (qs: QuizQuestion[]) => qs.reduce((s, q) => s + q.points, 0);

/** Đúng hoàn toàn mới được điểm câu đó. */
function grade(qs: QuizQuestion[], answers: Record<string, number[]>) {
  let score = 0;
  for (const q of qs) {
    const a = [...new Set(answers[q.id] ?? [])].sort((x, y) => x - y);
    if (a.length === q.correct.length && a.every((v, i) => v === q.correct[i])) score += q.points;
  }
  return Math.round(score * 100) / 100;
}

/** Đề gửi cho học sinh: không kèm đáp án. */
const forStudent = (qs: QuizQuestion[]) =>
  qs.map((q) => ({ id: q.id, text: q.text, options: q.options, multiple: q.correct.length > 1, points: q.points }));

@Injectable()
export class QuizzesService {
  constructor(
    @InjectRepository(Quiz) private readonly quizzes: Repository<Quiz>,
    @InjectRepository(QuizAttempt) private readonly attempts: Repository<QuizAttempt>,
    private readonly classes: ClassesService,
    private readonly users: UsersService,
  ) {}

  private summary(q: Quiz) {
    const { questions, classroom: _c, ...rest } = q;
    return { ...rest, questionCount: questions.length, maxScore: maxScoreOf(questions) };
  }

  private deadline(q: Quiz, a: QuizAttempt): Date | null {
    const times: number[] = [];
    if (q.dueAt) times.push(new Date(q.dueAt).getTime());
    if (q.durationMinutes) times.push(new Date(a.startedAt).getTime() + q.durationMinutes * 60_000);
    return times.length ? new Date(Math.min(...times)) : null;
  }

  private attemptView(q: Quiz, a: QuizAttempt) {
    const { quiz: _q, student, ...rest } = a;
    return {
      ...rest,
      student: student ? { id: student.id, fullName: student.fullName, email: student.email } : undefined,
      deadline: this.deadline(q, a),
      status: a.submittedAt ? 'submitted' : 'in_progress',
    };
  }

  async create(me: AuthUser, classId: string, dto: CreateQuizDto) {
    const classroom = await this.classes.assertCanManage(me, classId);
    const saved = await this.quizzes.save(
      this.quizzes.create({
        classroom,
        title: dto.title.trim(),
        description: dto.description ?? '',
        durationMinutes: dto.durationMinutes ?? null,
        dueAt: dto.dueAt ? new Date(dto.dueAt) : undefined,
        published: dto.published ?? false,
        showAnswers: dto.showAnswers ?? true,
        questions: normalizeQuestions(dto.questions),
      }),
    );
    return { ...this.summary(saved), questions: saved.questions };
  }

  private async load(id: string) {
    const q = await this.quizzes.findOne({ where: { id } });
    if (!q) throw new NotFoundException('Không tìm thấy bài kiểm tra');
    return q;
  }

  private canManage(me: AuthUser, q: Quiz) {
    return me.role === Role.Admin || q.classroom.teacher.id === me.id;
  }

  /** Học sinh/phụ huynh: chỉ thấy đề đã phát hành. */
  private async loadVisible(me: AuthUser, id: string) {
    const q = await this.load(id);
    await this.classes.assertCanView(me, q.classroom.id);
    if (!q.published && !this.canManage(me, q)) throw new NotFoundException('Không tìm thấy bài kiểm tra');
    return q;
  }

  async listForClass(me: AuthUser, classId: string) {
    const classroom = await this.classes.assertCanView(me, classId);
    const manager = me.role === Role.Admin || classroom.teacher.id === me.id;
    const list = await this.quizzes.find({
      where: { classroom: { id: classId }, ...(manager ? {} : { published: true }) },
      order: { createdAt: 'DESC' },
    });
    if (!list.length) return [];
    const who =
      me.role === Role.Student ? [me.id] : me.role === Role.Parent ? (await this.users.childrenOf(me.id)).map((c) => c.id) : 'all';
    const atts = await this.attempts.find({
      where: {
        quiz: { id: In(list.map((q) => q.id)) },
        ...(who === 'all' ? {} : { student: { id: In(who.length ? who : [NO_ID]) } }),
      },
      relations: { quiz: true },
    });
    const totalStudents = manager ? (await this.classes.approvedStudentIds(classId)).length : undefined;
    return list.map((q) => {
      const mine = atts.filter((a) => a.quiz.id === q.id);
      if (manager || who === 'all') {
        const done = mine.filter((a) => a.submittedAt);
        return {
          ...this.summary(q),
          submittedCount: done.length,
          totalStudents,
          averageScore: done.length ? Math.round((done.reduce((s, a) => s + (a.score ?? 0), 0) / done.length) * 100) / 100 : null,
        };
      }
      return { ...this.summary(q), attempts: mine.map((a) => this.attemptView(q, a)) };
    });
  }

  /** Xem đề. GV: đầy đủ đáp án. HS: đề (không đáp án) khi đang làm, kèm đáp án sau khi nộp nếu GV cho phép. */
  async get(me: AuthUser, id: string) {
    const q = await this.loadVisible(me, id);
    if (this.canManage(me, q)) return { ...this.summary(q), questions: q.questions };
    if (me.role === Role.Student) {
      const a = await this.attempts.findOne({ where: { quiz: { id }, student: { id: me.id } } });
      if (!a) return { ...this.summary(q), attempt: null };
      if (!a.submittedAt) return { ...this.summary(q), attempt: this.attemptView(q, a), questions: forStudent(q.questions) };
      return {
        ...this.summary(q),
        attempt: this.attemptView(q, a),
        questions: q.showAnswers ? q.questions : forStudent(q.questions),
      };
    }
    // Phụ huynh: chỉ xem điểm của con, không xem đề.
    const kids = (await this.users.childrenOf(me.id)).map((c) => c.id);
    const atts = await this.attempts.find({ where: { quiz: { id }, student: { id: In(kids.length ? kids : [NO_ID]) } } });
    return { ...this.summary(q), attempts: atts.map((a) => this.attemptView(q, a)) };
  }

  async start(me: AuthUser, id: string) {
    const q = await this.loadVisible(me, id);
    let a = await this.attempts.findOne({ where: { quiz: { id }, student: { id: me.id } } });
    if (a?.submittedAt) throw new BadRequestException('Bạn đã nộp bài này rồi');
    if (!a) {
      if (q.dueAt && new Date() > new Date(q.dueAt)) throw new BadRequestException('Đã quá hạn làm bài');
      a = await this.attempts.save(
        this.attempts.create({ quiz: q, student: await this.users.findById(me.id), startedAt: new Date(), maxScore: maxScoreOf(q.questions) }),
      );
    }
    // Kèm giờ máy chủ để app đếm ngược đúng dù đồng hồ máy học sinh lệch.
    return { ...this.summary(q), attempt: this.attemptView(q, a), questions: forStudent(q.questions), serverTime: new Date() };
  }

  async submit(me: AuthUser, id: string, dto: SubmitQuizDto) {
    const q = await this.loadVisible(me, id);
    const a = await this.attempts.findOne({ where: { quiz: { id }, student: { id: me.id } } });
    if (!a) throw new BadRequestException('Bạn chưa bắt đầu làm bài');
    if (a.submittedAt) throw new BadRequestException('Bạn đã nộp bài này rồi');
    const answers: Record<string, number[]> = {};
    for (const question of q.questions) {
      const raw = dto.answers?.[question.id];
      if (!Array.isArray(raw)) continue;
      answers[question.id] = [...new Set(raw.filter((v) => Number.isInteger(v) && v >= 0 && v < question.options.length))];
    }
    const now = new Date();
    const deadline = this.deadline(q, a);
    a.answers = answers;
    a.submittedAt = now;
    a.late = !!deadline && now.getTime() > deadline.getTime() + GRACE_MS;
    a.score = grade(q.questions, answers);
    a.maxScore = maxScoreOf(q.questions);
    const saved = await this.attempts.save(a);
    return {
      ...this.summary(q),
      attempt: this.attemptView(q, saved),
      questions: q.showAnswers ? q.questions : forStudent(q.questions),
    };
  }

  /** Kết quả cả lớp cho giáo viên: điểm từng em và tỉ lệ đúng từng câu. */
  async results(me: AuthUser, id: string) {
    const q = await this.load(id);
    await this.classes.assertCanManage(me, q.classroom.id);
    const atts = await this.attempts.find({ where: { quiz: { id } }, order: { submittedAt: 'ASC' } });
    const done = atts.filter((a) => a.submittedAt);
    const questionStats = q.questions.map((question) => {
      const right = done.filter((a) => grade([question], a.answers ?? {}) === question.points).length;
      return { id: question.id, correctCount: right, total: done.length };
    });
    return { quiz: this.summary(q), attempts: atts.map((a) => this.attemptView(q, a)), questionStats };
  }

  async update(me: AuthUser, id: string, dto: UpdateQuizDto) {
    const q = await this.load(id);
    if (!this.canManage(me, q)) throw new ForbiddenException('Chỉ giáo viên chủ lớp hoặc admin được thao tác');
    if (dto.questions) {
      if ((await this.attempts.count({ where: { quiz: { id } } })) > 0) {
        throw new BadRequestException('Đã có học sinh làm bài, không sửa câu hỏi được nữa');
      }
      q.questions = normalizeQuestions(dto.questions);
    }
    if (dto.title !== undefined) q.title = dto.title.trim();
    if (dto.description !== undefined) q.description = dto.description;
    if (dto.durationMinutes !== undefined) q.durationMinutes = dto.durationMinutes;
    if (dto.dueAt !== undefined) q.dueAt = dto.dueAt ? new Date(dto.dueAt) : (null as unknown as undefined);
    if (dto.published !== undefined) q.published = dto.published;
    if (dto.showAnswers !== undefined) q.showAnswers = dto.showAnswers;
    const saved = await this.quizzes.save(q);
    return { ...this.summary(saved), questions: saved.questions };
  }

  async remove(me: AuthUser, id: string) {
    const q = await this.load(id);
    if (!this.canManage(me, q)) throw new ForbiddenException('Chỉ giáo viên chủ lớp hoặc admin được thao tác');
    await this.quizzes.delete({ id });
  }
}
