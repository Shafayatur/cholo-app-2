-- CreateTable
CREATE TABLE "SeatBooking" (
    "id" SERIAL NOT NULL,
    "rideId" INTEGER NOT NULL,
    "userId" INTEGER NOT NULL,
    "seatNo" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SeatBooking_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "SeatBooking_rideId_seatNo_key" ON "SeatBooking"("rideId", "seatNo");

-- CreateIndex
CREATE UNIQUE INDEX "SeatBooking_rideId_userId_key" ON "SeatBooking"("rideId", "userId");

-- AddForeignKey
ALTER TABLE "SeatBooking" ADD CONSTRAINT "SeatBooking_rideId_fkey" FOREIGN KEY ("rideId") REFERENCES "Ride"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SeatBooking" ADD CONSTRAINT "SeatBooking_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
