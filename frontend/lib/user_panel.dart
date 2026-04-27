import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'SeatSelectionPage.dart';
import 'login_screen.dart';
import 'session.dart';
import 'backend_config.dart';
import 'passenger_rides_list.dart';

class UserPanel extends StatefulWidget {
  const UserPanel({Key? key}) : super(key: key);

  @override
  State<UserPanel> createState() => _UserPanelState();
}

class _UserPanelState extends State<UserPanel> {
  List<dynamic> notifications = [];
  bool isLoading = true;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    if (Session.userId == null) return;
    
    setState(() => isLoading = true);
    try {
      // Fetch notifications
      final notifRes = await http.get(
        Uri.parse('$backendUrl/api/notifications/user/${Session.userId}'),
      );
      
      // Fetch user data (to check ban status/warning count)
      // We might need a generic user endpoint, for now let's use passenger history 
      // or just assume we have an endpoint for user profile
      final userRes = await http.get(
        Uri.parse('$backendUrl/api/complaints/passenger/${Session.userId}/history'),
      );

      if (notifRes.statusCode == 200 && userRes.statusCode == 200) {
        setState(() {
          notifications = jsonDecode(notifRes.body)['notifications'];
          userData = jsonDecode(userRes.body);
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() => isLoading = false);
    }
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: SizedBox(
          width: double.maxFinite,
          child: notifications.isEmpty
              ? const Center(child: Text('No notifications'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    return ListTile(
                      leading: Icon(
                        n['type'] == 'WARNING' ? Icons.warning : 
                        n['type'] == 'SUCCESS' ? Icons.check_circle : Icons.info,
                        color: n['type'] == 'WARNING' ? Colors.orange : 
                               n['type'] == 'SUCCESS' ? Colors.green : Colors.blue,
                      ),
                      title: Text(n['title'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: Text(n['message'], style: const TextStyle(fontSize: 12)),
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color brandOrange = const Color(0xFFF98825);
    final Color darkText = const Color(0xFF2C323A);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: brandOrange,
        title: const Text(
          'User Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: _showNotifications,
              ),
              if (notifications.any((n) => n['isRead'] == false))
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                    constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchData,
          ),
        ],
      ),
      body: SafeArea(
        child: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('assets/cholo_logo.png', height: 60),
                  const SizedBox(height: 20),

                  Text(
                    'Welcome back!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: darkText),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  _buildFeatureSection(brandOrange, darkText),

                  const SizedBox(height: 32),

                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C323A)),
                  ),

                  const SizedBox(height: 16),

                  _buildQuickActions(context),
                ],
              ),
            ),
      ),
    );
  }


  Widget _buildNotificationCard(dynamic n) {
    IconData icon = Icons.info_outline;
    Color color = Colors.blue;
    
    if (n['type'] == 'WARNING') {
      icon = Icons.warning_amber_rounded;
      color = Colors.orange;
    } else if (n['type'] == 'DANGER') {
      icon = Icons.error_outline;
      color = Colors.red;
    } else if (n['type'] == 'SUCCESS') {
      icon = Icons.check_circle_outline;
      color = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(n['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(n['message'], style: const TextStyle(fontSize: 12)),
        trailing: Text(
          n['createdAt'].toString().substring(5, 10),
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildFeatureSection(Color brandOrange, Color darkText) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brandOrange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Features',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkText),
          ),
          const SizedBox(height: 16),
          _buildFeatureItem('Book a Ride', 'Find and book rides to your destination'),
          _buildFeatureItem('Ride History', 'View your past rides and bookings'),
          _buildFeatureItem('Payment Methods', 'Manage your payment options'),
          _buildFeatureItem('Profile Settings', 'Update your personal information'),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFFF98825), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                Text(description, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton('Book Ride', Icons.directions_car, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SeatSelectionPage(rideId: 1)));
              }),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton('My Rides', Icons.history, () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => PassengerRidesList())
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton('Profile', Icons.person, () {}),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton('Logout', Icons.logout, () {
                Session.userId = null;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String title, IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF98825),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
