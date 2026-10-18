import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TodoPhotoMandatoryReminder extends StatelessWidget {
  const TodoPhotoMandatoryReminder({super.key});

  void _showTodoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'TODO before publish',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Make photos mandatory - currently optional',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '1. In _submit() check:',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '- if verificationPhotos.isEmpty -> block + SnackBar "Verification mandatory - re-capture client anchor"',
                style: GoogleFonts.inter(fontSize: 10),
              ),
              Text(
                '- if evidencePhotos.isEmpty -> block + SnackBar "Evidence mandatory"',
                style: GoogleFonts.inter(fontSize: 10),
              ),
              SizedBox(height: 8),
              Text(
                '2. Verification rules:',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '- In-app camera only, GPS within 100m, timestamp after siteVisitStartedAt, within 10 mins',
                style: GoogleFonts.inter(fontSize: 10),
              ),
              Text(
                '- Auto-detect fixed anchor (wall, tiles, door, fence, tree, slab, fixed pipe, serial) - generic, not hardcoded',
                style: GoogleFonts.inter(fontSize: 10),
              ),
              Text(
                '- Client never sees verification photos - system flag only',
                style: GoogleFonts.inter(fontSize: 10),
              ),
              SizedBox(height: 8),
              Text(
                '3. Evidence rules:',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '- 3-4 new photos why extra needed, within 10 mins after Set 1, same GPS',
                style: GoogleFonts.inter(fontSize: 10),
              ),
              Text(
                '- Vision: scopeChangeScore + fair price from price book',
                style: GoogleFonts.inter(fontSize: 10),
              ),
              SizedBox(height: 8),
              Text(
                '4. Client blocks:',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '- If hasVerificationPhotos -> block counter 0 and <30% of requested',
                style: GoogleFonts.inter(fontSize: 10),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showTodoDialog(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.list_alt, size: 14, color: Colors.orange.shade800),
            SizedBox(width: 4),
            Text(
              'TODO: Photos mandatory',
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.orange.shade800,
              ),
            ),
            SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 14, color: Colors.orange.shade800),
          ],
        ),
      ),
    );
  }
}
