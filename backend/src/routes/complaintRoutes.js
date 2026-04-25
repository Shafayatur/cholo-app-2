const express = require("express");
const router = express.Router();
const complaintController = require("../controllers/complaintController");

router.post("/", complaintController.fileComplaint);
router.get("/", complaintController.getComplaints);
router.get("/:id", complaintController.getComplaintById);
router.put("/:id/status", complaintController.updateComplaintStatus);

module.exports = router;