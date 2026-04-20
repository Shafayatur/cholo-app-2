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
          totalFare =
              tf is num ? tf.ceil() : int.tryParse(tf.toString()) ?? 0;
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

    final seatFare = seatData["fare"] != null
        ? (seatData["fare"] is num
            ? (seatData["fare"] as num).toDouble()
            : double.tryParse(seatData["fare"].toString()) ?? 0)
        : 0.0;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent, // <-- moved here
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            // Wrap in a Container for the white background & shape
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person, color: Color(0xFF3B82F6)),
                ),
                const SizedBox(height: 12),
                Text(
                  "Seat ${seatData["seatNo"]} Passenger",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Divider(height: 24),

                // Details
                _buildDetailRow("Name", passenger["name"] ?? "N/A"),
                _buildDetailRow("Email", passenger["email"] ?? "N/A"),
                _buildDetailRow("Passenger ID", passenger["id"]?.toString() ?? "N/A"),
                
                if (seatFare > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.monetization_on_outlined, 
                            color: Color(0xFF16A34A), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Fare: ${seatFare.toStringAsFixed(2)} Taka",
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF166534),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Close",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              title,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  /* ─── UI BUILDERS ─── */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Ride Dashboard"),
        backgroundColor: const Color(0xFFF98825),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          else
            IconButton(
              onPressed: fetchSeatStatus,
              icon: const Icon(Icons.refresh),
              tooltip: "Refresh Seats",
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRouteInfoCard(),
            const SizedBox(height: 12),
            _buildEarningsCard(),
            const SizedBox(height: 20),
            _buildLegend(),
            const SizedBox(height: 8),
            if (totalSeats == 0 && !isLoading)
              const Text("No seat data found",
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))
            else
              _buildCarLayout(),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Ride #${widget.ride['id']}",
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
              _statusBadge(widget.ride['status']?.toString() ?? 'UNKNOWN'),
            ],
          ),
          const SizedBox(height: 16),
          _routePoint(widget.ride['origin'] ?? 'N/A', true),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              children: [
                Container(width: 2, height: 20, color: const Color(0xFFF98825)),
                Icon(Icons.keyboard_arrow_down_rounded, color: const Color(0xFFF98825), size: 16),
                Container(width: 2, height: 20, color: const Color(0xFFF98825)),
              ],
            ),
          ),
          _routePoint(widget.ride['destination'] ?? 'N/A', false),
          const Divider(height: 24),
          Row(
            children: [
              _infoChip(Icons.route, "${widget.ride['routeDistanceKm']} km"),
              const SizedBox(width: 12),
              _infoChip(
                Icons.schedule,
                "${(widget.ride['routeDurationMin'] is num
                    ? (widget.ride['routeDurationMin'] as num).toDouble()
                    : double.tryParse(widget.ride['routeDurationMin'].toString()) ?? 0)
                    .toStringAsFixed(2)} min   ",
              ),
              _infoChip(Icons.event, widget.ride['departureTime'] ?? 'N/A'),
            ],
          )
        ],
      ),
    );
  }

  Widget _routePoint(String text, bool isOrigin) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOrigin ? const Color(0xFF16A34A) : const Color(0xFFF98825),
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color bgColor;
    Color textColor;
    if (status == 'ACTIVE') {
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
    } else if (status == 'COMPLETED') {
      bgColor = Colors.blue.shade100;
      textColor = Colors.blue.shade800;
    } else {
      bgColor = Colors.grey.shade200;
      textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: TextStyle(
              color: textColor, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildEarningsCard() {
    final bookedCount = seats.where((s) => 
        s["state"] == "BOOKED" || s["state"] == "BOOKED_BY_ME").length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFF98825), const Color(0xFFE67E22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF98825).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Estimated Earnings",
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text("$totalFare Taka",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text("$bookedCount/${widget.ride['seats']} Booked",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          )
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(const Color(0xFFF3F4F6), "Available", border: true),
        const SizedBox(width: 14),
        _legendDot(const Color(0xFF3B82F6), "Booked"),
        const SizedBox(width: 14),
        const Text("Tap booked seats for info",
            style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _legendDot(Color color, String label, {bool border = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border:
                border ? Border.all(color: Colors.grey.shade400, width: 1.2) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500)),
      ],
    );
  }

  /* ─── CAR LAYOUT (DRIVER VIEW) ─── */

  Widget _buildCarLayout() {
    int backSeatCount = totalSeats > 1 ? totalSeats - 1 : 0;

    List<Widget> backRowWidgets = [];
    int remaining = backSeatCount;
    int seatNo = 2;

    while (remaining > 0) {
      int inThisRow = remaining >= 3 ? 3 : remaining;
      List<Widget> rowSeats = [];
      for (int i = 0; i < inThisRow; i++) {
        if (i > 0) rowSeats.add(const SizedBox(width: 12));
        rowSeats.add(_buildSeatTile(seatNo));
        seatNo++;
      }
      if (backRowWidgets.isNotEmpty) {
        backRowWidgets.add(const SizedBox(height: 14));
      }
      backRowWidgets.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: rowSeats,
        ),
      );
      remaining -= inThisRow;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Headlights
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _lightDot(const Color(0xFFFDE68A), const Color(0xFFFBBF24)),
              _lightDot(const Color(0xFFFDE68A), const Color(0xFFFBBF24)),
            ],
          ),

          // Car body
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFDFE),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 120,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: const Center(
                    child: Text("FRONT",
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7DD3FC),
                            letterSpacing: 3)),
                  ),
                ),
                const SizedBox(height: 22),

                // Front Row
                Row(
                  children: [
                    if (totalSeats >= 1) _buildSeatTile(1),
                    if (totalSeats >= 1) const Spacer(),
                    _buildDriverTile(),
                  ],
                ),

                if (backSeatCount > 0) ...[
                  const SizedBox(height: 20),
                  Container(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text("BACK",
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFBDBDBD),
                            letterSpacing: 2)),
                  ),
                  const SizedBox(height: 12),
                  Column(children: backRowWidgets),
                ]
              ],
            ),
          ),

          // Tail lights
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _lightDot(const Color(0xFFFECACA), const Color(0xFFFCA5A5)),
              _lightDot(const Color(0xFFFECACA), const Color(0xFFFCA5A5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lightDot(Color fill, Color stroke) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
          color: fill, shape: BoxShape.circle, border: Border.all(color: stroke)),
    );
  }

  Widget _buildDriverTile() {
    return Container(
      width: 64,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF98825).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF98825).withOpacity(0.3)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.drive_eta_rounded, size: 18, color: Color(0xFFF98825)),
          SizedBox(height: 2),
          Text("You",
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFF98825))),
        ],
      ),
    );
  }

  Widget _buildSeatTile(int seatNo) {
    final seatData = seats.firstWhere(
      (s) => s["seatNo"] == seatNo,
      orElse: () => {"seatNo": seatNo, "state": "AVAILABLE", "passenger": null},
    );

    final isBooked =
        seatData["state"] == "BOOKED" || seatData["state"] == "BOOKED_BY_ME";

    Color bgColor;
    Color textColor;
    BoxBorder? border;
    List<BoxShadow>? shadow;

    if (isBooked) {
      bgColor = const Color(0xFF3B82F6);
      textColor = Colors.white;
      shadow = [
        BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3)),
      ];
    } else {
      bgColor = Colors.white;
      textColor = Colors.grey.shade500;
      border = Border.all(color: Colors.grey.shade300, width: 1.2);
    }

    return GestureDetector(
      onTap: isBooked ? () => showPassengerDetails(seatData) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 64,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: border,
          boxShadow: shadow,
        ),
        child: Text(
          "$seatNo",
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
        ),
      ),
    );
  }
}