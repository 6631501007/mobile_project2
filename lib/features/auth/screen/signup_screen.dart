import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:borrowing_mobile/features/auth/widgets/auth_widgets.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  String _selectedRole = 'student'; // Default role
  bool _isLoading = false;

  Future<void> _signUp() async {
    if (_isLoading) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar('Passwords do not match.');
      return;
    }
     if (_fullNameController.text.trim().isEmpty) {
       _showErrorSnackBar('Please enter your Full Name.');
       return;
     }
     if (_emailController.text.trim().isEmpty || !_emailController.text.contains('@')) {
       _showErrorSnackBar('Please enter a valid Email.');
       return;
     }
     if (_passwordController.text.length < 6) { // Example: Minimum length
         _showErrorSnackBar('Password must be at least 6 characters long.');
         return;
     }


    setState(() { _isLoading = true; });
    final baseUrl = dotenv.env['API_BASE_URL']; 
    if (baseUrl == null) {
      print('ERROR: .env file not found or API_BASE_URL is missing');
      _showErrorSnackBar('Config error: API URL not found.');
      if (context.mounted) setState(() { _isLoading = false; });
      return;
    }

    final url = Uri.parse('$baseUrl/register');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'full_name': _fullNameController.text.trim(),
          'role': _selectedRole,
        }),
      );

      if (!context.mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Please login.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back to SignInScreen
      } else {
        final data = json.decode(response.body);
        _showErrorSnackBar(data['message'] ?? 'Registration failed.');
      }
    } catch (e) {
      if (!context.mounted) return;
      _showErrorSnackBar('Connection error: ${e.toString()}');
    } finally {
      if (context.mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  // Helpe for showing errors
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose(); // 👈 Dispose new controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const pink = Color(0xFFF07D86);
    const purple = Color(0xFF9B95D7);
    final size = MediaQuery.of(context).size;
    final double headerH = size.height * 0.38;
    const double contentOverlap = 80;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.white)),
            Positioned(
              top: 0, left: 0, right: 0, height: headerH,
              child: Image.asset('assets/vector2.png', fit: BoxFit.cover),
            ),
            Positioned(
              top: headerH - contentOverlap, left: 0, right: 0, bottom: 0,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                children: [
                  const Text(
                    'Sign up',
                    style: TextStyle(
                      fontSize: 34, fontWeight: FontWeight.w800, color: Color(0xFF202124),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 45, height: 4,
                    decoration:
                        BoxDecoration(color: pink, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 28),

                  const Label('Full Name'),
                  TextField(
                    controller: _fullNameController,
                    keyboardType: TextInputType.name,
                    decoration: underlineDeco(hint: 'enter your full name', icon: Icons.person_outline, focusColor: pink),
                  ),
                  const SizedBox(height: 22),

                  const Label('Email'),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        underlineDeco(hint: 'enter your email', icon: Icons.mail_outline, focusColor: pink),
                  ),
                  const SizedBox(height: 22),

                  const Label('Password'),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: underlineDeco(hint: 'enter your password (min 6 chars)', icon: Icons.lock_outline, focusColor: pink),
                  ),
                  const SizedBox(height: 22),

                  const Label('Confirm Password'),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: underlineDeco(hint: 'confirm your password', icon: Icons.lock_outline, focusColor: pink),
                  ),
                  const SizedBox(height: 22),

                  const SizedBox(height: 36),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purple, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      onPressed: _isLoading ? null : _signUp, // 👈 Connect to API call
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Text('Create Account'), // 👈 Update Text
                    ),
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text.rich(
                        TextSpan(
                          style: TextStyle(color: Color(0xFF9BA0A8), fontSize: 13.5),
                          children: [
                            TextSpan(text: "Already have an Account? "),
                            TextSpan(
                              text: 'Login',
                              style: TextStyle(color: pink, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}