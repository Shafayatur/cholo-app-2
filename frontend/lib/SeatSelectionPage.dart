import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'session.dart';
import 'backend_config.dart';

class SeatSelectionPage extends StatefulWidget {
  final int rideId;

  const SeatSelectionPage({Key? key, required this.rideId}) : super(key: key);

  @override
  State<SeatSelectionPage> createState() => _SeatSelectionPageState();
}

class _SeatSelectionPageState extends State<SeatSelectionPage> {
  final Set<int> selectedSeats = {};
  int totalSeats = 0;
  List<int> bookedSeats = [];
  List<int> myBookedSeats = [];
  bool isLoading = false;
  bool isConfirming = false;
  int? unitPassengerFare;

  @override
  void initState() {
    super.initState();
    fetchSeats();
  }

  Future<void> fetchSeats() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final userIdQuery = Session.userId != null
          ? "?userId=${Session.userId}"
          : "";
      final url = "$backendUrl/seat-booking/${widget.rideId}/seats$userIdQuery";

      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);

      final u = data["unitPassengerFare"];
      setState(() {
        totalSeats = data["totalSeats"];
        bookedSeats = List<int>.from(data["bookedSeats"]);
        myBookedSeats = List<int>.from(data["myBookedSeats"] ?? []);
        selectedSeats.removeWhere((seat) => bookedSeats.contains(seat));
        unitPassengerFare = u == null
            ? null
            : (u is num ? u.ceil() : int.tryParse(u.toString()));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error fetching seats: $e")));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void onSeatTapped(int seatNo) {
    if (bookedSeats.contains(seatNo) || myBookedSeats.isNotEmpty) return;
    setState(() {
      if (selectedSeats.contains(seatNo)) {
        selectedSeats.remove(seatNo);
      } else {
        selectedSeats.add(seatNo);
      }
    });
  }

  Future<void> confirmBooking() async {
    if (Session.userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please login first")));
      return;
    }

    if (myBookedSeats.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Booking already confirmed for this ride"),
        ),
      );
      return;
    }

    if (selectedSeats.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select at least one seat")));
      return;
    }

    setState(() => isConfirming = true);
    try {
      final res = await http.post(
        Uri.parse("$backendUrl/seat-booking"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "rideId": widget.rideId,
          "userId": Session.userId,
          "seats": selectedSeats.toList()..sort(),
        }),
      );

      final body = jsonDecode(res.body);

      if (res.statusCode == 201) {
        final bookedNow = List<int>.from(body["seats"] ?? []);
        final paid = body["bookingTotal"];
        final paidInt = paid == null
            ? null
            : (paid is num ? paid.ceil() : int.tryParse(paid.toString()));
        final msg = paid != null
            ? "Seats ${bookedNow.join(", ")} booked — $paidInt Taka total"
            : "Seats ${bookedNow.join(", ")} booked";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );

        setState(() {
          selectedSeats.clear();
        });

        await fetchSeats();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body["error"]?.toString() ?? "Booking failed"),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error booking seats: $e")));
    } finally {
      if (mounted) {
        setState(() => isConfirming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Seat"),
        backgroundColor: const Color(0xFFF98825),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),

          Text(
            "Ride ID: ${widget.rideId}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              unitPassengerFare == null
                  ? "Fare estimate unavailable (check ride distance data)."
                  : selectedSeats.isEmpty
                  ? "Per-seat fare (full route for now): ${unitPassengerFare!} Taka — select seats"
                  : "Estimated payable: ${unitPassengerFare! * selectedSeats.length} Taka (${selectedSeats.length} × $unitPassengerFare)",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: unitPassengerFare == null ? Colors.red.shade700 : Colors.black87,
              ),
            ),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _SeatLegend(color: Color(0xFFE5E7EB), label: "Available"),
                SizedBox(width: 10),
                _SeatLegend(color: Color(0xFFF98825), label: "Selected"),
                SizedBox(width: 10),
                _SeatLegend(color: Color(0xFF3B82F6), label: "Booked"),
              ],
            ),
          ),

          if (myBookedSeats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                "Booked by you: ${myBookedSeats.join(", ")} (locked)",
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : totalSeats == 0
                ? const Center(child: Text("No seats available"))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      final isBooked = bookedSeats.contains(seatNo);
                      final isSelected = selectedSeats.contains(seatNo);

                      Color color;
                      if (isBooked) {
                        color = const Color(0xFF3B82F6);
                      } else if (isSelected) {
                        color = const Color(0xFFF98825);
                      } else {
                        color = const Color(0xFFE5E7EB);
                      }

                      return GestureDetector(
                        onTap: () => onSeatTapped(seatNo),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "$seatNo",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isBooked || isSelected
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed:
                  (selectedSeats.isEmpty ||
                      myBookedSeats.isNotEmpty ||
                      isConfirming)
                  ? null
                  : confirmBooking,
              child: isConfirming
                  ? const CircularProgressIndicator()
                  : const Text("Confirm Booking"),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _SeatLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
