import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { CurrentUser, Roles } from '../common/decorators';
import type { AuthUser } from '../common/decorators';
import { Role } from '../common/role.enum';
import { CreateParentLinkDto, CreateUserDto, UpdateRoleDto } from './dto';
import { UsersService } from './users.service';

@ApiTags('Người dùng & phụ huynh')
@ApiBearerAuth()
@Controller()
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('users')
  @Roles(Role.Admin)
  list(@Query('role') role?: Role) {
    return this.users.list(role);
  }

  /** Admin tạo tài khoản với bất kỳ vai trò nào (kể cả admin). */
  @Post('users')
  @Roles(Role.Admin)
  create(@Body() dto: CreateUserDto) {
    return this.users.create(dto.email, dto.password, dto.fullName, dto.role);
  }

  @Patch('users/:id/role')
  @Roles(Role.Admin)
  updateRole(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateRoleDto) {
    return this.users.updateRole(id, dto.role);
  }

  @Post('parent-links')
  @Roles(Role.Admin)
  link(@Body() dto: CreateParentLinkDto) {
    return this.users.linkParent(dto.parentId, dto.studentId);
  }

  @Get('me/children')
  @Roles(Role.Parent)
  children(@CurrentUser() me: AuthUser) {
    return this.users.childrenOf(me.id);
  }
}
