import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'session.dart';
import 'backend_config.dart';
import 'complaint_details_page.dart';

class ComplaintsPage extends StatefulWidget {
  const ComplaintsPage({Key? key}) : super(key: key);

  @override
  State<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends State<ComplaintsPage> {
  List<dynamic> complaints = [];
  bool isLoading = true;
  String selectedFilter = 'ALL';
  
  final Color brandOrange = const Color(0xFFF98825);

  @override
  void initState() {
    super.initState();
    fetchComplaints();
  }

  Future<void> fetchComplaints() async {
    setState(() => isLoading = true);
    
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/api/complaints'),
        headers: {'Authorization': 'Bearer ${Session.userId}'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          complaints = data['complaints'];
        });
      }
    } catch (e) {
      print('Error fetching complaints: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> updateComplaintStatus(int complaintId, String newStatus) async {
    try {
      final response = await http.put(
        Uri.parse('$backendUrl/api/complaints/$complaintId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Session.userId}',
        },
        body: jsonEncode({'status': newStatus}),
      );
      
      if (response.statusCode == 200) {
        fetchComplaints(); // Refresh list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Complaint marked as $newStatus')),
        );
      }
    } catch (e) {
      print('Error updating complaint: $e');
    }
  }

  List<dynamic> get filteredComplaints {
    if (selectedFilter == 'ALL') return complaints;
    return complaints.where((c) => c['status'] == selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Complaints Management'),
        backgroundColor: brandOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchComplaints,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('PENDING', 'Pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('REVIEWED', 'Reviewed'),
                  const SizedBox(width: 8),
                  _buildFilterChip('RESOLVED', 'Resolved'),
                  const SizedBox(width: 8),
                  _buildFilterChip('DISMISSED', 'Dismissed'),
                ],
              ),
            ),
          ),
          
          // Complaints List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredComplaints.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.report_problem_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'No complaints found',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredComplaints.length,
                        itemBuilder: (context, index) {
                          final complaint = filteredComplaints[index];
                          return _buildComplaintCard(complaint);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filter, String label) {
    return FilterChip(
      label: Text(label),
      selected: selectedFilter == filter,
      onSelected: (_) {
        setState(() {
          selectedFilter = filter;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: brandOrange.withOpacity(0.2),
      checkmarkColor: brandOrange,
    );
  }

  Widget _buildComplaintCard(dynamic complaint) {
    final statusColors = {
      'PENDING': Colors.orange,
      'REVIEWED': Colors.blue,
      'RESOLVED': Colors.green,
      'DISMISSED': Colors.red,
    };
    
    final statusColor = statusColors[complaint['status']] ?? Colors.grey;
    
    return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(  // CHANGE: Wrap with InkWell instead of ExpansionTile
        onTap: () async {
            final result = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ComplaintDetailsPage(complaint: complaint),
            ),
            );
            if (result == 'refresh') {
            fetchComplaints(); // Refresh list after action
            }
        },
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
            children: [
                // Keep the same UI as before but simplified for the list
                Row(
                children: [
                    CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Icon(Icons.report_problem, color: statusColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Text(
                            'Complaint #${complaint['id']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                            'Against: ${complaint['passenger']['name']}',
                            style: const TextStyle(fontSize: 12),
                        ),
                        ],
                    ),
                    ),
                    Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                        complaint['status'],
                        style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                        ),
                    ),
                    ),
                    const Icon(Icons.chevron_right),
                ],
                ),
                const SizedBox(height: 8),
                Text(
                complaint['description'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
            ),
        ),
        ),
    );
    }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}