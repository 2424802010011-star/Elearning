import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { randomUUID } from 'crypto';
import { AccessToken } from 'livekit-server-sdk';
import { Repository } from 'typeorm';
import { BoardHub } from '../board/board.hub';
import { ClassesService } from '../classes/classes.service';
import { AuthUser } from '../common/decorators';
import { Role } from '../common/role.enum';
import { NotificationsService } from '../notifications/notifications.service';
import { UsersService } from '../users/users.service';
import { BoardPermissionsDto, CreateMeetingDto } from './dto';
import { Meeting, MeetingStatus } from './meeting.entity';

@Injectable()
export class MeetingsService {
  constructor(
    @InjectRepository(Meeting) private readonly meetings: Repository<Meeting>,
    private readonly classes: ClassesService,
    private readonly users: UsersService,
    private readonly cfg: ConfigService,
    private readonly hub: BoardHub,
    private readonly notes: NotificationsService,
  ) {
    // Chỉ người được vào phòng (đang mở) mới kết nối được bảng trắng.
    hub.setAccessChecker(async (user, meetingId) => {
      if (user.role === Role.Parent) throw new ForbiddenException();
      const m = await this.get(user, meetingId);
      if (m.status !== MeetingStatus.Live) throw new BadRequestException('Phòng chưa mở');
      const isHost = user.role === Role.Admin || m.classroom.teacher.id === user.id;
      return { isHost, allowAll: m.boardAllowAll, writers: m.boardWriters };
    });
  }

  async create(me: AuthUser, classId: string, dto: CreateMeetingDto): Promise<Meeting> {
    const classroom = await this.classes.assertCanManage(me, classId);
    const host = await this.users.findById(me.id);
    return this.meetings.save(
      this.meetings.create({
        classroom,
        host,
        title: dto.title,
        scheduledAt: dto.scheduledAt ? new Date(dto.scheduledAt) : undefined,
        roomName: `eduboard-${randomUUID()}`,
        boardWriters: [],
      }),
    );
  }

  async listForClass(me: AuthUser, classId: string): Promise<Meeting[]> {
    await this.classes.assertCanView(me, classId);
    return this.meetings.find({ where: { classroom: { id: classId } }, order: { createdAt: 'DESC' } });
  }

  private async load(id: string): Promise<Meeting> {
    const m = await this.meetings.findOne({ where: { id } });
    if (!m) throw new NotFoundException('Không tìm thấy cuộc họp');
    return m;
  }

  async get(me: AuthUser, id: string): Promise<Meeting> {
    const m = await this.load(id);
    await this.classes.assertCanView(me, m.classroom.id);
    return m;
  }

  private async loadManaged(me: AuthUser, id: string): Promise<Meeting> {
    const m = await this.load(id);
    await this.classes.assertCanManage(me, m.classroom.id);
    return m;
  }

  async start(me: AuthUser, id: string): Promise<Meeting> {
    const m = await this.loadManaged(me, id);
    if (m.status === MeetingStatus.Ended) throw new BadRequestException('Cuộc họp đã kết thúc');
    if (m.status === MeetingStatus.Scheduled) {
      m.status = MeetingStatus.Live;
      m.startedAt = new Date();
      await this.meetings.save(m);
      await this.notes.notify(await this.classes.approvedStudentIds(m.classroom.id), {
        type: 'meeting_live',
        title: `Lớp ${m.classroom.name} đang học trực tuyến`,
        body: `${m.title}. Vào tab Cuộc họp để tham gia.`,
        classId: m.classroom.id,
        tab: 'meetings',
      });
    }
    return m;
  }

  async end(me: AuthUser, id: string): Promise<Meeting> {
    const m = await this.loadManaged(me, id);
    m.status = MeetingStatus.Ended;
    m.endedAt = new Date();
    m.boardAllowAll = false;
    m.boardWriters = [];
    const saved = await this.meetings.save(m);
    this.hub.meetingEnded(m.id);
    return saved;
  }

  /**
   * Vào phòng họp: trả về địa chỉ máy chủ LiveKit và token.
   * Giáo viên chủ lớp/admin vào thì phòng tự mở. Học sinh chỉ vào được khi phòng đang mở.
   * Phụ huynh không vào phòng học.
   */
  async join(me: AuthUser, id: string) {
    if (me.role === Role.Parent) throw new ForbiddenException('Phụ huynh không tham gia phòng học');
    let m = await this.get(me, id);
    const isHost = me.role === Role.Admin || m.classroom.teacher.id === me.id;
    if (isHost) m = await this.start(me, id);
    else if (m.status !== MeetingStatus.Live) {
      throw new BadRequestException(m.status === MeetingStatus.Ended ? 'Cuộc họp đã kết thúc' : 'Giáo viên chưa mở phòng');
    }

    const user = await this.users.findById(me.id);
    const at = new AccessToken(this.cfg.get('LIVEKIT_API_KEY', 'devkey'), this.cfg.get('LIVEKIT_API_SECRET', 'secret'), {
      identity: user.id,
      name: user.fullName,
      ttl: '4h',
      metadata: JSON.stringify({ role: user.role, isHost }),
    });
    at.addGrant({
      room: m.roomName,
      roomJoin: true,
      canSubscribe: true,
      canPublish: true,
      canPublishData: true,
      roomAdmin: isHost,
    });
    return {
      meetingId: m.id,
      roomName: m.roomName,
      livekitUrl: this.cfg.get('LIVEKIT_URL', 'ws://localhost:7880'),
      token: await at.toJwt(),
      isHost,
      canWriteBoard: this.canWrite(m, me, isHost),
    };
  }

  private canWrite(m: Meeting, me: AuthUser, isHost: boolean): boolean {
    return isHost || m.boardAllowAll || m.boardWriters.includes(me.id);
  }

  async boardPermissions(me: AuthUser, id: string) {
    const m = await this.get(me, id);
    const isHost = me.role === Role.Admin || m.classroom.teacher.id === me.id;
    return { allowAll: m.boardAllowAll, writers: m.boardWriters, canWrite: this.canWrite(m, me, isHost) };
  }

  /** Giáo viên cấp hoặc thu quyền viết bảng. Chỉ học sinh đã vào lớp mới được cấp. */
  async setBoardPermissions(me: AuthUser, id: string, dto: BoardPermissionsDto) {
    const m = await this.loadManaged(me, id);
    if (m.status === MeetingStatus.Ended) throw new BadRequestException('Cuộc họp đã kết thúc');
    if (dto.studentIds) {
      const members = new Set(await this.classes.approvedStudentIds(m.classroom.id));
      const outsiders = dto.studentIds.filter((s) => !members.has(s));
      if (outsiders.length) throw new BadRequestException('Có học sinh không thuộc lớp này');
      m.boardWriters = [...new Set(dto.studentIds)];
    }
    if (dto.allowAll !== undefined) m.boardAllowAll = dto.allowAll;
    await this.meetings.save(m);
    this.hub.permissionsChanged(m.id, m.boardAllowAll, m.boardWriters);
    return { allowAll: m.boardAllowAll, writers: m.boardWriters, canWrite: true };
  }
}
