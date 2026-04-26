-- AlterTable
ALTER TABLE "User" ADD COLUMN     "banExpiryDate" TIMESTAMP(3),
ADD COLUMN     "banReason" TEXT,
ADD COLUMN     "isBanned" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "phone" TEXT,
ADD COLUMN     "warningCount" INTEGER NOT NULL DEFAULT 0;
