/**
 * Single source of truth for passenger fare math (keep in sync with driver estimates in app).
 * Uses billable distance = max(MIN_TRIP_KM, raw route distance).
 */
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
  const {
    originLat,
    originLng,
    destinationLat,
    destinationLng,
    routeDistanceKm,
  } = ride;
  const fromCoords = haversineKm(
    originLat,
    originLng,
    destinationLat,
    destinationLng
  );
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

/**
 * Fare for one passenger "leg" on this ride (today: whole stored route; later per segment).
 */
function passengerFareForRide(ride) {
  const billable = billableDistanceKmForRide(ride);
  if (billable == null) {
    const err = new Error("NO_DISTANCE_FOR_FARE");
    err.code = "NO_DISTANCE_FOR_FARE";
    throw err;
  }
  // Always charge whole currency units, rounded up.
  return Math.ceil(billable * RATE_PER_KM);
}

module.exports = {
  RATE_PER_KM,
  MIN_TRIP_KM,
  haversineKm,
  rawDistanceKmForRide,
  billableDistanceKmForRide,
  passengerFareForRide,
};
