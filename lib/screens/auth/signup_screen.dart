import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  final String role;
  const SignupScreen({super.key, required this.role});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _auth = AuthService();
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  bool loading = false;
  bool showPass = false;
  bool showConfirm = false;

  String strengthText = '';
  Color strengthColor = Colors.red;
  double strengthValue = 0;

  void _checkPassword(String pass) {
    bool hasUpper = pass.contains(RegExp(r'[A-Z]'));
    bool hasLower = pass.contains(RegExp(r'[a-z]'));
    bool hasNumber = pass.contains(RegExp(r'[0-9]'));
    bool hasSpecial = pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    bool has8 = pass.length >= 8;

    int score = 0;
    if (has8) score++;
    if (hasUpper) score++;
    if (hasLower) score++;
    if (hasNumber) score++;
    if (hasSpecial) score++;

    if (pass.isEmpty) {
      setState(() {
        strengthText = '';
        strengthValue = 0;
      });
      return;
    }

    if (score <= 2) {
      setState(() {
        strengthText =
            'Weak password - needs upper, lower, number, special, 8+ chars';
        strengthColor = Colors.red;
        strengthValue = 0.33;
      });
    } else if (score <= 4) {
      setState(() {
        strengthText =
            'Okay - add ${!hasUpper ? "upper " : ""}${!hasLower ? "lower " : ""}${!hasNumber ? "number " : ""}${!hasSpecial ? "special " : ""}${!has8 ? "8 chars" : ""}';
        strengthColor = Colors.orange;
        strengthValue = 0.66;
      });
    } else {
      setState(() {
        strengthText = 'Very strong';
        strengthColor = Colors.green;
        strengthValue = 1.0;
      });
    }
  }

  void _signup() async {
    if (passCtrl.text != confirmCtrl.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords don't match")));
      return;
    }
    if (strengthValue < 1.0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strengthText)));
      return;
    }
    setState(() => loading = true);
    try {
      await _auth.signUp(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
        role: widget.role,
        phone: phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created! Now login')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sign up as ${widget.role}',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: InputDecoration(
                labelText: 'M-Pesa Phone',
                prefixText: '+254 ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // PASSWORD FIRST
            TextField(
              controller: passCtrl,
              obscureText: !showPass,
              onChanged: _checkPassword,
              decoration: InputDecoration(
                labelText: 'Enter your password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    showPass ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => showPass = !showPass),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (strengthText.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: strengthValue,
                    color: strengthColor,
                    backgroundColor: Colors.grey[300],
                    minHeight: 6,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strengthText,
                    style: TextStyle(
                      color: strengthColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            // CONFIRM SECOND
            TextField(
              controller: confirmCtrl,
              obscureText: !showConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm your password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    showConfirm ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => showConfirm = !showConfirm),
                ),
              ),
            ),
            if (confirmCtrl.text.isNotEmpty &&
                passCtrl.text != confirmCtrl.text)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Passwords don't match",
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _signup,
                child: Text(loading ? 'Creating...' : 'Create Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
