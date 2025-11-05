import 'package:flutter/material.dart';

class Label extends StatelessWidget {
  const Label(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(color: Color(0xFF666A73), fontWeight: FontWeight.w700));
  }
}

InputDecoration underlineDeco({
  required String hint,
  required IconData icon,
  required Color focusColor,
  Widget? suffix,
}) {
  return InputDecoration(
    prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9BA0A8)),
    suffixIcon: suffix,
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFB6BAC2)),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 14),
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFE0E2E6), width: 1.2),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: focusColor, width: 1.6),
    ),
  );
}

class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.focusPink});
  final Color focusPink;
  @override
  State<PasswordField> createState() => _PasswordFieldState(); 
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: _obscure,
      decoration: underlineDeco(
        hint: 'enter your password',
        icon: Icons.lock_outline,
        focusColor: widget.focusPink,
        suffix: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: const Color(0xFF9BA0A8),
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}