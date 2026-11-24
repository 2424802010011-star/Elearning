// Kiểu dữ liệu nhận từ API backend EduBoard.

enum Role { admin, teacher, student, parent }

Role roleFrom(String s) => Role.values.firstWhere((r) => r.name == s, orElse: () => Role.student);

String roleLabel(Role r) => switch (r) {
      Role.admin => 'Quản trị viên',
      Role.teacher => 'Giáo viên',
      Role.student => 'Học sinh',
      Role.parent => 'Phụ huynh',
    };

class User {
  final String id;
  final String email;
  final String fullName;
  final Role role;
  User({required this.id, required this.email, required this.fullName, required this.role});
  factory User.fromJson(Map<String, dynamic> j) =>
      User(id: j['id'], email: j['email'], fullName: j['fullName'], role: roleFrom(j['role']));
}

class Classroom {
  final String id;
  final String name;
  final String? subject;
  final String? description;
  final String inviteCode;
  final User teacher;
  Classroom({
    required this.id,
    required this.name,
    this.subject,
    this.description,
    required this.inviteCode,
    required this.teacher,
  });
  factory Classroom.fromJson(Map<String, dynamic> j) => Classroom(
        id: j['id'],
        name: j['name'],
        subject: j['subject'],
        description: j['description'],
        inviteCode: j['inviteCode'] ?? '',
        teacher: User.fromJson(j['teacher']),
      );
}

class Enrollment {
  final String id;
  final User student;
  final String status; // pending | approved | rejected
  Enrollment({required this.id, required this.student, required this.status});
  factory Enrollment.fromJson(Map<String, dynamic> j) =>
      Enrollment(id: j['id'], student: User.fromJson(j['student']), status: j['status']);
}

class TimetableEntry {
  final String id;
  final String title;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String? location;
  TimetableEntry({
    required this.id,
    required this.title,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.location,
  });
  factory TimetableEntry.fromJson(Map<String, dynamic> j) => TimetableEntry(
        id: j['id'],
        title: j['title'],
        dayOfWeek: j['dayOfWeek'],
        startTime: j['startTime'],
        endTime: j['endTime'],
        location: j['location'],
      );
}

class Session {
  final String date;
  final String startTime;
  final String endTime;
  final String title;
  final String? location;
  final String classId;
  final String className;
  Session({
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.title,
    this.location,
    required this.classId,
    required this.className,
  });
  factory Session.fromJson(Map<String, dynamic> j) => Session(
        date: j['date'],
        startTime: j['startTime'],
        endTime: j['endTime'],
        title: j['title'],
        location: j['location'],
        classId: j['classroom']['id'],
        className: j['classroom']['name'],
      );
}

class Meeting {
  final String id;
  final String title;
  final String status; // scheduled | live | ended
  final DateTime? scheduledAt;
  Meeting({required this.id, required this.title, required this.status, this.scheduledAt});
  factory Meeting.fromJson(Map<String, dynamic> j) => Meeting(
        id: j['id'],
        title: j['title'],
        status: j['status'],
        scheduledAt: j['scheduledAt'] == null ? null : DateTime.parse(j['scheduledAt']).toLocal(),
      );
}

const dayNames = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];

class FileRef {
  final String id;
  final String name;
  final int size;
  final String mimeType;
  const FileRef({required this.id, required this.name, required this.size, required this.mimeType});
  factory FileRef.fromJson(Map<String, dynamic> j) =>
      FileRef(id: j['id'], name: j['name'] ?? 'file', size: (j['size'] as num?)?.toInt() ?? 0, mimeType: j['mimeType'] ?? '');
  static List<FileRef> listFrom(dynamic l) => [for (final j in (l as List? ?? const [])) FileRef.fromJson(j)];
}

String fmtSize(int b) => b < 1024
    ? '$b B'
    : b < 1024 * 1024
        ? '${(b / 1024).toStringAsFixed(0)} KB'
        : '${(b / 1024 / 1024).toStringAsFixed(1).replaceAll('.', ',')} MB';

class Lesson {
  final String id;
  final String title;
  final String content;
  final List<FileRef> attachments;
  final DateTime createdAt;
  Lesson({required this.id, required this.title, required this.content, required this.attachments, required this.createdAt});
  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: j['id'],
        title: j['title'],
        content: j['content'] ?? '',
        attachments: FileRef.listFrom(j['attachments']),
        createdAt: DateTime.parse(j['createdAt']).toLocal(),
      );
}

class Submission {
  final String id;
  final User student;
  final String content;
  final List<FileRef> attachments;
  final DateTime submittedAt;
  final bool late;
  final double? score;
  final String? feedback;
  Submission({
    required this.id,
    required this.student,
    required this.content,
    this.attachments = const [],
    required this.submittedAt,
    required this.late,
    this.score,
    this.feedback,
  });
  factory Submission.fromJson(Map<String, dynamic> j) => Submission(
        id: j['id'],
        student: User.fromJson(j['student']),
        content: j['content'] ?? '',
        attachments: FileRef.listFrom(j['attachments']),
        submittedAt: DateTime.parse(j['submittedAt']).toLocal(),
        late: j['late'] == true,
        score: (j['score'] as num?)?.toDouble(),
        feedback: j['feedback'],
      );
}

class Assignment {
  final String id;
  final String title;
  final String description;
  final DateTime? dueAt;
  final double maxScore;
  // Giáo viên
  final int? submittedCount, gradedCount, totalStudents;
  // Học sinh / phụ huynh
  final List<Submission> submissions;
  Assignment({
    required this.id,
    required this.title,
    required this.description,
    this.dueAt,
    required this.maxScore,
    this.submittedCount,
    this.gradedCount,
    this.totalStudents,
    this.submissions = const [],
  });
  factory Assignment.fromJson(Map<String, dynamic> j) => Assignment(
        id: j['id'],
        title: j['title'],
        description: j['description'] ?? '',
        dueAt: j['dueAt'] == null ? null : DateTime.parse(j['dueAt']).toLocal(),
        maxScore: (j['maxScore'] as num).toDouble(),
        submittedCount: j['submittedCount'],
        gradedCount: j['gradedCount'],
        totalStudents: j['totalStudents'],
        submissions: [for (final s in (j['submissions'] as List? ?? [])) Submission.fromJson(s)],
      );
}

String fmtDateTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.day}/${d.month}/${d.year}';

/// Điểm theo kiểu Việt Nam: 7,5 thay vì 7.5.
String fmtScore(double s) => s == s.roundToDouble() ? s.toInt().toString() : s.toString().replaceAll('.', ',');

class QuizQuestion {
  final String id;
  final String text;
  final List<String> options;
  final bool multiple;
  final double points;
  /// Chỉ có với giáo viên, hoặc học sinh sau khi nộp (nếu giáo viên cho xem đáp án).
  final List<int>? correct;
  QuizQuestion({required this.id, required this.text, required this.options, required this.multiple, required this.points, this.correct});
  factory QuizQuestion.fromJson(Map<String, dynamic> j) {
    final correct = (j['correct'] as List?)?.map((e) => e as int).toList();
    return QuizQuestion(
      id: j['id'],
      text: j['text'],
      options: [for (final o in j['options'] as List) o as String],
      multiple: j['multiple'] == true || (correct?.length ?? 0) > 1,
      points: (j['points'] as num?)?.toDouble() ?? 1,
      correct: correct,
    );
  }
}

class QuizAttempt {
  final String id;
  final String? studentName;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final DateTime? deadline;
  final double? score;
  final double maxScore;
  final bool late;
  final Map<String, List<int>> answers;
  QuizAttempt({
    required this.id,
    this.studentName,
    required this.startedAt,
    this.submittedAt,
    this.deadline,
    this.score,
    required this.maxScore,
    required this.late,
    this.answers = const {},
  });
  bool get submitted => submittedAt != null;
  factory QuizAttempt.fromJson(Map<String, dynamic> j) => QuizAttempt(
        id: j['id'],
        studentName: (j['student'] as Map?)?['fullName'],
        startedAt: DateTime.parse(j['startedAt']).toLocal(),
        submittedAt: j['submittedAt'] == null ? null : DateTime.parse(j['submittedAt']).toLocal(),
        deadline: j['deadline'] == null ? null : DateTime.parse(j['deadline']).toLocal(),
        score: (j['score'] as num?)?.toDouble(),
        maxScore: (j['maxScore'] as num?)?.toDouble() ?? 0,
        late: j['late'] == true,
        answers: {
          for (final e in ((j['answers'] as Map?) ?? {}).entries) e.key as String: [for (final v in e.value as List) v as int],
        },
      );
}

class Quiz {
  final String id;
  final String title;
  final String description;
  final int? durationMinutes;
  final DateTime? dueAt;
  final bool published;
  final bool showAnswers;
  final int questionCount;
  final double maxScore;
  // Giáo viên
  final int? submittedCount, totalStudents;
  final double? averageScore;
  // Học sinh: lượt làm của mình. Phụ huynh: lượt làm của con.
  final QuizAttempt? attempt;
  final List<QuizAttempt> attempts;
  final List<QuizQuestion> questions;
  final DateTime? serverTime;
  Quiz({
    required this.id,
    required this.title,
    required this.description,
    this.durationMinutes,
    this.dueAt,
    required this.published,
    required this.showAnswers,
    required this.questionCount,
    required this.maxScore,
    this.submittedCount,
    this.totalStudents,
    this.averageScore,
    this.attempt,
    this.attempts = const [],
    this.questions = const [],
    this.serverTime,
  });
  bool get overdue => dueAt != null && DateTime.now().isAfter(dueAt!);
  factory Quiz.fromJson(Map<String, dynamic> j) => Quiz(
        id: j['id'],
        title: j['title'],
        description: j['description'] ?? '',
        durationMinutes: j['durationMinutes'],
        dueAt: j['dueAt'] == null ? null : DateTime.parse(j['dueAt']).toLocal(),
        published: j['published'] == true,
        showAnswers: j['showAnswers'] != false,
        questionCount: j['questionCount'] ?? (j['questions'] as List?)?.length ?? 0,
        maxScore: (j['maxScore'] as num?)?.toDouble() ?? 0,
        submittedCount: j['submittedCount'],
        totalStudents: j['totalStudents'],
        averageScore: (j['averageScore'] as num?)?.toDouble(),
        attempt: j['attempt'] == null ? null : QuizAttempt.fromJson(j['attempt']),
        attempts: [for (final a in (j['attempts'] as List? ?? [])) QuizAttempt.fromJson(a)],
        questions: [for (final q in (j['questions'] as List? ?? [])) QuizQuestion.fromJson(q)],
        serverTime: j['serverTime'] == null ? null : DateTime.parse(j['serverTime']).toLocal(),
      );
}
