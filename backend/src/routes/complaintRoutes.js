const express = require("express");
const router = express.Router();
const complaintController = require("../controllers/complaintController");

// Existing routes
router.post("/", complaintController.fileComplaint);
router.get("/", complaintController.getComplaints);
router.get("/:id", complaintController.getComplaintById);
router.put("/:id/status", complaintController.updateComplaintStatus);

// Warning and Ban routes
router.post("/warnings", complaintController.sendWarning);
router.post("/ban", complaintController.banPassenger);
router.get("/passenger/:passengerId/history", complaintController.getPassengerHistory);

// Passenger to Driver/Passenger complaints
router.post("/passenger-to-driver", complaintController.filePassengerToDriverComplaint);
router.post("/passenger-to-passenger", complaintController.filePassengerToPassengerComplaint);

// ============ NEW: Privacy-Preserving Identification Endpoints ============
// Identify passenger currently in a seat (Immediate reporting)
router.post("/identify-passenger", complaintController.identifyPassengerBySeat);

// Identify passenger by seat number and time range (Delayed reporting)
router.post("/identify-passenger-by-time", complaintController.identifyPassengerBySeatAndTime);

// Get seat map for a ride (only seat numbers, no names)
router.get("/ride/:rideId/seats", complaintController.getRideSeatMap);

module.exports = router;