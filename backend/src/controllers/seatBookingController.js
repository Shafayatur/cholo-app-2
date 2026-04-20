const prisma = require("../lib/prisma");
const {
  passengerFareForRide,
  billableDistanceKmForRide,
  RATE_PER_KM,
  MIN_TRIP_KM,
} = require("./fareController");
const socketHub = require("../lib/socketHub");

const parseSeatNumbers = (input) => {
  if (!Array.isArray(input)) return [];
  return [...new Set(input.map((value) => Number(value)).filter(Number.isInteger))];
};

exports.getSeatsByRide = async (req, res) => {
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
      if (e.code !== "NO_DISTANCE_FOR_FARE") throw e;
    }

    const activeBookings = await prisma.seatBooking.findMany({
      where: { rideId, paidAt: null },
      include: {
        user: { select: { id: true, name: true, email: true } },
      },
    });

    const paidBookings = await prisma.seatBooking.findMany({
      where: { rideId, paidAt: { not: null } },
      include: {
        user: { select: { id: true, name: true } },
      },
      orderBy: { paidAt: "desc" },
    });

    const bookingBySeat = new Map(activeBookings.map((booking) => [booking.seatNo, booking]));
    const seats = Array.from({ length: ride.seats }, (_, index) => {
      const seatNo = index + 1;
      const booking = bookingBySeat.get(seatNo);
      const isMine = Boolean(userId && booking?.userId === userId);

      if (!booking) {
        return { seatNo, state: "AVAILABLE", isMine: false, passenger: null, fare: null };
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

    const gotTotalMoney = paidBookings.reduce((sum, item) => sum + Math.ceil(Number(item.fare) || 0), 0);
    const breakdownByPassenger = new Map();
    for (const item of paidBookings) {
      const current = breakdownByPassenger.get(item.userId) || {
        userId: item.userId,
        passengerName: item.user?.name || `P${item.userId}`,
        amount: 0,
      };
      current.amount += Math.ceil(Number(item.fare) || 0);
      breakdownByPassenger.set(item.userId, current);
    }

    return res.json({
      totalSeats: ride.seats,
      totalFare: ride.totalFare,
      gotTotalMoney,
      paidBreakdown: Array.from(breakdownByPassenger.values()).sort((a, b) => b.amount - a.amount),
      unitPassengerFare,
      billableDistanceKm,
      fareRatePerKm: RATE_PER_KM,
      minBillableKm: MIN_TRIP_KM,
      seats,
      bookedSeats: activeBookings.map((booking) => booking.seatNo),
      myBookedSeats: userId
        ? activeBookings.filter((booking) => booking.userId === userId).map((booking) => booking.seatNo)
        : [],
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Internal server error" });
  }
};

exports.createSeatBooking = async (req, res) => {
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

      if (!ride) throw new Error("RIDE_NOT_FOUND");

      const outOfRangeSeat = seatNumbers.find((seatNo) => seatNo < 1 || seatNo > ride.seats);
      if (outOfRangeSeat) throw new Error("INVALID_SEAT_NUMBER");

      const existingUserBookings = await tx.seatBooking.findMany({
        where: { rideId, userId, paidAt: null },
        select: { seatNo: true },
      });
      if (existingUserBookings.length > 0) throw new Error("USER_ALREADY_BOOKED");

      const conflictingBookings = await tx.seatBooking.findMany({
        where: { rideId, paidAt: null, seatNo: { in: seatNumbers } },
        select: { seatNo: true },
      });
      if (conflictingBookings.length > 0) {
        const conflictError = new Error("SEAT_ALREADY_BOOKED");
        conflictError.conflictSeatNos = conflictingBookings.map((booking) => booking.seatNo);
        throw conflictError;
      }

      let unitFare;
      try {
        unitFare = passengerFareForRide(ride);
      } catch (e) {
        if (e.code === "NO_DISTANCE_FOR_FARE") throw new Error("NO_DISTANCE_FOR_FARE");
        throw e;
      }

      const bookingTotal = unitFare * seatNumbers.length;
      await tx.seatBooking.createMany({
        data: seatNumbers.map((seatNo) => ({
          rideId,
          userId,
          seatNo,
          fare: unitFare,
          paymentMethod: null,
          paymentPhone: null,
          paidAt: null,
        })),
      });

      const updatedRide = await tx.ride.update({
        where: { id: rideId },
        data: { totalFare: { increment: bookingTotal } },
        select: { totalFare: true },
      });

      return {
        seats: seatNumbers,
        unitFare,
        bookingTotal,
        rideTotalFare: Math.ceil(Number(updatedRide.totalFare) || 0),
      };
    });

    socketHub.emitFareUpdate({ rideId, totalFare: payload.rideTotalFare });
    return res.status(201).json({
      message: "Seat booking confirmed",
      seats: payload.seats,
      unitFare: payload.unitFare,
      bookingTotal: payload.bookingTotal,
      rideTotalFare: payload.rideTotalFare,
    });
  } catch (e) {
    if (e.message === "RIDE_NOT_FOUND") return res.status(404).json({ error: "Ride not found" });
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
        error: "Ride has no usable distance data (coordinates or route distance). Cannot compute fare.",
      });
    }
    console.error(e);
    return res.status(500).json({ error: "Internal server error" });
  }
};

exports.completePayment = async (req, res) => {
  const rideId = Number(req.params.rideId);
  const userId = Number(req.body.userId);
  const paymentMethod = String(req.body.paymentMethod || "").toLowerCase();
  const paymentPhone = String(req.body.paymentPhone || "").trim();
  const allowedMethods = ["cash", "bkash", "nagad"];

  if (!Number.isInteger(rideId) || !Number.isInteger(userId)) {
    return res.status(400).json({ error: "rideId and userId are required" });
  }
  if (!allowedMethods.includes(paymentMethod)) {
    return res.status(400).json({ error: "Invalid payment method" });
  }
  if (paymentMethod !== "cash" && !/^\d{11}$/.test(paymentPhone)) {
    return res.status(400).json({ error: "Valid 11-digit phone number is required" });
  }

  try {
    const payload = await prisma.$transaction(async (tx) => {
      const myBookings = await tx.seatBooking.findMany({
        where: { rideId, userId, paidAt: null },
        select: { id: true, seatNo: true, fare: true },
        orderBy: { seatNo: "asc" },
      });
      if (!myBookings.length) throw new Error("NO_ACTIVE_BOOKINGS");

      const payableAmount = myBookings.reduce((sum, b) => sum + Math.ceil(Number(b.fare) || 0), 0);
      const bookingIds = myBookings.map((b) => b.id);
      const now = new Date();

      await tx.seatBooking.updateMany({
        where: { id: { in: bookingIds } },
        data: {
          paymentMethod,
          paymentPhone: paymentMethod === "cash" ? null : paymentPhone,
          paidAt: now,
        },
      });

      const updatedRide = await tx.ride.update({
        where: { id: rideId },
        data: { totalFare: { decrement: payableAmount } },
        select: { totalFare: true },
      });

      return {
        payableAmount,
        seats: myBookings.map((b) => b.seatNo),
        rideTotalFare: Math.max(0, Math.ceil(Number(updatedRide.totalFare) || 0)),
      };
    });

    socketHub.emitFareUpdate({ rideId, totalFare: payload.rideTotalFare });
    return res.json({
      message: "Payment completed and seats released",
      rideId,
      userId,
      paymentMethod,
      payableAmount: payload.payableAmount,
      seats: payload.seats,
      rideTotalFare: payload.rideTotalFare,
    });
  } catch (err) {
    if (err.message === "NO_ACTIVE_BOOKINGS") {
      return res.status(404).json({ error: "No active booked seats found for this passenger" });
    }
    console.error(err);
    return res.status(500).json({ error: "Internal server error" });
  }
};
