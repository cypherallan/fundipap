import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DisputesScreen extends StatelessWidget {
  const DisputesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            'Disputes & Tickets',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
          ),
          Text('No tickets', style: GoogleFonts.inter(color: Colors.black45)),
        ],
      ),
    );
  }
}
