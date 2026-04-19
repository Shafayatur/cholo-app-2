-- Align DB with schema: Ride.totalFare and SeatBooking.fare
ALTER TABLE "Ride" ADD COLUMN "totalFare" DOUBLE PRECISION NOT NULL DEFAULT 0;

ALTER TABLE "SeatBooking" ADD COLUMN "fare" DOUBLE PRECISION NOT NULL DEFAULT 0;
