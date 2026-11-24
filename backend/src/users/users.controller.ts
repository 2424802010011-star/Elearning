import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { CurrentUser, Roles } from '../common/decorators';
import type { AuthUser } from '../common/decorators';
import { Role } from '../common/role.enum';
import { CreateParentLinkDto, CreateUserDto, ResetPasswordDto, UpdateRoleDto, UpdateUserDto } from './dto';
import { UsersService } from './users.service';

@ApiTags('Người dùng & phụ huynh')
@ApiBearerAuth()
@Controller()
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('users')
  @Roles(Role.Admin)
  list(@Query('role') role?: Role, @Query('q') q?: string) {
    return this.users.list(role, q);
  }

  /** Admin tạo tài khoản với bất kỳ vai trò nào (kể cả admin). */
  @Post('users')
  @Roles(Role.Admin)
  create(@Body() dto: CreateUserDto) {
    return this.users.create(dto.email, dto.password, dto.fullName, dto.role);
  }

  @Patch('users/:id/role')
  @Roles(Role.Admin)
  updateRole(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateRoleDto, @CurrentUser() me: AuthUser) {
    return this.users.updateRole(id, dto.role, me);
  }

  /** Sửa tên, đổi vai trò, khóa / mở khóa. */
  @Patch('users/:id')
  @Roles(Role.Admin)
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateUserDto, @CurrentUser() me: AuthUser) {
    return this.users.update(id, dto, me);
  }

  @Post('users/:id/password')
  @Roles(Role.Admin)
  @HttpCode(204)
  resetPassword(@Param('id', ParseUUIDPipe) id: string, @Body() dto: ResetPasswordDto) {
    return this.users.resetPassword(id, dto.password);
  }

  @Get('parent-links')
  @Roles(Role.Admin)
  links() {
    return this.users.listLinks();
  }

  @Delete('parent-links/:id')
  @Roles(Role.Admin)
  @HttpCode(204)
  unlink(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.unlink(id);
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
