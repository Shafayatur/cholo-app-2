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
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Rides"),
        backgroundColor: const Color(0xFFF98825),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : rides.isEmpty
              ? const Center(child: Text("No rides found"))
              : ListView.builder(
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final ride = rides[index];

                    return Card(
                      child: ListTile(
                        title: Text(
                            "${ride['origin']} → ${ride['destination']}"),
                        subtitle: Text("Status: ${ride['status']}"),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RideDetailsPage(ride: ride),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}