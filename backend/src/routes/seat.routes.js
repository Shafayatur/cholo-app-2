const express = require("express");
const router = express.Router();
const prisma = require("../../prisma/client");

// GET seats
router.get("/:rideId/seats", async (req, res) => {
    const rideId = Number(req.params.rideId);

    try {
        const ride = await prisma.ride.findUnique({
            where: { id: rideId },
        });

        // 🔴 ADD THIS CHECK
        if (!ride) {
            return res.status(404).json({ error: "Ride not found" });
        }

        const booked = await prisma.seatBooking.findMany({
            where: { rideId },
            select: { seatNo: true },
        });

        res.json({
            totalSeats: ride.seats,
            bookedSeats: booked.map(b => b.seatNo),
        });

    } catch (err) {
        console.error(err); // 🔴 ADD THIS
        res.status(500).json({ error: "Internal server error" });
    }
});


// BOOK seat
router.post("/", async (req, res) => {
    const { rideId, userId, seatNo } = req.body;

    try {
        const booking = await prisma.seatBooking.create({
            data: { rideId, userId, seatNo },
        });

        res.json(booking);
    } catch (e) {
        res.status(400).json({ error: "Seat already booked" });
    }
});

module.exports = router;