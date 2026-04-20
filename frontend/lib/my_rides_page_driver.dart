import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'session.dart';
import 'backend_config.dart';
import 'ride_details_page.dart';

class MyRidesPageDriver extends StatefulWidget {
  const MyRidesPageDriver({Key? key}) : super(key: key);

  @override
  State<MyRidesPageDriver> createState() => _MyRidesPageDriverState();
}

class _MyRidesPageDriverState extends State<MyRidesPageDriver> {
  List rides = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMyRides();
  }

  Future<void> fetchMyRides() async {
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/api/rides/driver/${Session.userId}'),
      );

      final data = jsonDecode(res.body);

      setState(() {
        rides = data;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching rides: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("My Rides"),
        backgroundColor: const Color(0xFFF98825),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : rides.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.drive_eta_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        "No rides created yet",
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final ride = rides[index];
                    return _buildRideCard(ride);
                  },
                ),
    );
  }

  /// Custom styled card for each ride to match RideDetailsPage aesthetics
  Widget _buildRideCard(Map<String, dynamic> ride) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RideDetailsPage(ride: ride),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Top Row: Route and Status Badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "${ride['origin']} → ${ride['destination']}",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(ride['status']?.toString() ?? 'UNKNOWN'),
                  ],
                ),
                
                const SizedBox(height: 14),
                
                // Bottom Row: Meta info and Arrow
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, 
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      ride['departureTime'] ?? 'N/A',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.straighten, 
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      "${ride['routeDistanceKm'] ?? '?'} km",
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded, 
                        size: 16, color: Colors.grey.shade400),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Reusable status badge matching the detail page
  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    if (status == 'ACTIVE') {
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
    } else if (status == 'COMPLETED') {
      bgColor = Colors.blue.shade100;
      textColor = Colors.blue.shade800;
    } else if (status == 'CANCELLED') {
      bgColor = Colors.red.shade100;
      textColor = Colors.red.shade800;
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
      child: Text(
        status,
        style: TextStyle(
            color: textColor, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}