import 'package:flutter/material.dart';
import 'package:borrowing_mobile/features/auth/screens/signin_screen.dart';


class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key}); 

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F0F14);
    const white = Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _DecorPainter()),
            const Align(alignment: Alignment(0, -0.95), child: _BrandTitle()),
            Align(
              alignment: const Alignment(0, -0.20),
              child: Image.asset('assets/con.png', width: 330, fit: BoxFit.contain),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 36,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Play without limits',
                    style: TextStyle(color: white, fontWeight: FontWeight.w800, fontSize: 26),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your console. Your time',
                    style: TextStyle(color: white, fontWeight: FontWeight.w800, fontSize: 22),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Discover a new way to enjoy gaming freedom.\n'
                    'No more limits just choose your console and start playing.',
                    style: TextStyle(
                      color: Color(0xCCBFC2CC),
                      fontSize: 13.5,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignInScreen()),
                          );
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration:
                              const BoxDecoration(color: white, shape: BoxShape.circle),
                          child: const Icon(Icons.arrow_forward, size: 26, color: Colors.black),
                        ),
                      ),
                    ],
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

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();
  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 18,
      letterSpacing: 0.2,
    );
    const accent = Color(0xFFE8A3B8);
    return RichText(
      text: const TextSpan(
        style: base,
        children: [
          TextSpan(text: 'Cons'),
          TextSpan(text: 'O', style: TextStyle(color: accent)),
          TextSpan(text: 'le go', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _DecorPainter extends StatelessWidget {
  const _DecorPainter();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _BgPainter());
}

class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0x66FFFFFF);

    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.25), size.width * 0.42, stroke);
    canvas.drawCircle(Offset(size.width * -0.05, -20), size.width * 0.70, stroke);
    canvas.drawCircle(Offset(size.width * 0.70, size.height * 0.42), size.width * 0.38, stroke);
    canvas.drawCircle(Offset(size.width * 0.24, size.height * 0.48), 70, stroke);

    final purple = Paint()..color = const Color(0xFFB6A9F1).withOpacity(0.75);
    final pink = Paint()..color = const Color(0xFFE7A3A8).withOpacity(0.85);
    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.68), 74, purple);
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.58), 82, pink);

    _star(canvas, Offset(size.width * 0.80, size.height * 0.19), 10, const Color(0xFFD9A3E8));
    _star(canvas, Offset(size.width * 0.63, size.height * 0.44), 10, const Color(0xFFF3A9B3));
    _star(canvas, Offset(size.width * 0.18, size.height * 0.33), 12, const Color(0xFF58E8D1));
    _star(canvas, Offset(size.width * 0.47, size.height * 0.30), 10, const Color(0xFFA7B4FF));
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r * 0.25, c.dy - r * 0.25, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + r * 0.25, c.dy + r * 0.25, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r * 0.25, c.dy + r * 0.25, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - r * 0.25, c.dy - r * 0.25, c.dx, c.dy - r);
    canvas.drawPath(p, Paint()..color = color..style = PaintingStyle.fill);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}