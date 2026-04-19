import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'backend_config.dart';

class RideDetailsPage extends StatefulWidget {
  final Map<String, dynamic> ride;

  const RideDetailsPage({Key? key, required this.ride}) : super(key: key);

  @override
  State<RideDetailsPage> createState() => _RideDetailsPageState();
}

class _RideDetailsPageState extends State<RideDetailsPage> {
  bool isLoading = false;
  int totalSeats = 0;
  List<Map<String, dynamic>> seats = [];
  int totalFare = 0;
  Timer? _seatPoll;

  int? get rideId => widget.ride["id"] is int
      ? widget.ride["id"] as int
      : int.tryParse(widget.ride["id"].toString());

  @override
  void initState() {
    super.initState();
    fetchSeatStatus();
    _seatPoll = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) fetchSeatStatus(silent: true);
    });
  }

  @override
  void dispose() {
    _seatPoll?.cancel();
    super.dispose();
  }

  Future<void> fetchSeatStatus({bool silent = false}) async {
    if (rideId == null) return;
    if (!silent) setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("$backendUrl/seat-booking/$rideId/seats"),
      );
      final data = jsonDecode(response.body);
      setState(() {
        totalSeats = data["totalSeats"] ?? 0;
        seats = List<Map<String, dynamic>>.from(data["seats"] ?? []);
        final tf = data["totalFare"];
        if (tf != null) {
          totalFare = tf is num ? tf.ceil() : int.tryParse(tf.toString()) ?? 0;
        }
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load seat status: $e")),
        );
      }
    } finally {
      if (mounted && !silent) setState(() => isLoading = false);
    }
  }

  void showPassengerDetails(Map<String, dynamic> seatData) {
    final passenger = seatData["passenger"];
    if (passenger == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Seat ${seatData["seatNo"]} Passenger"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Name: ${passenger["name"] ?? "N/A"}"),
            Text("Email: ${passenger["email"] ?? "N/A"}"),
            Text("Passenger ID: ${passenger["id"] ?? "N/A"}"),
            if (seatData["fare"] != null)
              Text(
                "Seat fare: ${(seatData["fare"] is num ? (seatData["fare"] as num).toDouble() : double.tryParse(seatData["fare"].toString()) ?? 0).toStringAsFixed(2)} Taka",
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ride Details"),
        backgroundColor: const Color(0xFFF98825),
        actions: [
          IconButton(
            onPressed: fetchSeatStatus,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Ride ID: ${widget.ride['id']}"),
                const SizedBox(height: 10),
                Text("Origin: ${widget.ride['origin']}"),
                Text("Destination: ${widget.ride['destination']}"),
                const SizedBox(height: 10),
                Text("Distance: ${widget.ride['routeDistanceKm']} km"),
                Text("Duration: ${widget.ride['routeDurationMin']} min"),
                const SizedBox(height: 10),
                Text("Departure: ${widget.ride['departureTime']}"),
                Text("Seats: ${widget.ride['seats']}"),
                const SizedBox(height: 10),
                Text("Status: ${widget.ride['status']}"),
                const SizedBox(height: 20),
                Text(
                  "Seat Status",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (totalSeats == 0)
                  const Text("No seat data found")
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: totalSeats,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                    itemBuilder: (_, index) {
                      final seatNo = index + 1;
                      final seatData = seats.firstWhere(
                        (seat) => seat["seatNo"] == seatNo,
                        orElse: () => {
                          "seatNo": seatNo,
                          "state": "AVAILABLE",
                          "passenger": null,
                        },
                      );
                      final isBooked =
                          seatData["state"] == "BOOKED" ||
                          seatData["state"] == "BOOKED_BY_ME";

                      return GestureDetector(
                        onTap: isBooked
                            ? () => showPassengerDetails(seatData)
                            : null,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isBooked
                                ? Colors.blue
                                : Colors.green.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "$seatNo",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),
                Text(
                  "Total Fare: $totalFare Taka",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
