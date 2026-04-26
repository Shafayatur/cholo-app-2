import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'session.dart';
import 'backend_config.dart';
import 'passenger_ride_details.dart';

class PassengerRidesList extends StatefulWidget {
  const PassengerRidesList({Key? key}) : super(key: key);

  @override
  State<PassengerRidesList> createState() => _PassengerRidesListState();
}

class _PassengerRidesListState extends State<PassengerRidesList> {
  List<dynamic> rides = [];
  bool isLoading = true;
  final Color brandOrange = const Color(0xFFF98825);

  @override
  void initState() {
    super.initState();
    fetchAllRides();
  }

  Future<void> fetchAllRides() async {
    setState(() => isLoading = true);
    
    try {
      // Fetch all rides (temporary - will be replaced with passenger-specific rides later)
      final response = await http.get(
        Uri.parse('$backendUrl/api/rides'),
        headers: {'Authorization': 'Bearer ${Session.userId}'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          rides = data['rides'] ?? [];
        });
      } else {
        print('Failed to fetch rides: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching rides: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('My Rides'),
        backgroundColor: brandOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchAllRides,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : rides.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_car, size: 64, color: Colors.grey.shade300.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'No rides available',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final ride = rides[index];
                    return _buildRideCard(ride);
                  },
                ),
    );
  }

  Widget _buildRideCard(dynamic ride) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PassengerRideDetails(ride: ride),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${ride['origin']} → ${ride['destination']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ride['status'] == 'ACTIVE' 
                        ? Colors.green.shade100 
                        : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ride['status'] ?? 'UNKNOWN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ride['status'] == 'ACTIVE' 
                          ? Colors.green.shade800 
                          : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    ride['departureTime']?.toString().substring(0, 16) ?? 'N/A',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${ride['routeDurationMin'] ?? '?'} min',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attach_money, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Fare: ${ride['totalFare'] ?? 0} Taka',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: brandOrange),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}