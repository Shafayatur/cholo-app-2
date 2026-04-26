import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'session.dart';
import 'backend_config.dart';

class ComplaintDetailsPage extends StatefulWidget {
  final Map<String, dynamic> complaint;

  const ComplaintDetailsPage({Key? key, required this.complaint}) : super(key: key);

  @override
  State<ComplaintDetailsPage> createState() => _ComplaintDetailsPageState();
}

class _ComplaintDetailsPageState extends State<ComplaintDetailsPage> {
  bool isProcessing = false;
  final TextEditingController _messageController = TextEditingController();
  final Color brandOrange = const Color(0xFFF98825);

  Future<void> _sendWarning() async {
    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a warning message')),
      );
      return;
    }

    setState(() => isProcessing = true);

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/complaints/warnings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Session.userId}',
        },
        body: jsonEncode({
          'complaintId': widget.complaint['id'],
          'passengerId': widget.complaint['passenger']['id'],
          'message': _messageController.text,
        }),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context, 'refresh');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warning sent to passenger'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() => isProcessing = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => isProcessing = true);

    try {
      final response = await http.put(
        Uri.parse('$backendUrl/api/complaints/${widget.complaint['id']}/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Session.userId}',
        },
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context, 'refresh');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Complaint marked as ${status.toLowerCase()}')),
        );
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() => isProcessing = false);
    }
  }

  Future<void> _banPassenger({required bool permanent}) async {
    setState(() => isProcessing = true);

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/complaints/ban'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Session.userId}',
        },
        body: jsonEncode({
          'complaintId': widget.complaint['id'],
          'passengerId': widget.complaint['passenger']['id'],
          'duration': permanent ? 'permanent' : 'temporary',
          'reason': _messageController.text.isEmpty ? 'Violation of platform rules' : _messageController.text,
        }),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context, 'refresh');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(permanent ? 'Passenger permanently banned' : 'Passenger banned for 7 days'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() => isProcessing = false);
    }
  }

  void _showWarningDialog() {
    _messageController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Warning'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Passenger: ${widget.complaint['passenger']['name']}'),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Warning message...',
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
            onPressed: _sendWarning,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Send Warning'),
          ),
        ],
      ),
    );
  }

  void _showBanDialog({required bool permanent}) {
    _messageController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(permanent ? 'Permanent Ban' : 'Temporary Ban (7 days)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Passenger: ${widget.complaint['passenger']['name']}'),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Reason for ban...',
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
            onPressed: () => _banPassenger(permanent: permanent),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(permanent ? 'Permanent Ban' : 'Ban for 7 days'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final complaint = widget.complaint;
    final statusColors = {
      'PENDING': Colors.orange,
      'REVIEWED': Colors.blue,
      'RESOLVED': Colors.green,
      'DISMISSED': Colors.grey,
    };
    final statusColor = statusColors[complaint['status']] ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaint Details'),
        backgroundColor: brandOrange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: statusColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current Status', style: TextStyle(fontSize: 12)),
                        Text(
                          complaint['status'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: complaint['severity'] == 'HIGH'
                          ? Colors.red
                          : complaint['severity'] == 'MEDIUM'
                              ? Colors.orange
                              : Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      complaint['severity'],
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Passenger Info
            _buildSection('Passenger Information', [
              _buildInfoRow('Name', complaint['passenger']['name']),
              _buildInfoRow('Email', complaint['passenger']['email']),
              _buildInfoRow('Phone', complaint['passenger']['phone'] ?? 'N/A'),
              _buildInfoRow('Warning Count', complaint['passenger']['warningCount']?.toString() ?? '0'),
              _buildInfoRow('Banned', complaint['passenger']['isBanned'] ? 'Yes' : 'No'),
            ]),
            const SizedBox(height: 16),

            // Driver Info
            _buildSection('Driver Information', [
              _buildInfoRow('Name', complaint['driver']['name']),
              _buildInfoRow('Email', complaint['driver']['email']),
            ]),
            const SizedBox(height: 16),

            // Ride Info
            _buildSection('Ride Information', [
              _buildInfoRow('Route', '${complaint['ride']['origin']} → ${complaint['ride']['destination']}'),
              _buildInfoRow('Date', complaint['ride']['departureTime']?.toString().substring(0, 10) ?? 'N/A'),
            ]),
            const SizedBox(height: 16),

            // Complaint Details
            _buildSection('Complaint Details', [
              Text(
                complaint['description'],
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Filed: ${complaint['createdAt'].toString().substring(0, 16)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ]),
            const SizedBox(height: 24),

            // Action Buttons (only show if status is PENDING)
            if (complaint['status'] == 'PENDING')
              Column(
                children: [
                  const Text(
                    'Take Action',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isProcessing ? null : () => _updateStatus('REVIEWED'),
                          icon: const Icon(Icons.visibility),
                          label: const Text('Review'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isProcessing ? null : () => _updateStatus('RESOLVED'),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Resolve'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isProcessing ? null : () => _updateStatus('DISMISSED'),
                          icon: const Icon(Icons.close),
                          label: const Text('Dismiss'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isProcessing ? null : _showWarningDialog,
                          icon: const Icon(Icons.warning_amber),
                          label: const Text('Warning'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isProcessing ? null : () => _showBanDialog(permanent: false),
                          icon: const Icon(Icons.block),
                          label: const Text('Temp Ban'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isProcessing ? null : () => _showBanDialog(permanent: true),
                          icon: const Icon(Icons.gavel),
                          label: const Text('Perm Ban'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            if (isProcessing) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
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