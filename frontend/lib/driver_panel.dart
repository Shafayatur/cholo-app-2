import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'backend_config.dart';
import 'ride_details_page.dart';
import 'my_rides_page_driver.dart'; 

class DriverPanel extends StatefulWidget {
  const DriverPanel({Key? key}) : super(key: key);

  @override
  State<DriverPanel> createState() => _DriverPanelState();
}

class _DriverPanelState extends State<DriverPanel> {
  final TextEditingController originController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final TextEditingController departureController = TextEditingController();
  final TextEditingController seatsController = TextEditingController();

  int? rideId;
  String rideStatus = "NOT_CREATED";
  bool isLoading = false;
  bool isBookingLoading = false;
  DateTime? selectedDepartureTime;
  List<Map<String, dynamic>> bookingRequests = [];
  List<LatLng> routePoints = [];
  double? routeDistanceKm;
  double? routeDurationMin;
  List<Map<String, dynamic>> searchResults = [];
  bool isSearching = false;
  final MapController mapController = MapController();

  LatLng? startLocation;
  LatLng? endLocation;

  final String openRouteServiceApiKey =
      "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImU0YzRiNTY2MGNjMjRmYjI5ZjE3ZTFiMGFmMGNiZWUzIiwiaCI6Im11cm11cjY0In0=";

  bool get canEdit => rideStatus == "NOT_CREATED" || rideStatus == "PLANNED";
  bool get canShowCreate => rideId == null;
  bool get canShowPlannedActions => rideId != null && rideStatus == "PLANNED";

  int minEstimatedFare = 0;
  int maxEstimatedFare = 0;
  bool isFareEstimateLoading = false;

  Future<void> _fetchFareEstimatesFromBackend() async {
    if (routeDistanceKm == null) {
      minEstimatedFare = 0;
      maxEstimatedFare = 0;
      return;
    }
    final seatCount = int.tryParse(seatsController.text.trim()) ?? 0;
    if (seatCount <= 0) {
      minEstimatedFare = 0;
      maxEstimatedFare = 0;
      return;
    }
    if (mounted) {
      setState(() => isFareEstimateLoading = true);
    }
    try {
      final res = await http.post(
        Uri.parse('${backendUrl}/api/rides/fare-estimate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'routeDistanceKm': routeDistanceKm,
          'seats': seatCount,
        }),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          minEstimatedFare = (data['minFare'] is num)
              ? (data['minFare'] as num).toInt()
              : int.tryParse(data['minFare']?.toString() ?? '0') ?? 0;
          maxEstimatedFare = (data['maxFare'] is num)
              ? (data['maxFare'] as num).toInt()
              : int.tryParse(data['maxFare']?.toString() ?? '0') ?? 0;
        });
      } else {
        setState(() {
          minEstimatedFare = 0;
          maxEstimatedFare = 0;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        minEstimatedFare = 0;
        maxEstimatedFare = 0;
      });
    } finally {
      if (mounted) {
        setState(() => isFareEstimateLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    seatsController.text = "4";
  }

  Future<String> reverseGeocode(LatLng point) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.openrouteservice.org/geocode/reverse?api_key=$openRouteServiceApiKey&point.lon=${point.longitude}&point.lat=${point.latitude}&size=1',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          return data['features'][0]['properties']['label'] ??
              'Unknown location';
        }
      }
    } catch (e) {
      print('Reverse geocoding error: $e');
    }
    return '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
  }

  Future<void> fetchRealRoute() async {
    if (startLocation == null || endLocation == null) return;

    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$openRouteServiceApiKey&start=${startLocation!.longitude},${startLocation!.latitude}&end=${endLocation!.longitude},${endLocation!.latitude}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] == null || (data['features'] as List).isEmpty) {
          if (!mounted) return;
          setState(() {
            routePoints = [];
            routeDistanceKm = 0;
            routeDurationMin = 0;
            minEstimatedFare = 0;
            maxEstimatedFare = 0;
          });
          return;
        }
        final coordinates = data['features'][0]['geometry']['coordinates'];
        final summary = data['features'][0]['properties']['summary'];

        setState(() {
          routePoints = coordinates
              .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
              .toList();
          routeDistanceKm = summary['distance'] / 1000;
          routeDurationMin = summary['duration'] / 60;
        });
        await _fetchFareEstimatesFromBackend();
      } else {
        if (!mounted) return;
        setState(() {
          routePoints = [];
          routeDistanceKm = 0;
          routeDurationMin = 0;
          minEstimatedFare = 0;
          maxEstimatedFare = 0;
        });
      }
    } catch (e) {
      print('Route fetching error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> createRide() async {
    if (startLocation == null ||
        endLocation == null ||
        selectedDepartureTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select locations and departure time'),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${backendUrl}/api/rides'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'driverId': 1, // TODO: Get from auth
          'origin': originController.text,
          'destination': destinationController.text,
          'originLat': startLocation!.latitude,
          'originLng': startLocation!.longitude,
          'destinationLat': endLocation!.latitude,
          'destinationLng': endLocation!.longitude,
          'routeDistanceKm': routeDistanceKm,
          'routeDurationMin': routeDurationMin,
          'departureTime': selectedDepartureTime!.toIso8601String(),
          'seats': int.parse(seatsController.text),
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        setState(() {
          rideId = data['ride']['id'];
          rideStatus = data['ride']['status'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride created successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create ride: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> startRide() async {
    if (rideId == null) return;

    setState(() => isLoading = true);

    try {
      final response = await http.put(
        Uri.parse('${backendUrl}/api/rides/$rideId/start'),
      );

      if (response.statusCode == 200) {
        setState(() => rideStatus = 'ONGOING');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ride started')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting ride: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> cancelRide() async {
    if (rideId == null) return;

    setState(() => isLoading = true);

    try {
      final response = await http.put(
        Uri.parse('${backendUrl}/api/rides/$rideId/cancel'),
      );

      if (response.statusCode == 200) {
        setState(() {
          rideId = null;
          rideStatus = 'NOT_CREATED';
          startLocation = null;
          endLocation = null;
          routePoints = [];
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ride cancelled')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error cancelling ride: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchBookingRequests() async {
    if (rideId == null) return;

    setState(() => isBookingLoading = true);

    try {
      final response = await http.get(
        Uri.parse('${backendUrl}/api/bookings/ride/$rideId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => bookingRequests = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      print('Error fetching bookings: $e');
    } finally {
      setState(() => isBookingLoading = false);
    }
  }

  Future<void> acceptBooking(int bookingId) async {
    try {
      final response = await http.put(
        Uri.parse('${backendUrl}/api/bookings/$bookingId/accept'),
      );

      if (response.statusCode == 200) {
        await fetchBookingRequests();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Booking accepted')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error accepting booking: $e')));
    }
  }

  Future<void> rejectBooking(int bookingId) async {
    try {
      final response = await http.put(
        Uri.parse('${backendUrl}/api/bookings/$bookingId/reject'),
      );

      if (response.statusCode == 200) {
        await fetchBookingRequests();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Booking rejected')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error rejecting booking: $e')));
    }
  }

  Future<void> selectDepartureTime() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          selectedDepartureTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
          departureController.text = selectedDepartureTime!.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color brandOrange = const Color(0xFFF98825);

    return Scaffold(
      backgroundColor: Colors.white,
            appBar: AppBar(
        backgroundColor: brandOrange,
        title: const Text(
          'Driver Panel',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>  MyRidesPageDriver(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: const LatLng(23.8103, 90.4125), // Dhaka
                  initialZoom: 12,
                  onTap: canEdit
                      ? (tapPosition, point) => handleMapTap(tapPosition, point)
                      : null,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.mashfi.cholo_app.dev',
                  ),
                  if (startLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: startLocation!,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.green,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  if (endLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: endLocation!,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  if (routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          color: Colors.blue,
                          strokeWidth: 4.0,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canEdit) ...[
                    TextField(
                      controller: originController,
                      decoration: const InputDecoration(
                        labelText: 'Origin',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: destinationController,
                      decoration: const InputDecoration(
                        labelText: 'Destination',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: departureController,
                      decoration: const InputDecoration(
                        labelText: 'Departure Time',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      onTap: selectDepartureTime,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: seatsController,
                      decoration: const InputDecoration(
                        labelText: 'Seats',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _fetchFareEstimatesFromBackend(),
                    ),
                    const SizedBox(height: 16),
                    if (routeDistanceKm != null && routeDurationMin != null)
                      Text(
                        'Distance: ${routeDistanceKm!.toStringAsFixed(1)} km, Duration: ${routeDurationMin!.toStringAsFixed(0)} min',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    if (routeDistanceKm != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Est. minimum total: $minEstimatedFare Taka',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        'Est. maximum total: $maxEstimatedFare Taka',
                        style: const TextStyle(fontSize: 13),
                      ),
                      if (isFareEstimateLoading)
                        const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                    const SizedBox(height: 16),
                    if (canShowCreate)
                      ElevatedButton(
                        onPressed: isLoading ? null : createRide,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandOrange,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Create Ride'),
                      ),
                  ],
                  if (canShowPlannedActions) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading ? null : startRide,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('Start Ride'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isLoading ? null : cancelRide,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Cancel Ride'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RideDetailsPage(
                              ride: {
                                "id": rideId,
                                "origin": originController.text,
                                "destination": destinationController.text,
                                "routeDistanceKm": routeDistanceKm,
                                "routeDurationMin": routeDurationMin,
                                "departureTime": departureController.text,
                                "seats": seatsController.text,
                                "status": rideStatus,
                              },
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text("View Ride Details"),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: fetchBookingRequests,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandOrange,
                      ),
                      child: isBookingLoading
                          ? const CircularProgressIndicator()
                          : const Text('Check Booking Requests'),
                    ),
                    if (bookingRequests.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Booking Requests:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...bookingRequests.map(
                        (request) => Card(
                          child: ListTile(
                            title: Text(request['passenger']['name']),
                            subtitle: Text('Status: ${request['status']}'),
                            trailing: request['status'] == 'PENDING'
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.check,
                                          color: Colors.green,
                                        ),
                                        onPressed: () =>
                                            acceptBooking(request['id']),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            rejectBooking(request['id']),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> handleMapTap(TapPosition tapPosition, LatLng point) async {
    if (!canEdit || isLoading) return;

    if (startLocation == null) {
      setState(() {
        startLocation = point;
        endLocation = null;
        routePoints = [];
        routeDistanceKm = null;
        routeDurationMin = null;
        minEstimatedFare = 0;
        maxEstimatedFare = 0;
        originController.text = "Loading place...";
        destinationController.clear();
      });

      final placeName = await reverseGeocode(point);

      setState(() {
        originController.text = placeName;
      });
    } else if (endLocation == null) {
      setState(() {
        endLocation = point;
        destinationController.text = "Loading place...";
      });

      final placeName = await reverseGeocode(point);

      setState(() {
        destinationController.text = placeName;
      });

      if (startLocation != null && endLocation != null) {
        await fetchRealRoute();
      }
    } else {
      setState(() {
        startLocation = point;
        endLocation = null;
        routePoints = [];
        routeDistanceKm = null;
        routeDurationMin = null;
        minEstimatedFare = 0;
        maxEstimatedFare = 0;
        originController.text = "Loading place...";
        destinationController.clear();
      });

      final placeName = await reverseGeocode(point);

      setState(() {
        originController.text = placeName;
      });
    }
  }
}
