import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'login_screen.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FundipapColors.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: FundipapColors.primaryYellow,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Karibu\nFundi Pap',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 36,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You are signing in as?',
                style: GoogleFonts.inter(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 40),
              _RoleCard(
                icon: Icons.person,
                title: 'Client',
                subtitle: 'I need a fundi',
                color: Colors.white,
                onTap: () => _go(context, 'client'),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.build,
                title: 'Fundi',
                subtitle: 'I am a fundi, I want jobs',
                color: FundipapColors.blackGray,
                textColor: Colors.white,
                onTap: () => _go(context, 'fundi'),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => _go(context, 'admin'),
                  child: Text(
                    'Admin?',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.black26,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Center(
                child: Text(
                  'M-Pesa Protected • Escrow',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.black45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _go(BuildContext c, String role) {
    Navigator.push(
      c,
      MaterialPageRoute(builder: (_) => LoginScreen(role: role)),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.textColor = FundipapColors.blackGray,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FundipapColors.primaryYellow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: FundipapColors.blackGray),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: textColor.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: textColor),
          ],
        ),
      ),
    );
  }
}
