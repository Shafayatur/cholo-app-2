const express = require("express");
const router = express.Router();
const complaintController = require("../controllers/complaintController");

// Existing routes
router.post("/", complaintController.fileComplaint);
router.get("/", complaintController.getComplaints);
router.get("/:id", complaintController.getComplaintById);
router.put("/:id/status", complaintController.updateComplaintStatus);

// NEW ROUTES
router.post("/warnings", complaintController.sendWarning);
router.post("/ban", complaintController.banPassenger);
router.get("/passenger/:passengerId/history", complaintController.getPassengerHistory);
router.post("/passenger-to-driver", complaintController.filePassengerToDriverComplaint);
router.post("/passenger-to-passenger", complaintController.filePassengerToPassengerComplaint);

module.exports = router;