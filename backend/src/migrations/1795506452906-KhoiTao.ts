import { MigrationInterface, QueryRunner } from "typeorm";

/** Tạo toàn bộ bảng lần đầu. Sinh bằng: npm run migration:generate -- src/migrations/KhoiTao */

export class KhoiTao1795506452906 implements MigrationInterface {
    name = 'KhoiTao1795506452906'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`);
        await queryRunner.query(`CREATE TYPE "public"."users_role_enum" AS ENUM('admin', 'teacher', 'student', 'parent')`);
        await queryRunner.query(`CREATE TABLE "users" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "email" character varying NOT NULL, "passwordHash" character varying NOT NULL, "fullName" character varying NOT NULL, "role" "public"."users_role_enum" NOT NULL, "active" boolean NOT NULL DEFAULT true, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_97672ac88f789774dd47f7c8be3" UNIQUE ("email"), CONSTRAINT "PK_a3ffb1c0c8416b9fc6f907b7433" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "classrooms" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "name" character varying NOT NULL, "subject" character varying, "description" text, "inviteCode" character varying(8) NOT NULL, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "teacherId" uuid, CONSTRAINT "UQ_960add459f910d8bc6acdc4347b" UNIQUE ("inviteCode"), CONSTRAINT "PK_20b7b82896c06eda27548bd0c24" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "assignments" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "title" character varying NOT NULL, "description" text NOT NULL DEFAULT '', "dueAt" TIMESTAMP, "maxScore" real NOT NULL DEFAULT '10', "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "classroomId" uuid, CONSTRAINT "PK_c54ca359535e0012b04dcbd80ee" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "submissions" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "content" text NOT NULL, "attachments" text, "submittedAt" TIMESTAMP NOT NULL, "late" boolean NOT NULL DEFAULT false, "score" real, "feedback" text, "gradedAt" TIMESTAMP, "assignmentId" uuid, "studentId" uuid, CONSTRAINT "UQ_d08e86921fcb85d36ba6aa41bf2" UNIQUE ("assignmentId", "studentId"), CONSTRAINT "PK_10b3be95b8b2fb1e482e07d706b" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TYPE "public"."enrollments_status_enum" AS ENUM('pending', 'approved', 'rejected')`);
        await queryRunner.query(`CREATE TABLE "enrollments" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "status" "public"."enrollments_status_enum" NOT NULL DEFAULT 'pending', "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), "classroomId" uuid, "studentId" uuid, CONSTRAINT "UQ_0d13df45a63569d3596e422da11" UNIQUE ("classroomId", "studentId"), CONSTRAINT "PK_7c0f752f9fb68bf6ed7367ab00f" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TYPE "public"."files_visibility_enum" AS ENUM('class', 'private')`);
        await queryRunner.query(`CREATE TABLE "files" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "originalName" character varying NOT NULL, "mimeType" character varying NOT NULL, "size" integer NOT NULL, "storageKey" character varying NOT NULL, "visibility" "public"."files_visibility_enum" NOT NULL DEFAULT 'private', "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "uploadedById" uuid, "classroomId" uuid, CONSTRAINT "PK_6c16b9093a142e0e7613b04a3d9" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "lessons" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "title" character varying NOT NULL, "content" text NOT NULL DEFAULT '', "attachments" text NOT NULL, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "classroomId" uuid, CONSTRAINT "PK_9b9a8d455cac672d262d7275730" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TYPE "public"."meetings_status_enum" AS ENUM('scheduled', 'live', 'ended')`);
        await queryRunner.query(`CREATE TABLE "meetings" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "title" character varying NOT NULL, "scheduledAt" TIMESTAMP, "status" "public"."meetings_status_enum" NOT NULL DEFAULT 'scheduled', "roomName" character varying NOT NULL, "startedAt" TIMESTAMP, "endedAt" TIMESTAMP, "boardAllowAll" boolean NOT NULL DEFAULT false, "boardWriters" text NOT NULL DEFAULT '', "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "classroomId" uuid, "hostId" uuid, CONSTRAINT "UQ_f4fcaf3d77a7a2bb0fd9c3695a9" UNIQUE ("roomName"), CONSTRAINT "PK_aa73be861afa77eb4ed31f3ed57" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "notifications" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "userId" uuid NOT NULL, "type" character varying NOT NULL, "title" character varying NOT NULL, "body" text NOT NULL DEFAULT '', "classId" character varying, "tab" character varying, "readAt" TIMESTAMP, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_6a72c3c0f683f6462415e653c3a" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE INDEX "IDX_21e65af2f4f242d4c85a92aff4" ON "notifications" ("userId", "createdAt") `);
        await queryRunner.query(`CREATE TABLE "quizzes" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "title" character varying NOT NULL, "description" text NOT NULL DEFAULT '', "durationMinutes" integer, "dueAt" TIMESTAMP, "published" boolean NOT NULL DEFAULT false, "showAnswers" boolean NOT NULL DEFAULT true, "questions" text NOT NULL, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "classroomId" uuid, CONSTRAINT "PK_b24f0f7662cf6b3a0e7dba0a1b4" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "quiz_attempts" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "startedAt" TIMESTAMP NOT NULL, "answers" text, "submittedAt" TIMESTAMP, "score" real, "maxScore" real NOT NULL, "late" boolean NOT NULL DEFAULT false, "quizId" uuid, "studentId" uuid, CONSTRAINT "UQ_dde71ecc3653c031a60a97f1e9b" UNIQUE ("quizId", "studentId"), CONSTRAINT "PK_a84a93fb092359516dc5b325b90" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "timetable_entries" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "title" character varying NOT NULL, "dayOfWeek" smallint NOT NULL, "startTime" character varying(5) NOT NULL, "endTime" character varying(5) NOT NULL, "startDate" date NOT NULL, "endDate" date, "location" character varying, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "classroomId" uuid, CONSTRAINT "PK_11b6792dfdc5dd6849abed870d0" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "parent_links" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "parentId" uuid, "studentId" uuid, CONSTRAINT "UQ_4db46e6423fad4ff52368cd1b34" UNIQUE ("parentId", "studentId"), CONSTRAINT "PK_222960eedb6ffea31a97611369b" PRIMARY KEY ("id"))`);
        await queryRunner.query(`ALTER TABLE "classrooms" ADD CONSTRAINT "FK_ea22bf3c6b069755e01340f6334" FOREIGN KEY ("teacherId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "assignments" ADD CONSTRAINT "FK_0f17cfc7f30874d8eff2855a24f" FOREIGN KEY ("classroomId") REFERENCES "classrooms"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "submissions" ADD CONSTRAINT "FK_c2611c601f49945ceff5c0909a2" FOREIGN KEY ("assignmentId") REFERENCES "assignments"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "submissions" ADD CONSTRAINT "FK_4fc99318a291abd7e2a50f50851" FOREIGN KEY ("studentId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "enrollments" ADD CONSTRAINT "FK_a766f2b4118abeedc8636ef567b" FOREIGN KEY ("classroomId") REFERENCES "classrooms"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "enrollments" ADD CONSTRAINT "FK_bf3ba3dfa95e2df7388eb4589fd" FOREIGN KEY ("studentId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "files" ADD CONSTRAINT "FK_a525d85f0ac59aa9a971825e1af" FOREIGN KEY ("uploadedById") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "files" ADD CONSTRAINT "FK_03881e5a55b9699271c98e73c6a" FOREIGN KEY ("classroomId") REFERENCES "classrooms"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "lessons" ADD CONSTRAINT "FK_24e457392edd2a2c916be50dc45" FOREIGN KEY ("classroomId") REFERENCES "classrooms"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "meetings" ADD CONSTRAINT "FK_345df39c106f650310386163601" FOREIGN KEY ("classroomId") REFERENCES "classrooms"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "meetings" ADD CONSTRAINT "FK_f4c16c40d16a9eb2003c5dd1ff2" FOREIGN KEY ("hostId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "notifications" ADD CONSTRAINT "FK_692a909ee0fa9383e7859f9b406" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "quizzes" ADD CONSTRAINT "FK_18a03afa516b6c8bcfe058eacd8" FOREIGN KEY ("classroomId") REFERENCES "classrooms"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "quiz_attempts" ADD CONSTRAINT "FK_23f2bbe9288b221b1b377372782" FOREIGN KEY ("quizId") REFERENCES "quizzes"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "quiz_attempts" ADD CONSTRAINT "FK_30ae16bcedd2b2663686edfc7a8" FOREIGN KEY ("studentId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "timetable_entries" ADD CONSTRAINT "FK_397e14a2715ba8cf7c820f94214" FOREIGN KEY ("classroomId") REFERENCES "classrooms"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "parent_links" ADD CONSTRAINT "FK_1104ad9d6ea62e14b6c344d5b29" FOREIGN KEY ("parentId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "parent_links" ADD CONSTRAINT "FK_9f562dd73387033384658162132" FOREIGN KEY ("studentId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "parent_links" DROP CONSTRAINT "FK_9f562dd73387033384658162132"`);
        await queryRunner.query(`ALTER TABLE "parent_links" DROP CONSTRAINT "FK_1104ad9d6ea62e14b6c344d5b29"`);
        await queryRunner.query(`ALTER TABLE "timetable_entries" DROP CONSTRAINT "FK_397e14a2715ba8cf7c820f94214"`);
        await queryRunner.query(`ALTER TABLE "quiz_attempts" DROP CONSTRAINT "FK_30ae16bcedd2b2663686edfc7a8"`);
        await queryRunner.query(`ALTER TABLE "quiz_attempts" DROP CONSTRAINT "FK_23f2bbe9288b221b1b377372782"`);
        await queryRunner.query(`ALTER TABLE "quizzes" DROP CONSTRAINT "FK_18a03afa516b6c8bcfe058eacd8"`);
        await queryRunner.query(`ALTER TABLE "notifications" DROP CONSTRAINT "FK_692a909ee0fa9383e7859f9b406"`);
        await queryRunner.query(`ALTER TABLE "meetings" DROP CONSTRAINT "FK_f4c16c40d16a9eb2003c5dd1ff2"`);
        await queryRunner.query(`ALTER TABLE "meetings" DROP CONSTRAINT "FK_345df39c106f650310386163601"`);
        await queryRunner.query(`ALTER TABLE "lessons" DROP CONSTRAINT "FK_24e457392edd2a2c916be50dc45"`);
        await queryRunner.query(`ALTER TABLE "files" DROP CONSTRAINT "FK_03881e5a55b9699271c98e73c6a"`);
        await queryRunner.query(`ALTER TABLE "files" DROP CONSTRAINT "FK_a525d85f0ac59aa9a971825e1af"`);
        await queryRunner.query(`ALTER TABLE "enrollments" DROP CONSTRAINT "FK_bf3ba3dfa95e2df7388eb4589fd"`);
        await queryRunner.query(`ALTER TABLE "enrollments" DROP CONSTRAINT "FK_a766f2b4118abeedc8636ef567b"`);
        await queryRunner.query(`ALTER TABLE "submissions" DROP CONSTRAINT "FK_4fc99318a291abd7e2a50f50851"`);
        await queryRunner.query(`ALTER TABLE "submissions" DROP CONSTRAINT "FK_c2611c601f49945ceff5c0909a2"`);
        await queryRunner.query(`ALTER TABLE "assignments" DROP CONSTRAINT "FK_0f17cfc7f30874d8eff2855a24f"`);
        await queryRunner.query(`ALTER TABLE "classrooms" DROP CONSTRAINT "FK_ea22bf3c6b069755e01340f6334"`);
        await queryRunner.query(`DROP TABLE "parent_links"`);
        await queryRunner.query(`DROP TABLE "timetable_entries"`);
        await queryRunner.query(`DROP TABLE "quiz_attempts"`);
        await queryRunner.query(`DROP TABLE "quizzes"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_21e65af2f4f242d4c85a92aff4"`);
        await queryRunner.query(`DROP TABLE "notifications"`);
        await queryRunner.query(`DROP TABLE "meetings"`);
        await queryRunner.query(`DROP TYPE "public"."meetings_status_enum"`);
        await queryRunner.query(`DROP TABLE "lessons"`);
        await queryRunner.query(`DROP TABLE "files"`);
        await queryRunner.query(`DROP TYPE "public"."files_visibility_enum"`);
        await queryRunner.query(`DROP TABLE "enrollments"`);
        await queryRunner.query(`DROP TYPE "public"."enrollments_status_enum"`);
        await queryRunner.query(`DROP TABLE "submissions"`);
        await queryRunner.query(`DROP TABLE "assignments"`);
        await queryRunner.query(`DROP TABLE "classrooms"`);
        await queryRunner.query(`DROP TABLE "users"`);
        await queryRunner.query(`DROP TYPE "public"."users_role_enum"`);
    }

}
