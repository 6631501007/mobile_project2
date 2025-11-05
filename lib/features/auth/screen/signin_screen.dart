import 'package:borrowing_mobile/features/auth/screen/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:borrowing_mobile/features/auth/widgets/auth_widgets.dart';
import 'package:borrowing_mobile/features/navigation/main_navigation_page.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false; //  state สำหรับ loading

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    print('Attempting login...');

    setState(() {
      _isLoading = true;
    });

    final baseUrl = dotenv.env['API_BASE_URL']; 
    if (baseUrl == null) {
      print('ERROR: .env file not found or API_BASE_URL is missing');
      _showErrorSnackBar('Config error: API URL not found.');
      if (context.mounted) setState(() { _isLoading = false; });
      return;
    }
    
    final url = Uri.parse('$baseUrl/login'); 
    
    final email = _emailController.text.trim();
    final pass = _passwordController.text;

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': pass}),
      );
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      // ตรวจสอบ widget ยังอยู่ในหน้าจอก่อนเรียกใช้ context
      if (!context.mounted) return;

      if (response.statusCode == 200) {
        print('Login successful!');
        final data = json.decode(response.body);
        final user =
            data['user']; // { "user_id": 1, "email": "...", "full_name": "...", "role": "..." }

        // บันทึกข้อมูล User ลง SharedPreferences ---
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('userId', user['user_id']);
        await prefs.setString('fullName', user['full_name']);
        await prefs.setString('userRole', user['role']);
        // ---------------------------------------------------

        final role = user['role'];

        switch (role) {
          // case 'staff':
          //   Navigator.pushReplacement(
          //     context,
          //     MaterialPageRoute(
          //       builder: (context) => const StaffNavigationPage(),
          //     ),
          //   );
          //   break;
          // case 'lecture':
          //   Navigator.pushReplacement(
          //     context,
          //     MaterialPageRoute(
          //       builder: (context) => const LectureNavigationPage(),
          //     ),
          //   );
          //   break;
          case 'student':
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const MainNavigationPage(),
              ),
            );
            break;
          default:
            _showErrorSnackBar('Role ไม่ถูกต้อง: $role');
        }
      } else {
        print('Login failed!');
        // Login ไม่สำเร็จ
        final data = json.decode(response.body);
        _showErrorSnackBar(data['message'] ?? 'อีเมลหรือรหัสผ่านไม่ถูกต้อง');
      }
    } catch (e) {
      print('Sign-in Error: $e');
      // เกิดข้อผิดพลาด
      if (!context.mounted) return;
      _showErrorSnackBar('เชื่อมต่อเซิร์ฟเวอร์ล้มเหลว: ${e.toString()}');
    } finally {
      print('Login process finished.');
      if (context.mounted) {
        // ตรวจสอบ context ก่อน setState เสมอ
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
              top: 0,
              left: 0,
              right: 0,
              height: headerH,
              child: Image.asset('assets/vector2.png', fit: BoxFit.cover),
            ),
            Positioned(
              top: headerH - contentOverlap,
              left: 0,
              right: 0,
              bottom: 0,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                children: [
                  const Text(
                    'Sign in',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF202124),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: pink,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 28),

                  const Label('Email'),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: underlineDeco(
                      hint: 'enter your email',
                      icon: Icons.mail_outline,
                      focusColor: pink,
                    ),
                  ),
                  const SizedBox(height: 22),

                  const Label('Password'),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: underlineDeco(
                      hint: 'enter your password',
                      icon: Icons.lock_outline,
                      focusColor: pink,
                    ),
                  ),
                  const SizedBox(height: 36),

                  SizedBox(
                    height: 52,
                    // 6. [แก้ไข] เปลี่ยนปุ่มให้แสดง Loading
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: _isLoading
                          ? null
                          : _signIn, // 👈 ถ้าโหลดอยู่ ให้กดไม่ได้
                      child: _isLoading
                          ? const SizedBox(
                              // 👈 ถ้าโหลดอยู่ ให้แสดงวงกลม
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text('Login'), // 👈 ถ้าไม่โหลด แสดง Text
                    ),
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          color: Color(0xFF9BA0A8),
                          fontSize: 13.5,
                        ),
                        children: [
                          const TextSpan(text: "Don't have an Account ? "),
                          TextSpan(
                            text: 'Sign up',
                            style: const TextStyle(
                              color: pink,
                              fontWeight: FontWeight.w700,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpScreen(),
                                  ),
                                );
                              },
                          ),
                        ],
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
