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
      if (selected == "cash") {
        await _completeRideAndPayment(paymentMethod: selected);
      } else {
        await _showMobilePaymentDialog(selected);
      }
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
      subtitle: Text(sublabel,
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing:
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: () => Navigator.pop(context, value),
    );
  }

  Future<void> _showMobilePaymentDialog(String paymentMethod) async {
    final phoneController = TextEditingController();
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(paymentMethod == "bkash" ? "bKash Payment" : "Nagad Payment"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone Number",
                  hintText: "01XXXXXXXXX",
                ),
                validator: (v) {
                  final value = (v ?? "").trim();
                  if (!RegExp(r"^\d{11}$").hasMatch(value)) {
                    return "Enter valid 11-digit phone";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "PIN (mock)",
                  hintText: "Enter 4-6 digit pin",
                ),
                validator: (v) {
                  final value = (v ?? "").trim();
                  if (value.length < 4) return "Invalid PIN";
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: const Text("Pay"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _completeRideAndPayment(
        paymentMethod: paymentMethod,
        paymentPhone: phoneController.text.trim(),
      );
    }
  }

  Future<void> _completeRideAndPayment({
    required String paymentMethod,
    String? paymentPhone,
  }) async {
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
          "paymentPhone": paymentPhone,
        }),
      );
      final body = jsonDecode(res.body);
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            "Payment complete via ${body["paymentMethod"]}. Paid: ${body["payableAmount"]} Taka",
          ),
        ));
        await fetchSeats();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(body["error"]?.toString() ?? "Payment failed")));
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
                    Expanded(child: _buildCarLayout()),
                    if (myBookedSeats.isEmpty) _buildBottomBar(),
                  ],
                ),
    );
  }

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
                      ? "Per seat: ${unitPassengerFare!} Taka — tap to select"
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

  /* ─── CAR LAYOUT ─── */

  Widget _buildCarLayout() {
    // Seat 1 is always front passenger. Rest go to back rows (max 3 per row).
    final int backSeatCount = totalSeats > 1 ? totalSeats - 1 : 0;

    // Dynamically build back rows
    List<Widget> backRowWidgets = [];
    int remaining = backSeatCount;
    int seatNo = 2; // back seats start at 2

    while (remaining > 0) {
      int inThisRow = remaining >= 3 ? 3 : remaining;
      List<Widget> seats = [];
      for (int i = 0; i < inThisRow; i++) {
        if (i > 0) seats.add(const SizedBox(width: 12));
        seats.add(_buildSeatTile(seatNo));
        seatNo++;
      }
      if (backRowWidgets.isNotEmpty) {
        backRowWidgets.add(const SizedBox(height: 14));
      }
      backRowWidgets.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: seats,
        ),
      );
      remaining -= inThisRow;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 16),
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

          // ── Car body ──
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
                // Windshield
                Container(
                  width: 120,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: const Center(
                    child: Text(
                      "FRONT",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7DD3FC),
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // ── Front row: passenger (left) + driver (right) ──
                Row(
                  children: [
                    _buildSeatTile(1),
                    const Spacer(),
                    _buildDriverTile(),
                  ],
                ),

                const SizedBox(height: 20),

                // Divider
                Container(
                  height: 1,
                  color: Colors.grey.shade200,
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "BACK",
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFBDBDBD),
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Back rows (dynamic) ──
                if (backRowWidgets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      "No back seats",
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade400),
                    ),
                  )
                else
                  Column(children: backRowWidgets),

                // My booked banner
                if (myBookedSeats.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _buildMyBookedBanner(),
                ],
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
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: stroke),
      ),
    );
  }

  /// Non-interactive driver tile.
  Widget _buildDriverTile() {
    return Container(
      width: 64,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person, size: 18, color: Colors.grey.shade500),
          const SizedBox(height: 2),
          Text(
            "Driver",
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  /// Individual seat tile with four visual states.
  Widget _buildSeatTile(int seatNo) {
    if (seatNo > totalSeats) return const SizedBox(width: 64);

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
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }

  /// Green banner when user already has seats booked.
  Widget _buildMyBookedBanner() {
    return Container(
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
            ElevatedButton(
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
          ],
        ),
      ),
    );
  }
}