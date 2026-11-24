import { MigrationInterface, QueryRunner } from "typeorm";

export class NhacGioHoc1795506626070 implements MigrationInterface {
    name = 'NhacGioHoc1795506626070'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TABLE "reminder_logs" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "entryId" uuid NOT NULL, "date" character varying(10) NOT NULL, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_1da4a0fe7e60323d07005bb54fd" UNIQUE ("entryId", "date"), CONSTRAINT "PK_b829028c9baa35c1f66188c186d" PRIMARY KEY ("id"))`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`DROP TABLE "reminder_logs"`);
    }

}
