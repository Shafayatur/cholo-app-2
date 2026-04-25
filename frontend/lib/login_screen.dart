import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'admin_panel.dart';
import 'backend_config.dart';
import 'driver_panel.dart';
import 'user_panel.dart';
import 'session.dart'; 
import 'driver_dashboard.dart';  



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
  String _selectedRole = 'PASSENGER'; // Default role

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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

Session.userId = data["user"]["id"];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome ${data['user']['name']}!')),
        );

        // Navigate based on user role
        final String userRole = data['user']['role'];
        if (userRole == 'ADMIN') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AdminPanel()),
          );
        } else if (userRole == 'DRIVER') {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const DriverDashboard()),
            );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const UserPanel()),
          );
        }
      } else {
        final error = jsonDecode(response.body);
        setState(() {
          _errorMessage = error['error'] ?? 'Login failed';
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
        _nameController.clear();
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Image.asset('assets/cholo_logo.png', height: 120),
              const SizedBox(height: 40),

              // Title
              Text(
                _showSignup ? 'Create Account' : 'Login',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 24),

              // Name Field (only for signup)
              if (_showSignup)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextField(
                    controller: _nameController,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: brandOrange,
                      ),
                      hintText: 'Full Name',
                      hintStyle: TextStyle(color: Colors.orange.shade300),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: brandOrange, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: brandOrange, width: 2.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),

              // Email/Username Field
              TextField(
                controller: _emailController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.person_outline, color: brandOrange),
                  hintText: 'Email',
                  hintStyle: TextStyle(color: Colors.orange.shade300),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: brandOrange, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: brandOrange, width: 2.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),

              // Password Field
              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: true,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.lock_outline, color: brandOrange),
                  hintText: 'Password',
                  hintStyle: TextStyle(color: Colors.orange.shade300),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: brandOrange, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: brandOrange, width: 2.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),

              // Role Selection (only for signup)
              if (_showSignup)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: AbsorbPointer(
                    absorbing: _isLoading,
                    child: DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.admin_panel_settings,
                          color: brandOrange,
                        ),
                        hintText: 'Select Role',
                        hintStyle: TextStyle(color: Colors.orange.shade300),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: brandOrange,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: brandOrange,
                            width: 2.0,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'PASSENGER',
                          child: Text('Passenger'),
                        ),
                        DropdownMenuItem(
                          value: 'DRIVER',
                          child: Text('Driver'),
                        ),
                        DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedRole = value!;
                        });
                      },
                    ),
                  ),
                ),

              // Error Message
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                ),

              // Forgot Password Link (only for login)
              if (!_showSignup)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            // Handle forgot password routing
                          },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: darkText,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Action Button
              ElevatedButton(
                onPressed: _isLoading ? null : (_showSignup ? _signup : _login),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _showSignup ? 'Sign Up' : 'Login',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 32),

              // Toggle between Login and Signup
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _showSignup
                        ? 'Already have an account? '
                        : 'Not registered? ',
                    style: TextStyle(color: darkText, fontSize: 16),
                  ),
                  GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _showSignup = !_showSignup;
                              _errorMessage = '';
                              _emailController.clear();
                              _passwordController.clear();
                              _nameController.clear();
                              _selectedRole = 'PASSENGER'; // Reset to default
                            });
                          },
                    child: Text(
                      _showSignup ? 'Login' : 'Sign Up',
                      style: TextStyle(
                        color: brandOrange,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
