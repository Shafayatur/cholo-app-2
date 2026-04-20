const express = require("express");
const router = express.Router();
const seatBookingController = require("../controllers/seatBookingController");

router.get("/:rideId/seats", seatBookingController.getSeatsByRide);
router.post("/", seatBookingController.createSeatBooking);
router.post("/:rideId/complete-payment", seatBookingController.completePayment);

module.exports = router;
