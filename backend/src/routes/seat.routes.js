const express = require("express");
const router = express.Router();
const prisma = require("../../prisma/client");

const parseSeatNumbers = (input) => {
  if (!Array.isArray(input)) return [];
  return [...new Set(input.map((value) => Number(value)).filter(Number.isInteger))];
};

// GET seats with ownership details
router.get("/:rideId/seats", async (req, res) => {
  const rideId = Number(req.params.rideId);
  const userId = req.query.userId ? Number(req.query.userId) : null;

  if (!Number.isInteger(rideId)) {
    return res.status(400).json({ error: "Invalid rideId" });
  }

  try {
    const ride = await prisma.ride.findUnique({
      where: { id: rideId },
      select: { seats: true },
    });

    if (!ride) {
      return res.status(404).json({ error: "Ride not found" });
    }

    const bookings = await prisma.seatBooking.findMany({
      where: { rideId },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
      },
    });

    const bookingBySeat = new Map(bookings.map((booking) => [booking.seatNo, booking]));
    const seats = Array.from({ length: ride.seats }, (_, index) => {
      const seatNo = index + 1;
      const booking = bookingBySeat.get(seatNo);
      const isMine = Boolean(userId && booking?.userId === userId);

      if (!booking) {
        return {
          seatNo,
          state: "AVAILABLE",
          isMine: false,
          passenger: null,
        };
      }

      return {
        seatNo,
        state: isMine ? "BOOKED_BY_ME" : "BOOKED",
        isMine,
        passenger: {
          id: booking.user.id,
          name: booking.user.name,
          email: booking.user.email,
        },
      };
    });

    res.json({
      totalSeats: ride.seats,
      seats,
      bookedSeats: bookings.map((booking) => booking.seatNo),
      myBookedSeats: userId
        ? bookings.filter((booking) => booking.userId === userId).map((booking) => booking.seatNo)
        : [],
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Internal server error" });
  }
});

// BOOK one or many seats atomically
router.post("/", async (req, res) => {
  const rideId = Number(req.body.rideId);
  const userId = Number(req.body.userId);
  const seatNumbers = parseSeatNumbers(req.body.seats ?? [req.body.seatNo]);

  if (!Number.isInteger(rideId) || !Number.isInteger(userId)) {
    return res.status(400).json({ error: "rideId and userId are required" });
  }

  if (!seatNumbers.length) {
    return res.status(400).json({ error: "At least one seat must be selected" });
  }

  try {
    const result = await prisma.$transaction(async (tx) => {
      const ride = await tx.ride.findUnique({
        where: { id: rideId },
        select: { id: true, seats: true },
      });

      if (!ride) {
        throw new Error("RIDE_NOT_FOUND");
      }

      const outOfRangeSeat = seatNumbers.find((seatNo) => seatNo < 1 || seatNo > ride.seats);
      if (outOfRangeSeat) {
        throw new Error("INVALID_SEAT_NUMBER");
      }

      const existingUserBookings = await tx.seatBooking.findMany({
        where: { rideId, userId },
        select: { seatNo: true },
      });
      if (existingUserBookings.length > 0) {
        throw new Error("USER_ALREADY_BOOKED");
      }

      const conflictingBookings = await tx.seatBooking.findMany({
        where: {
          rideId,
          seatNo: { in: seatNumbers },
        },
        select: { seatNo: true },
      });

      if (conflictingBookings.length > 0) {
        const conflictSeatNos = conflictingBookings.map((booking) => booking.seatNo);
        const conflictError = new Error("SEAT_ALREADY_BOOKED");
        conflictError.conflictSeatNos = conflictSeatNos;
        throw conflictError;
      }

      await tx.seatBooking.createMany({
        data: seatNumbers.map((seatNo) => ({ rideId, userId, seatNo })),
      });

      return seatNumbers;
    });

    res.status(201).json({
      message: "Seat booking confirmed",
      seats: result,
    });
  } catch (e) {
    if (e.message === "RIDE_NOT_FOUND") {
      return res.status(404).json({ error: "Ride not found" });
    }
    if (e.message === "INVALID_SEAT_NUMBER") {
      return res.status(400).json({ error: "One or more seat numbers are invalid" });
    }
    if (e.message === "USER_ALREADY_BOOKED") {
      return res.status(409).json({
        error: "You already confirmed booking for this ride. Seats cannot be changed.",
      });
    }
    if (e.message === "SEAT_ALREADY_BOOKED") {
      return res.status(409).json({
        error: "One or more selected seats are already booked",
        seats: e.conflictSeatNos ?? [],
      });
    }
    console.error(e);
    res.status(500).json({ error: "Internal server error" });
  }
});

module.exports = router;