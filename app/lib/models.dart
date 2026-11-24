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
