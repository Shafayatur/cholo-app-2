const express = require("express");
const router = express.Router();
const prisma = require("../lib/prisma");
const {
  passengerFareForRide,
  billableDistanceKmForRide,
  RATE_PER_KM,
  MIN_TRIP_KM,
} = require("../lib/fare");
const socketHub = require("../lib/socketHub");

const parseSeatNumbers = (input) => {
  if (!Array.isArray(input)) return [];
  return [...new Set(input.map((value) => Number(value)).filter(Number.isInteger))];
};

router.get("/:rideId/seats", async (req, res) => {
  const rideId = Number(req.params.rideId);
  const userId = req.query.userId ? Number(req.query.userId) : null;

  if (!Number.isInteger(rideId)) {
    return res.status(400).json({ error: "Invalid rideId" });
  }

  try {
    const ride = await prisma.ride.findUnique({
      where: { id: rideId },
      select: {
        seats: true,
        totalFare: true,
        originLat: true,
        originLng: true,
        destinationLat: true,
        destinationLng: true,
        routeDistanceKm: true,
      },
    });

    if (!ride) {
      return res.status(404).json({ error: "Ride not found" });
    }

    let unitPassengerFare = null;
    let billableDistanceKm = null;
    try {
      unitPassengerFare = passengerFareForRide(ride);
      billableDistanceKm = billableDistanceKmForRide(ride);
    } catch (e) {
      if (e.code !== "NO_DISTANCE_FOR_FARE") {
        throw e;
      }
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
          fare: null,
        };
      }

      return {
        seatNo,
        state: isMine ? "BOOKED_BY_ME" : "BOOKED",
        isMine,
        fare: booking.fare,
        passenger: {
          id: booking.user.id,
          name: booking.user.name,
          email: booking.user.email,
        },
      };
    });

    res.json({
      totalSeats: ride.seats,
      totalFare: ride.totalFare,
      unitPassengerFare,
      billableDistanceKm,
      fareRatePerKm: RATE_PER_KM,
      minBillableKm: MIN_TRIP_KM,
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
    const payload = await prisma.$transaction(async (tx) => {
      const ride = await tx.ride.findUnique({
        where: { id: rideId },
        select: {
          id: true,
          seats: true,
          originLat: true,
          originLng: true,
          destinationLat: true,
          destinationLng: true,
          routeDistanceKm: true,
        },
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

      let unitFare;
      try {
        unitFare = passengerFareForRide(ride);
      } catch (e) {
        if (e.code === "NO_DISTANCE_FOR_FARE") {
          const wrapped = new Error("NO_DISTANCE_FOR_FARE");
          throw wrapped;
        }
        throw e;
      }

      const bookingTotal = unitFare * seatNumbers.length;

      await tx.seatBooking.createMany({
        data: seatNumbers.map((seatNo) => ({
          rideId,
          userId,
          seatNo,
          fare: unitFare,
        })),
      });

      const updatedRide = await tx.ride.update({
        where: { id: rideId },
        data: {
          totalFare: { increment: bookingTotal },
        },
        select: { totalFare: true },
      });

      return {
        seats: seatNumbers,
        unitFare,
        bookingTotal,
        rideTotalFare: updatedRide.totalFare,
      };
    });

    socketHub.emitFareUpdate({
      rideId,
      totalFare: payload.rideTotalFare,
    });

    res.status(201).json({
      message: "Seat booking confirmed",
      seats: payload.seats,
      unitFare: payload.unitFare,
      bookingTotal: payload.bookingTotal,
      rideTotalFare: payload.rideTotalFare,
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
    if (e.message === "NO_DISTANCE_FOR_FARE") {
      return res.status(400).json({
        error:
          "Ride has no usable distance data (coordinates or route distance). Cannot compute fare.",
      });
    }
    console.error(e);
    res.status(500).json({ error: "Internal server error" });
  }
});

module.exports = router;
