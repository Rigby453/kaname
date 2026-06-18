-- Migration: auth_phone_ru_compliance
-- RF law 406-FZ: email → nullable, add phone (nullable, unique, Russian E.164)

-- Make email nullable (existing rows keep their value)
ALTER TABLE "User" ALTER COLUMN "email" DROP NOT NULL;

-- Add phone column (nullable, unique)
ALTER TABLE "User" ADD COLUMN "phone" TEXT;
ALTER TABLE "User" ADD CONSTRAINT "User_phone_key" UNIQUE ("phone");
