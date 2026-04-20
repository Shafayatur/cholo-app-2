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
  bool isProcessingPayment = false;
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
      final userIdQuery =
          Session.userId != null ? "?userId=${Session.userId}" : "";
      final url =
          "$backendUrl/seat-booking/${widget.rideId}/seats$userIdQuery";

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error fetching seats: $e")));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please login first")));
      return;
    }

    if (myBookedSeats.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Booking already confirmed for this ride")));
      return;
    }

    if (selectedSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select at least one seat")));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        setState(() => selectedSeats.clear());
        await fetchSeats();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(body["error"]?.toString() ?? "Booking failed")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error booking seats: $e")));
    } finally {
      if (mounted) {
        setState(() => isConfirming = false);
      }
    }
  }

  Future<void> _showPaymentMethodChooser() async {
    if (Session.userId == null || myBookedSeats.isEmpty) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Select Payment Method",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              _paymentOption(
                icon: Icons.payments_outlined,
                label: "Cash",
                sublabel: "Pay at destination",
                color: const Color(0xFF16A34A),
                value: "cash",
              ),
              _paymentOption(
                icon: Icons.account_balance_wallet_outlined,
                label: "bKash",
                sublabel: "Mobile banking",
                color: const Color(0xFFE2136E),
                value: "bkash",
              ),
              _paymentOption(
                icon: Icons.account_balance_wallet,
                label: "Nagad",
                sublabel: "Mobile banking",
                color: const Color(0xFFF6921E),
                value: "nagad",
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await _completeRideAndPayment(selected);
    }
  }

  Widget _paymentOption({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required String value,
  }) {
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle:
          Text(sublabel, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: () => Navigator.pop(context, value),
    );
  }

  Future<void> _completeRideAndPayment(String paymentMethod) async {
    if (Session.userId == null) return;
    setState(() => isProcessingPayment = true);
    try {
      final res = await http.post(
        Uri.parse(
            "$backendUrl/seat-booking/${widget.rideId}/complete-payment"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": Session.userId,
          "paymentMethod": paymentMethod,
        }),
      );
      final body = jsonDecode(res.body);
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            "Payment via ${body["paymentMethod"]} started. Payable: ${body["payableAmount"]} Taka",
          ),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(body["error"]?.toString() ?? "Payment failed")));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Payment error: $e")));
    } finally {
      if (mounted) {
        setState(() => isProcessingPayment = false);
      }
    }
  }

  /* ─── UI BUILDERS ─── */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Your Seat"),
        backgroundColor: const Color(0xFFF98825),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFF98825).withOpacity(0.3),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : totalSeats == 0
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_seat_outlined,
                          size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text("No seats available",
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 15)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildFareCard(),
                    _buildLegend(),
                    Expanded(child: _buildBusLayout()),
                    if (myBookedSeats.isEmpty) _buildBottomBar(),
                  ],
                ),
    );
  }

  /// Fare info banner below app bar.
  Widget _buildFareCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: unitPassengerFare == null
            ? Colors.red.shade50
            : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unitPassengerFare == null
              ? Colors.red.shade200
              : const Color(0xFFFED7AA),
        ),
      ),
      child: Row(
        children: [
          Icon(
            unitPassengerFare == null
                ? Icons.error_outline
                : Icons.receipt_long_outlined,
            color: unitPassengerFare == null
                ? Colors.red.shade600
                : const Color(0xFFEA580C),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              unitPassengerFare == null
                  ? "Fare estimate unavailable — check ride distance data"
                  : selectedSeats.isEmpty
                      ? "Per seat: ${unitPassengerFare!} Taka — tap seats to select"
                      : "${selectedSeats.length} seat(s) × ${unitPassengerFare!} Taka = ${unitPassengerFare! * selectedSeats.length} Taka",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: unitPassengerFare == null
                    ? Colors.red.shade700
                    : const Color(0xFF9A3412),
              ),
            ),
          ),
          if (selectedSeats.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF98825),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${selectedSeats.length}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

    /// Colour legend row.
  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendDot(const Color(0xFFF3F4F6), "Available", border: true),
          const SizedBox(width: 14),
          _legendDot(const Color(0xFFF98825), "Selected"),
          const SizedBox(width: 14),
          _legendDot(const Color(0xFF3B82F6), "Booked"),
          if (myBookedSeats.isNotEmpty) ...[
            const SizedBox(width: 14),
            _legendDot(const Color(0xFF16A34A), "Yours"),
          ],
        ],
      ),
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
            border: border
                ? Border.all(color: Colors.grey.shade400, width: 1.2)
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Full bus-shaped seat grid with driver area, column headers, and aisle.
  Widget _buildBusLayout() {
    final rowsCount = (totalSeats / 4).ceil();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(18),
          color: Colors.grey.shade50,
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // ── Driver cabin ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade300,
                      border: Border.all(color: Colors.grey.shade400, width: 2),
                    ),
                    child: Icon(Icons.drive_eta_rounded,
                        size: 24, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Text("Driver",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500)),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Column headers ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: [
                  _colHeader("A"),
                  const SizedBox(width: 4),
                  _colHeader("B"),
                  const SizedBox(width: 20),
                  const SizedBox(
                      width: 20,
                      child: Center(
                          child: Text("",
                              style: TextStyle(fontSize: 10)))),
                  const SizedBox(width: 20),
                  _colHeader("C"),
                  const SizedBox(width: 4),
                  _colHeader("D"),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ── Seat rows ──
            ...List.generate(rowsCount, (rowIndex) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    _buildSeatTile(rowIndex * 4 + 1),
                    const SizedBox(width: 4),
                    _buildSeatTile(rowIndex * 4 + 2),
                    const SizedBox(width: 20),
                    // Aisle indicator
                    Container(
                      width: 20,
                      alignment: Alignment.center,
                      child: Container(
                        width: 2,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    _buildSeatTile(rowIndex * 4 + 3),
                    const SizedBox(width: 4),
                    _buildSeatTile(rowIndex * 4 + 4),
                  ],
                ),
              );
            }),

            // ── My booked seats banner ──
            if (myBookedSeats.isNotEmpty) _buildMyBookedBanner(),
          ],
        ),
      ),
    );
  }

  Widget _colHeader(String label) {
    return const SizedBox(
      width: 52,
      child: Center(
        child: Text(
          "",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  /// Individual seat tile with four visual states.
  Widget _buildSeatTile(int seatNo) {
    if (seatNo > totalSeats) return const SizedBox(width: 52);

    final isBooked = bookedSeats.contains(seatNo);
    final isMine = myBookedSeats.contains(seatNo);
    final isSelected = selectedSeats.contains(seatNo);
    final canTap = !isBooked && !isMine;

    Color bgColor;
    Color textColor;
    BoxBorder? border;
    List<BoxShadow>? shadow;

    if (isMine) {
      bgColor = const Color(0xFF16A34A);
      textColor = Colors.white;
    } else if (isBooked) {
      bgColor = const Color(0xFF3B82F6);
      textColor = Colors.white;
    } else if (isSelected) {
      bgColor = const Color(0xFFF98825);
      textColor = Colors.white;
      shadow = [
        BoxShadow(
          color: const Color(0xFFF98825).withOpacity(0.35),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];
    } else {
      bgColor = Colors.white;
      textColor = Colors.black87;
      border = Border.all(color: Colors.grey.shade300, width: 1.2);
    }

    return GestureDetector(
      onTap: canTap ? () => onSeatTapped(seatNo) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 52,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: border,
          boxShadow: shadow,
        ),
        child: Text(
          "$seatNo",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }

  /// Green banner shown when user already has seats booked.
  Widget _buildMyBookedBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle,
                    color: Color(0xFF16A34A), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Seats Confirmed",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF166534),
                      ),
                    ),
                    Text(
                      "Seat ${myBookedSeats.join(", ")} — locked for you",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  isProcessingPayment ? null : _showPaymentMethodChooser,
              icon: isProcessingPayment
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.credit_card, size: 18),
              label: const Text("Complete Ride & Payment",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.green.shade300,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Persistent bottom bar with fare summary and confirm button.
  Widget _buildBottomBar() {
    final canConfirm = selectedSeats.isNotEmpty && !isConfirming;
    final total = unitPassengerFare != null
        ? unitPassengerFare! * selectedSeats.length
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Summary column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedSeats.isEmpty
                        ? "No seat selected"
                        : "Seat ${selectedSeats.toList()..sort()}",
                    style: TextStyle(
                      fontSize: 12,
                      color: selectedSeats.isEmpty
                          ? Colors.grey.shade500
                          : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    total != null ? "$total Taka" : "—",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: canConfirm
                          ? const Color(0xFFF98825)
                          : Colors.grey.shade400,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Confirm button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: ElevatedButton(
                onPressed: canConfirm ? confirmBooking : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canConfirm
                      ? const Color(0xFFF98825)
                      : Colors.grey.shade200,
                  foregroundColor:
                      canConfirm ? Colors.white : Colors.grey.shade400,
                  disabledBackgroundColor: Colors.grey.shade200,
                  disabledForegroundColor: Colors.grey.shade400,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: canConfirm ? 2 : 0,
                ),
                child: isConfirming
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text("Confirm",
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}