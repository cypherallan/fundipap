import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MyJobsScreen extends StatelessWidget {
  const MyJobsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'My Active Jobs - Coming soon',
        style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
      ),
    );
  }
}
