const express = require("express");
const router = express.Router();
const rideController = require("../controllers/rideController");
const prisma = require("../lib/prisma");

router.post("/", rideController.createRide);
router.put("/:id/route", rideController.updateRideRoute);
router.put("/:id/start", rideController.startRide);
router.put("/:id/cancel", rideController.cancelRide);
router.get("/driver/:driverId", async (req, res) => {
  try {
    const driverId = Number(req.params.driverId);
    if (!Number.isInteger(driverId)) {
      return res.status(400).json({ error: "Invalid driverId" });
    }

    const rides = await prisma.ride.findMany({
      where: { driverId },
      orderBy: { createdAt: "desc" },
    });

    res.json(rides);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch rides" });
  }
});

router.get("/:id", rideController.getRideById);

module.exports = router;