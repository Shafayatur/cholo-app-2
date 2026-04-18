import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'admin_panel.dart';
import 'backend_config.dart';
import 'driver_panel.dart';
import 'user_panel.dart';
import 'session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _isLoading = false;
  bool _showSignup = false;
  String _errorMessage = '';
  String _selectedRole = 'PASSENGER';

  final Color brandOrange = const Color(0xFFF98825);
  final Color darkText = const Color(0xFF2C323A);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = data["user"];

        Session.userId = user["id"]; // ✅ SAVE USER ID

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Welcome ${user['name']}!')));

        final role = user['role'];

        if (role == 'ADMIN') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminPanel()),
          );
        } else if (role == 'DRIVER') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DriverPanel()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const UserPanel()),
          );
        }
      } else {
        setState(() {
          _errorMessage = data['error'] ?? 'Login failed';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signup() async {
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
          'role': _selectedRole,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signup successful! Please login.')),
        );

        setState(() {
          _showSignup = false;
        });
      } else {
        final error = jsonDecode(response.body);
        setState(() {
          _errorMessage = error['error'] ?? 'Signup failed';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Image.asset('assets/cholo_logo.png', height: 120),
              const SizedBox(height: 30),

              Text(
                _showSignup ? "Create Account" : "Login",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),

              const SizedBox(height: 20),

              if (_showSignup)
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Name"),
                ),

              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email"),
              ),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password"),
              ),

              const SizedBox(height: 10),

              if (_showSignup)
                DropdownButton<String>(
                  value: _selectedRole,
                  items: const [
                    DropdownMenuItem(
                      value: 'PASSENGER',
                      child: Text('Passenger'),
                    ),
                    DropdownMenuItem(value: 'DRIVER', child: Text('Driver')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value!;
                    });
                  },
                ),

              const SizedBox(height: 20),

              if (_errorMessage.isNotEmpty)
                Text(_errorMessage, style: const TextStyle(color: Colors.red)),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _isLoading ? null : (_showSignup ? _signup : _login),
                child: Text(_showSignup ? "Signup" : "Login"),
              ),

              TextButton(
                onPressed: () {
                  setState(() {
                    _showSignup = !_showSignup;
                  });
                },
                child: Text(
                  _showSignup
                      ? "Already have account? Login"
                      : "Create account",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
