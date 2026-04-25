import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'backend_config.dart';
import 'session.dart';

import 'package:intl/intl.dart';

class DateFormatters {
  static String rideTime(dynamic value) {
    try {
      return DateFormat('h:mm a, dd-MM-yyyy')
          .format(DateTime.parse(value.toString()));
    } catch (_) {
      return "N/A";
    }
  }
}

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
  int gotTotalMoney = 0;
  List<Map<String, dynamic>> paidBreakdown = [];
  Timer? _seatPoll;
  
  // New variables for passengers list
  List<Map<String, dynamic>> passengers = [];
  bool isLoadingPassengers = false;

  int? get rideId => widget.ride["id"] is int
      ? widget.ride["id"] as int
      : int.tryParse(widget.ride["id"].toString());

  @override
  void initState() {
    super.initState();
    fetchSeatStatus().then((_) {
      fetchPassengers();
    });
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
        final gm = data["gotTotalMoney"];
        if (gm != null) {
          gotTotalMoney = gm is num ? gm.ceil() : int.tryParse(gm.toString()) ?? 0;
        }
        paidBreakdown = List<Map<String, dynamic>>.from(data["paidBreakdown"] ?? []);
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

  Future<void> fetchPassengers() async {
    if (rideId == null) return;
    
    setState(() {
      isLoadingPassengers = true;
    });
    
    try {
      // Extract passengers directly from seats data
      List<Map<String, dynamic>> extractedPassengers = [];
      
      for (var seat in seats) {
        // Check if seat is booked and has passenger
        final isBooked = seat["state"] == "BOOKED" || seat["state"] == "BOOKED_BY_ME";
        final passenger = seat["passenger"];
        
        if (isBooked && passenger != null) {
          // Avoid duplicate passengers (same person booking multiple seats)
          bool exists = extractedPassengers.any((p) => p['id'] == passenger['id']);
          
          if (!exists) {
            extractedPassengers.add({
              'id': passenger['id'],
              'name': passenger['name'] ?? 'Unknown',
              'email': passenger['email'] ?? 'No email',
              'seatNo': seat['seatNo'],
              'fare': seat['fare'] ?? 0,
              'paymentStatus': 'PENDING', // Default status
              'bookingStatus': 'CONFIRMED',
            });
          }
        }
      }
      
      setState(() {
        passengers = extractedPassengers;
      });
      
      print("✅ Loaded ${extractedPassengers.length} passengers from seats");
      
    } catch (e) {
      print("Error extracting passengers: $e");
    } finally {
      setState(() {
        isLoadingPassengers = false;
      });
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
        backgroundColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
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
                Row(
                  children: [
                    Expanded(
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
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showComplaintDialog(passenger);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("File Complaint",
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
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

  // Simple complaint dialog (no external file needed)
  void _showComplaintDialog(Map<String, dynamic> passenger) {
    final TextEditingController complaintController = TextEditingController();
    String severity = 'MEDIUM';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('File Complaint against ${passenger['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: severity,
                decoration: const InputDecoration(labelText: 'Severity'),
                items: const [
                  DropdownMenuItem(value: 'LOW', child: Text('Low')),
                  DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                  DropdownMenuItem(value: 'HIGH', child: Text('High')),
                ],
                onChanged: (value) {
                  severity = value!;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: complaintController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Complaint Details',
                  hintText: 'Describe the issue...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement complaint submission to backend
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Complaint submitted (demo)')),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

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
              onPressed: () => fetchSeatStatus(),
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
            const SizedBox(height: 24),
            _buildPassengersSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengersSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF98825).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.people_outline, color: const Color(0xFFF98825)),
                const SizedBox(width: 8),
                Text(
                  "Passengers List",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF98825),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF98825).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    passengers.length.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFF98825),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (isLoadingPassengers)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (passengers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.person_off_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      "No passengers have booked this ride yet",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: passengers.length,
              separatorBuilder: (context, index) => Divider(
                height: 0,
                color: Colors.grey.shade200,
                thickness: 1,
              ),
              itemBuilder: (context, index) {
                final passenger = passengers[index];
                return _buildPassengerTile(passenger);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPassengerTile(Map<String, dynamic> passenger) {
    final bool hasPaid = passenger['paymentStatus'] == 'PAID';
    final String bookingStatus = passenger['bookingStatus'] ?? 'CONFIRMED';
    
    return InkWell(
      onTap: () => _showPassengerDetailsDialog(passenger),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF98825).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  passenger['name'][0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFF98825),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        passenger['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (hasPaid)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Paid',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (!hasPaid && bookingStatus == 'CONFIRMED')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Pending',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        passenger['phone'] ?? 'N/A',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          passenger['pickupPoint'] ?? 'N/A',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Container(
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: () => _showComplaintDialog(passenger),
                icon: Icon(Icons.report_problem_outlined, color: Colors.red.shade700, size: 20),
                tooltip: 'File Complaint',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPassengerDetailsDialog(Map<String, dynamic> passenger) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF98825).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          passenger['name'][0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF98825),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            passenger['name'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            passenger['email'] ?? 'No email provided',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                _buildPassengerDetailRow(Icons.phone, 'Phone', passenger['phone'] ?? 'N/A'),
                _buildPassengerDetailRow(Icons.location_on, 'Pickup Point', passenger['pickupPoint'] ?? 'N/A'),
                _buildPassengerDetailRow(Icons.attach_money, 'Payment Status', passenger['paymentStatus'] ?? 'PENDING'),
                _buildPassengerDetailRow(Icons.confirmation_number, 'Booking Status', passenger['bookingStatus'] ?? 'PENDING'),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showComplaintDialog(passenger);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('File Complaint'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPassengerDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ... (keep all your existing UI methods: _buildRouteInfoCard, _routePoint, _statusBadge, _infoChip, _buildEarningsCard, _showGotMoneyBreakdown, _buildLegend, _legendDot, _buildCarLayout, _lightDot, _buildDriverTile, _buildSeatTile)
  
  // I'll include the rest of your existing methods here...
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
              _infoChip(
                Icons.route,
                "${(widget.ride['routeDistanceKm'] is num
                    ? (widget.ride['routeDistanceKm'] as num).toDouble()
                    : double.tryParse(widget.ride['routeDistanceKm'].toString()) ?? 0)
                    .toStringAsFixed(2)} km   ",
              ),
              _infoChip(
                Icons.schedule,
                "${(widget.ride['routeDurationMin'] is num
                    ? (widget.ride['routeDurationMin'] as num).toDouble()
                    : double.tryParse(widget.ride['routeDurationMin'].toString()) ?? 0)
                    .toStringAsFixed(2)} min   ",
              ),
              _infoChip(Icons.event, DateFormatters.rideTime(widget.ride['departureTime'])),
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

    return GestureDetector(
      onTap: _showGotMoneyBreakdown,
      child: Container(
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
                const SizedBox(height: 4),
                Text("Got money: $gotTotalMoney Taka",
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
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
      ),
    );
  }

  void _showGotMoneyBreakdown() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Collected Payments"),
        content: paidBreakdown.isEmpty
            ? const Text("No completed payments yet.")
            : SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: paidBreakdown.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (_, i) {
                    final item = paidBreakdown[i];
                    final name = item["passengerName"]?.toString() ?? "Passenger";
                    final amount = item["amount"] is num
                        ? (item["amount"] as num).toInt()
                        : int.tryParse(item["amount"]?.toString() ?? "0") ?? 0;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text("$amount Tk"),
                      ],
                    );
                  },
                ),
              ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
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
            border: border ? Border.all(color: Colors.grey.shade400, width: 1.2) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500)),
      ],
    );
  }

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _lightDot(const Color(0xFFFDE68A), const Color(0xFFFBBF24)),
              _lightDot(const Color(0xFFFDE68A), const Color(0xFFFBBF24)),
            ],
          ),
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

    final isBooked = seatData["state"] == "BOOKED" || seatData["state"] == "BOOKED_BY_ME";

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