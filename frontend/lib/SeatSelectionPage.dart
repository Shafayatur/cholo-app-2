import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session.dart';

import 'src/backend_config_io.dart'
    if (dart.library.html) 'src/backend_config_web.dart';

class SeatSelectionPage extends StatefulWidget {
  final int rideId;

  const SeatSelectionPage({Key? key, required this.rideId}) : super(key: key);

  @override
  State<SeatSelectionPage> createState() => _SeatSelectionPageState();
}

class _SeatSelectionPageState extends State<SeatSelectionPage> {
  int? selectedSeat;

  int totalSeats = 0;
  List<int> bookedSeats = [];

  @override
  void initState() {
    super.initState();
    fetchSeats();
  }

  Future<void> fetchSeats() async {
    try {
      final url = "${backendUrlImpl()}/seat-booking/${widget.rideId}/seats";
      print("Calling: $url");

      final res = await http.get(Uri.parse(url));

      print("Status: ${res.statusCode}");
      print("Body: ${res.body}");

      final data = jsonDecode(res.body);

      setState(() {
        totalSeats = data["totalSeats"];
        bookedSeats = List<int>.from(data["bookedSeats"]);
      });
    } catch (e) {
      print("Error fetching seats: $e");
    }
  }

  Future<void> bookSeat() async {
    try {
      final res = await http.post(
        Uri.parse("${backendUrlImpl()}/seat-booking"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "rideId": widget.rideId,
          "userId": Session.userId, // temporary (replace later with auth user)
          "seatNo": selectedSeat,
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Seat $selectedSeat booked")));

        setState(() {
          selectedSeat = null;
        });

        fetchSeats(); // refresh seat map
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Booking failed")));
      }
    } catch (e) {
      print("Error booking seat: $e");
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: Center(
              child: totalSeats == 0
                  ? const CircularProgressIndicator()
                  : Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: List.generate(totalSeats, (index) {
                        int seatNo = index + 1;

                        bool isBooked = bookedSeats.contains(seatNo);
                        bool isSelected = selectedSeat == seatNo;

                        return GestureDetector(
                          onTap: isBooked
                              ? null
                              : () {
                                  setState(() {
                                    selectedSeat = seatNo;
                                  });
                                },
                          child: Container(
                            width: 60,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isBooked
                                  ? Colors.blue
                                  : isSelected
                                  ? Colors.orange
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "$seatNo",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF98825),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: selectedSeat == null ? null : bookSeat,
              child: const Text("Confirm Booking"),
            ),
          ),
        ],
      ),
    );
  }
}
