import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'session.dart';
import 'backend_config.dart';

class PassengerRideDetails extends StatefulWidget {
  final dynamic ride;

  const PassengerRideDetails({Key? key, required this.ride}) : super(key: key);

  @override
  State<PassengerRideDetails> createState() => _PassengerRideDetailsState();
}

class _PassengerRideDetailsState extends State<PassengerRideDetails> {
  List<dynamic> fellowPassengers = [];
  dynamic driver;
  bool isLoading = true;
  String? mySeatNumber;
  
  final Color brandOrange = const Color(0xFFF98825);

  @override
  void initState() {
    super.initState();
    fetchRideDetails();
  }

  Future<void> fetchRideDetails() async {
    setState(() => isLoading = true);
    
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/seat-booking/${widget.ride['id']}/seats'),
        headers: {'Authorization': 'Bearer ${Session.userId}'},
      );
      
      print('Fetch ride details status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        List<dynamic> allPassengers = [];
        String? mySeat;
        
        for (var seat in data['seats']) {
          if (seat['passenger'] != null && seat['state'] != 'AVAILABLE') {
            final passenger = seat['passenger'];
            final isMe = passenger['id'] == Session.userId;
            
            if (isMe) {
              mySeat = seat['seatNo'].toString();
            } else {
              allPassengers.add({
                'id': passenger['id'],
                'name': passenger['name'],
                'email': passenger['email'],
                'seatNo': seat['seatNo'],
                'fare': seat['fare'],
              });
            }
          }
        }
        
        final driverData = {
          'id': widget.ride['driverId'],
          'name': widget.ride['driver']?['name'] ?? 'Driver',
          'email': widget.ride['driver']?['email'] ?? 'N/A',
        };
        
        setState(() {
          fellowPassengers = allPassengers;
          driver = driverData;
          mySeatNumber = mySeat;
          isLoading = false;
        });
        
        print('Found ${fellowPassengers.length} fellow passengers');
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching ride details: $e');
      setState(() => isLoading = false);
    }
  }

  // Simple complaint dialog without complex StatefulBuilder
  void _showComplaintDialog({int? passengerId, String? passengerName, int? seatNo}) {
    final TextEditingController complaintController = TextEditingController();
    String complaintType = passengerId != null ? 'PASSENGER' : 'DRIVER';
    String severity = 'MEDIUM';
    bool isSubmitting = false;
    
    // If passenger is specified, we're complaining against passenger
    final targetPassengerId = passengerId;
    final targetPassengerName = passengerName;
    
    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            complaintType == 'PASSENGER' 
              ? 'Report Passenger: $targetPassengerName'
              : 'Report Driver'
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Severity Selection
                const Text(
                  'Severity',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSeverityChip('LOW', 'Low', severity, (value) {
                        severity = value;
                        (dialogContext as Element).markNeedsBuild();
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSeverityChip('MEDIUM', 'Medium', severity, (value) {
                        severity = value;
                        (dialogContext as Element).markNeedsBuild();
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSeverityChip('HIGH', 'High', severity, (value) {
                        severity = value;
                        (dialogContext as Element).markNeedsBuild();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Description
                const Text(
                  'Describe the issue',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: complaintController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Please describe what happened...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (complaintController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please describe the issue')),
                        );
                        return;
                      }
                      
                      setState(() => isSubmitting = true);
                      Navigator.pop(dialogContext); // Close dialog
                      
                      await _submitComplaint(
                        type: complaintType,
                        accusedId: complaintType == 'PASSENGER' ? targetPassengerId : widget.ride['driverId'],
                        description: complaintController.text,
                        severity: severity,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit'),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildSeverityChip(String value, String label, String selectedValue, Function(String) onSelected) {
    return FilterChip(
      label: Text(label),
      selected: selectedValue == value,
      onSelected: (selected) {
        if (selected) onSelected(value);
      },
      backgroundColor: Colors.grey.shade200,
      selectedColor: value == 'LOW' 
          ? Colors.green.shade200
          : value == 'MEDIUM' 
              ? Colors.orange.shade200
              : Colors.red.shade200,
    );
  }

  Future<void> _submitComplaint({
    required String type,
    required int? accusedId,
    required String description,
    required String severity,
  }) async {
    try {
      final endpoint = type == 'PASSENGER'
          ? '$backendUrl/api/complaints/passenger-to-passenger'
          : '$backendUrl/api/complaints/passenger-to-driver';
      
      final body = type == 'PASSENGER'
          ? {
              'complainantId': Session.userId,
              'accusedId': accusedId,
              'rideId': widget.ride['id'],
              'description': description,
              'severity': severity,
            }
          : {
              'passengerId': Session.userId,
              'driverId': accusedId,
              'rideId': widget.ride['id'],
              'description': description,
              'severity': severity,
            };
      
      print('Submitting complaint to: $endpoint');
      print('Body: $body');
      
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Session.userId}',
        },
        body: jsonEncode(body),
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complaint filed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final error = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error['error'] ?? 'Failed to file complaint')),
          );
        }
      }
    } catch (e) {
      print('Error filing complaint: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Ride Details'),
        backgroundColor: brandOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ride Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.ride['origin']} → ${widget.ride['destination']}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _infoRow(Icons.calendar_today, 'Date', widget.ride['departureTime']?.toString().substring(0, 10) ?? 'N/A'),
                          _infoRow(Icons.access_time, 'Time', widget.ride['departureTime']?.toString().substring(11, 16) ?? 'N/A'),
                          _infoRow(Icons.route, 'Distance', '${widget.ride['routeDistanceKm'] ?? '?'} km'),
                          _infoRow(Icons.timer, 'Duration', '${widget.ride['routeDurationMin'] ?? '?'} min'),
                          _infoRow(Icons.attach_money, 'Fare', '${widget.ride['totalFare'] ?? '?'} Taka'),
                          if (mySeatNumber != null)
                            _infoRow(Icons.event_seat, 'Your Seat', 'Seat $mySeatNumber'),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Driver Info Card with Report Button
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Driver Information',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _infoRow(Icons.person, 'Name', driver?['name'] ?? 'N/A'),
                          _infoRow(Icons.email, 'Email', driver?['email'] ?? 'N/A'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _showComplaintDialog(),
                            icon: const Icon(Icons.report_problem_outlined, size: 16),
                                label: const Text('Report'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Fellow Passengers Card
                  if (fellowPassengers.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fellow Passengers',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...fellowPassengers.map((passenger) => ListTile(
                              leading: CircleAvatar(
                                backgroundColor: brandOrange.withOpacity(0.1),
                                child: Text(
                                  passenger['name'][0].toUpperCase(),
                                  style: TextStyle(color: brandOrange),
                                ),
                              ),
                              title: Text(passenger['name']),
                              subtitle: Text('Seat ${passenger['seatNo']}'),
                              trailing: OutlinedButton.icon(
                                onPressed: () => _showComplaintDialog(
                                  passengerId: passenger['id'],
                                  passengerName: passenger['name'],
                                  seatNo: passenger['seatNo'],
                                ),
                                icon: const Icon(Icons.report_problem_outlined, size: 16),
                                label: const Text('Report'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                ),
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
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
}