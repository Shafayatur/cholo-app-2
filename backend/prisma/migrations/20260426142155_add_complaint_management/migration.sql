-- CreateTable
CREATE TABLE "Warning" (
    "id" SERIAL NOT NULL,
    "passengerId" INTEGER NOT NULL,
    "complaintId" INTEGER NOT NULL,
    "message" TEXT NOT NULL,
    "issuedBy" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Warning_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Warning_passengerId_idx" ON "Warning"("passengerId");

-- CreateIndex
CREATE INDEX "Warning_complaintId_idx" ON "Warning"("complaintId");

-- AddForeignKey
ALTER TABLE "Warning" ADD CONSTRAINT "Warning_passengerId_fkey" FOREIGN KEY ("passengerId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Warning" ADD CONSTRAINT "Warning_complaintId_fkey" FOREIGN KEY ("complaintId") REFERENCES "Complaint"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
