/*
  Warnings:

  - You are about to drop the column `passengerId` on the `Warning` table. All the data in the column will be lost.
  - Added the required column `userId` to the `Warning` table without a default value. This is not possible if the table is not empty.

*/
-- DropForeignKey
ALTER TABLE "Complaint" DROP CONSTRAINT "Complaint_driverId_fkey";

-- DropForeignKey
ALTER TABLE "Complaint" DROP CONSTRAINT "Complaint_passengerId_fkey";

-- DropForeignKey
ALTER TABLE "Warning" DROP CONSTRAINT "Warning_passengerId_fkey";

-- DropIndex
DROP INDEX "Warning_passengerId_idx";

-- AlterTable
ALTER TABLE "Complaint" ADD COLUMN     "complainantId" INTEGER,
ADD COLUMN     "metadata" JSONB,
ALTER COLUMN "driverId" DROP NOT NULL,
ALTER COLUMN "passengerId" DROP NOT NULL;

-- AlterTable
ALTER TABLE "Warning" DROP COLUMN "passengerId",
ADD COLUMN     "userId" INTEGER NOT NULL;

-- CreateIndex
CREATE INDEX "Complaint_complainantId_idx" ON "Complaint"("complainantId");

-- CreateIndex
CREATE INDEX "Warning_userId_idx" ON "Warning"("userId");

-- AddForeignKey
ALTER TABLE "Complaint" ADD CONSTRAINT "Complaint_complainantId_fkey" FOREIGN KEY ("complainantId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Complaint" ADD CONSTRAINT "Complaint_driverId_fkey" FOREIGN KEY ("driverId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Complaint" ADD CONSTRAINT "Complaint_passengerId_fkey" FOREIGN KEY ("passengerId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Warning" ADD CONSTRAINT "Warning_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
