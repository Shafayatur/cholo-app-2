const express = require("express");
const cors = require("cors");
const authRoutes = require("./routes/authRoutes");
const rideRoutes = require("./routes/rideRoutes");
const fareRoutes = require("./routes/fareRoutes");
const bookingRoutes = require("./routes/bookingRoutes");
const seatBookingRoutes = require("./routes/seatBookingRoutes");


const app = express();

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.send("Cholo backend is running");
});

app.use("/api/auth", authRoutes);
app.use("/api/rides", rideRoutes);
app.use("/api/fares", fareRoutes);
app.use("/api/bookings", bookingRoutes);
app.use("/seat-booking", seatBookingRoutes);

module.exports = app;



