-- ADR-064: name+avatar profile sync — `name` already existed on User and now the
-- PATCH /auth/me endpoint accepts it; `avatarPreset` is a new nullable column
-- (previously the avatar preset id lived only on-device).
-- AlterTable
ALTER TABLE "User" ADD COLUMN     "avatarPreset" TEXT;
