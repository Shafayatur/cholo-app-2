const RATE_PER_KM = Number(process.env.FARE_RATE_PER_KM || 10);
const MIN_TRIP_KM = Number(process.env.FARE_MIN_TRIP_KM || 1);

function haversineKm(lat1, lon1, lat2, lon2) {
  if (
    lat1 == null ||
    lon1 == null ||
    lat2 == null ||
    lon2 == null ||
    Number.isNaN(lat1) ||
    Number.isNaN(lon1) ||
    Number.isNaN(lat2) ||
    Number.isNaN(lon2)
  ) {
    return null;
  }
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function rawDistanceKmForRide(ride) {
  const { originLat, originLng, destinationLat, destinationLng, routeDistanceKm } = ride;
  const fromCoords = haversineKm(originLat, originLng, destinationLat, destinationLng);
  if (fromCoords != null && !Number.isNaN(fromCoords) && fromCoords > 0) {
    return fromCoords;
  }
  if (routeDistanceKm != null && Number(routeDistanceKm) > 0) {
    return Number(routeDistanceKm);
  }
  return null;
}

function billableDistanceKmForRide(ride) {
  const raw = rawDistanceKmForRide(ride);
  if (raw == null) return null;
  return Math.max(MIN_TRIP_KM, raw);
}

function passengerFareForRide(ride) {
  const billable = billableDistanceKmForRide(ride);
  if (billable == null) {
    const err = new Error("NO_DISTANCE_FOR_FARE");
    err.code = "NO_DISTANCE_FOR_FARE";
    throw err;
  }
  return Math.ceil(billable * RATE_PER_KM);
}

function estimateRideFareRange({ routeDistanceKm, seats }) {
  const distance = Number(routeDistanceKm);
  const seatCount = Number(seats);

  if (!Number.isFinite(distance) || distance <= 0) {
    return {
      hasRoute: false,
      unitPassengerFare: 0,
      minFare: 0,
      maxFare: 0,
      billableDistanceKm: 0,
    };
  }

  if (!Number.isFinite(seatCount) || seatCount <= 0) {
    return {
      hasRoute: true,
      unitPassengerFare: 0,
      minFare: 0,
      maxFare: 0,
      billableDistanceKm: Math.max(MIN_TRIP_KM, distance),
    };
  }

  const billableDistanceKm = Math.max(MIN_TRIP_KM, distance);
  const unitPassengerFare = Math.ceil(billableDistanceKm * RATE_PER_KM);
  const minFare = Math.ceil(MIN_TRIP_KM * RATE_PER_KM);
  const maxFare = unitPassengerFare * Math.ceil(seatCount);

  return {
    hasRoute: true,
    unitPassengerFare,
    minFare,
    maxFare,
    billableDistanceKm,
  };
}

exports.getFareEstimate = async (req, res) => {
  try {
    const { routeDistanceKm, seats } = req.body;
    const estimate = estimateRideFareRange({ routeDistanceKm, seats });
    return res.json({
      ...estimate,
      ratePerKm: RATE_PER_KM,
      minBillableKm: MIN_TRIP_KM,
    });
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

module.exports.RATE_PER_KM = RATE_PER_KM;
module.exports.MIN_TRIP_KM = MIN_TRIP_KM;
module.exports.haversineKm = haversineKm;
module.exports.rawDistanceKmForRide = rawDistanceKmForRide;
module.exports.billableDistanceKmForRide = billableDistanceKmForRide;
module.exports.passengerFareForRide = passengerFareForRide;
module.exports.estimateRideFareRange = estimateRideFareRange;
