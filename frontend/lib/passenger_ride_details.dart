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
  int? totalSeats;

  final Color brandOrange = const Color(0xFFF98825);

  // For delayed reporting
  int? _selectedSeatForReport;
  DateTimeRange? _selectedTimeRange;
  String _reportDescription = '';
  String _severity = 'MEDIUM';
  bool _isSubmitting = false;

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

        List<dynamic> activePassengers = [];
        String? mySeat;
        int seats = data['totalSeats'] ?? 0;

        for (var seat in data['seats']) {
          if (seat['passenger'] != null && seat['state'] != 'AVAILABLE') {
            final passenger = seat['passenger'];
            final isMe = passenger['id'] == Session.userId;

            if (isMe) {
              mySeat = seat['seatNo'].toString();
            } else {
              // Only store seat number for display (privacy)
              if (seat['paidAt'] == null) {
                activePassengers.add({
                  'seatNo': seat['seatNo'],
                });
              }
            }
          }
        }

        final driverData = {
          'id': widget.ride['driverId'],
          'name': widget.ride['driver']?['name'] ?? 'Driver',
          'email': widget.ride['driver']?['email'] ?? 'N/A',
        };

        setState(() {
          fellowPassengers = activePassengers;
          totalSeats = seats;
          driver = driverData;
          mySeatNumber = mySeat;
          isLoading = false;
        });

        print('Found ${activePassengers.length} active passengers');
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching ride details: $e');
      setState(() => isLoading = false);
    }
  }

  // ============ IMMEDIATE REPORTING (During Ride) ============
  void _showImmediateReportDialog({required int seatNo}) {
    final TextEditingController descriptionController = TextEditingController();
    String severity = 'MEDIUM';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Report Passenger in Seat $seatNo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Severity',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSeverityChip('LOW', 'Low', severity, (value) {
                            setDialogState(() => severity = value);
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSeverityChip('MEDIUM', 'Medium', severity, (value) {
                            setDialogState(() => severity = value);
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSeverityChip('HIGH', 'High', severity, (value) {
                            setDialogState(() => severity = value);
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Describe the issue',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'What happened? (time, location, details...)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (descriptionController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please describe the issue')),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext);
                    await _submitImmediateComplaint(
                      seatNo: seatNo,
                      description: descriptionController.text,
                      severity: severity,
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Report'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitImmediateComplaint({
    required int seatNo,
    required String description,
    required String severity,
  }) async {
    setState(() => _isSubmitting = true);

    try {
      final identifyResponse = await http.post(
        Uri.parse('$backendUrl/api/complaints/identify-passenger'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Session.userId}',
        },
        body: jsonEncode({
          'rideId': widget.ride['id'],
          'seatNo': seatNo,
        }),
      );

      if (identifyResponse.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not identify passenger in that seat')),
        );
        return;
      }

      final identifyData = jsonDecode(identifyResponse.body);
      final accusedId = identifyData['passenger']['id'];

      final response = await http.post(
        Uri.parse('$backendUrl/api/complaints/passenger-to-passenger'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Session.userId}',
        },
        body: jsonEncode({
          'complainantId': Session.userId,
          'accusedId': accusedId,
          'rideId': widget.ride['id'],
          'description': description,
          'severity': severity,
          'seatNo': seatNo,
          'reportType': 'IMMEDIATE',
        }),
      );

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
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ============ DELAYED REPORTING (After Ride) ============
  void _showDelayedReportDialog() {
    _selectedSeatForReport = null;
    _selectedTimeRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(minutes: 30)),
      end: DateTime.now(),
    );
    _reportDescription = '';
    _severity = 'MEDIUM';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Report Issue After Ride'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Seat Selection
                    const Text(
                      'Select Seat Number',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: List.generate(totalSeats ?? 4, (index) {
                        final seatNo = index + 1;
                        final isMySeat = seatNo.toString() == mySeatNumber;
                        return FilterChip(
                          label: Text('Seat $seatNo'),
                          selected: _selectedSeatForReport == seatNo,
                          onSelected: isMySeat
                              ? null
                              : (selected) {
                                  setDialogState(() {
                                    _selectedSeatForReport = selected ? seatNo : null;
                                  });
                                },
                          selectedColor: Colors.red.shade100,
                          backgroundColor: Colors.grey.shade200,
                          disabledColor: Colors.grey.shade300,
                        );
                      }),
                    ),
                    if (_selectedSeatForReport == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Select a seat number (cannot report yourself)',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ),
                    const SizedBox(height: 16),
                    
                    // Time Selection
                    const Text(
                      'When did this happen?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    
                    // Time Range Presets
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Preset buttons
                          Row(
                            children: [
                              Expanded(
                                child: _buildTimePresetButton(
                                  'Last 15 min',
                                  DateTime.now().subtract(const Duration(minutes: 15)),
                                  DateTime.now(),
                                  setDialogState,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildTimePresetButton(
                                  'Last 30 min',
                                  DateTime.now().subtract(const Duration(minutes: 30)),
                                  DateTime.now(),
                                  setDialogState,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTimePresetButton(
                                  'Last 1 hour',
                                  DateTime.now().subtract(const Duration(hours: 1)),
                                  DateTime.now(),
                                  setDialogState,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildTimePresetButton(
                                  'Last 2 hours',
                                  DateTime.now().subtract(const Duration(hours: 2)),
                                  DateTime.now(),
                                  setDialogState,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          
                          // Custom time range picker (Selecting From and To separately)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('From:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              _buildDateTimePickerButton(
                                context,
                                _selectedTimeRange!.start,
                                (newDateTime) {
                                  setDialogState(() {
                                    _selectedTimeRange = DateTimeRange(
                                      start: newDateTime,
                                      end: _selectedTimeRange!.end.isBefore(newDateTime) 
                                          ? newDateTime.add(const Duration(minutes: 30)) 
                                          : _selectedTimeRange!.end,
                                    );
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              const Text('To:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              _buildDateTimePickerButton(
                                context,
                                _selectedTimeRange!.end,
                                (newDateTime) {
                                  if (newDateTime.isBefore(_selectedTimeRange!.start)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('End time must be after start time')),
                                    );
                                    return;
                                  }
                                  setDialogState(() {
                                    _selectedTimeRange = DateTimeRange(
                                      start: _selectedTimeRange!.start,
                                      end: newDateTime,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Display selected time range
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Selected: ${_formatDateTime(_selectedTimeRange!.start)} - ${_formatDateTime(_selectedTimeRange!.end)}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Severity
                    const Text(
                      'Severity',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSeverityChip('LOW', 'Low', _severity, (value) {
                            setDialogState(() => _severity = value);
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSeverityChip('MEDIUM', 'Medium', _severity, (value) {
                            setDialogState(() => _severity = value);
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSeverityChip('HIGH', 'High', _severity, (value) {
                            setDialogState(() => _severity = value);
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
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'What happened? (be specific)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => _reportDescription = value,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _selectedSeatForReport == null || _reportDescription.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(dialogContext);
                          await _submitDelayedComplaint();
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Report'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Helper method for time preset buttons
  Widget _buildTimePresetButton(String label, DateTime start, DateTime end, Function(void Function()) setState) {
    final isSelected = _selectedTimeRange?.start == start && _selectedTimeRange?.end == end;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedTimeRange = DateTimeRange(start: start, end: end);
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue.shade100 : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.blue.shade800 : Colors.black87,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  // Helper method for picking date and time together
  Widget _buildDateTimePickerButton(BuildContext context, DateTime current, Function(DateTime) onPicked) {
    return OutlinedButton.icon(
      onPressed: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: current,
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now(),
        );
        if (date == null) return;

        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(current),
        );
        if (time == null) return;

        onPicked(DateTime(date.year, date.month, date.day, time.hour, time.minute));
      },
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text(_formatDateTime(current)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 45),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _submitDelayedComplaint() async {
    if (_selectedSeatForReport == null || _selectedTimeRange == null) return;

    setState(() => _isSubmitting = true);

    try {
      final identifyResponse = await http.post(
        Uri.parse('$backendUrl/api/complaints/identify-passenger-by-time'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Session.userId}',
        },
        body: jsonEncode({
          'rideId': widget.ride['id'],
          'seatNo': _selectedSeatForReport,
          'startTime': _selectedTimeRange!.start.toIso8601String(),
          'endTime': _selectedTimeRange!.end.toIso8601String(),
        }),
      );

      if (identifyResponse.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not identify passenger at that time')),
        );
        return;
      }

      final identifyData = jsonDecode(identifyResponse.body);
      final accusedId = identifyData['passenger']['id'];

      final response = await http.post(
        Uri.parse('$backendUrl/api/complaints/passenger-to-passenger'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Session.userId}',
        },
        body: jsonEncode({
          'complainantId': Session.userId,
          'accusedId': accusedId,
          'rideId': widget.ride['id'],
          'description': _reportDescription,
          'severity': _severity,
          'seatNo': _selectedSeatForReport,
          'timeRange': {
            'start': _selectedTimeRange!.start.toIso8601String(),
            'end': _selectedTimeRange!.end.toIso8601String(),
          },
          'reportType': 'DELAYED',
        }),
      );

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
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime time) {
    return '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // Report Driver
  void _reportDriver() {
    final TextEditingController descriptionController = TextEditingController();
    String severity = 'MEDIUM';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Report Driver'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Severity',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSeverityChip('LOW', 'Low', severity, (value) {
                            setDialogState(() => severity = value);
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSeverityChip('MEDIUM', 'Medium', severity, (value) {
                            setDialogState(() => severity = value);
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSeverityChip('HIGH', 'High', severity, (value) {
                            setDialogState(() => severity = value);
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Describe the issue',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'What happened?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (descriptionController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please describe the issue')),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext);
                    await _submitDriverComplaint(
                      description: descriptionController.text,
                      severity: severity,
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Report'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitDriverComplaint({
    required String description,
    required String severity,
  }) async {
    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/complaints/passenger-to-driver'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Session.userId}',
        },
        body: jsonEncode({
          'passengerId': Session.userId,
          'driverId': widget.ride['driverId'],
          'rideId': widget.ride['id'],
          'description': description,
          'severity': severity,
        }),
      );

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
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
                            onPressed: _reportDriver,
                            icon: const Icon(Icons.report_problem_outlined, size: 16),
                            label: const Text('Report Driver'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Fellow Passengers Card (Only Seat Numbers - Privacy Preserved)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Other Passengers',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: brandOrange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${fellowPassengers.length} active',
                                  style: TextStyle(fontSize: 11, color: brandOrange),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (fellowPassengers.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  'No other passengers currently in this ride',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              ),
                            )
                          else
                            ...fellowPassengers.map((passenger) => ListTile(
                              leading: CircleAvatar(
                                backgroundColor: brandOrange.withOpacity(0.1),
                                child: Text(
                                  '${passenger['seatNo']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: brandOrange,
                                  ),
                                ),
                              ),
                              title: Text('Seat ${passenger['seatNo']}'),
                              subtitle: const Text('Active passenger'),
                              trailing: OutlinedButton.icon(
                                onPressed: () => _showImmediateReportDialog(
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
                          
                          const Divider(height: 24),
                          
                          // Delayed Report Button
                          ElevatedButton.icon(
                            onPressed: _showDelayedReportDialog,
                            icon: const Icon(Icons.access_time),
                            label: const Text('Report Issue After Ride'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black87,
                              minimumSize: const Size(double.infinity, 45),
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          Text(
                            'Use this to report issues that happened earlier. Select seat number and time range.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            textAlign: TextAlign.center,
                          ),
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