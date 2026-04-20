const express = require("express");
const router = express.Router();
const fareController = require("../controllers/fareController");

router.post("/estimate", fareController.getFareEstimate);

module.exports = router;
