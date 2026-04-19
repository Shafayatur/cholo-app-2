const express = require("express");
const router = express.Router();
const rideController = require("../controllers/rideController");
const prisma = require("../../prisma/client"); // 👈 ADD THIS

router.post("/", rideController.createRide);
router.post("/fare-estimate", rideController.getFareEstimate);
router.put("/:id/route", rideController.updateRideRoute);
router.put("/:id/start", rideController.startRide);
router.put("/:id/cancel", rideController.cancelRide);

// ✅ NEW ROUTE (ADD THIS)
router.get("/driver/:driverId", async (req, res) => {
  try {
    const driverId = parseInt(req.params.driverId);

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