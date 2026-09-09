import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../app.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, required this.role});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  static const adminEmails = [
    'ellerhn.agwona@gmail.com',
    'agwonamallan@gmail.com',
  ];

  void _login() async {
    setState(() => loading = true);
    try {
      var user = await _auth.login(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );
      if (user == null) throw 'Login failed';
      var role = await _auth.getUserRole(user.uid);

      // Admin lock
      if (role == 'admin' && !adminEmails.contains(user.email)) {
        throw 'Not authorized as admin';
      }
      if (widget.role == 'admin' && !adminEmails.contains(user.email)) {
        throw 'Only ${adminEmails.first} can login as admin';
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              HomeNavigator(role: role ?? widget.role, email: user.email ?? ''),
        ),
        (r) => false,
      );
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
          'Login as ${widget.role}',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _login,
                child: Text(
                  loading
                      ? 'Logging in...'
                      : 'Login as ${widget.role.toUpperCase()}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
