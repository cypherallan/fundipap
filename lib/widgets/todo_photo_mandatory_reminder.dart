import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TodoPhotoMandatoryReminder extends StatelessWidget {
  const TodoPhotoMandatoryReminder({super.key});

  void _showExplanation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'PHOTOS MANDATORY TODO - Before Publish',
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
                'DO NOT HARDCODE - Works for all 140 jobs',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'TWO SETS OF PHOTOS (Generic Logic):',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'SET 1 - VERIFICATION (Proof fundi is at client site):\n'
                '• Client original photo has fixed anchor (wall, tiles, door, tree, fence, slab, fixed pipe - ANY fixed object, NOT movable like broom/jerrycan)\n'
                '• System auto-detects anchor + any text/serial via OCR (generic, not washing machine specific)\n'
                '• Blur anchor, show to fundi, ask to re-capture same anchor from same place\n'
                '• Must be in-app camera only, GPS within 100m of job, timestamp after siteVisitStartedAt, within 10 mins\n'
                '• If matches -> photoVerified = true. If not, ask retake (2 tries).\n\n'
                'SET 2 - EVIDENCE (Proof extra is needed):\n'
                '• 3-4 NEW photos showing why extra needed (no space, no water, bigger scope, materials needed)\n'
                '• Must be taken within 10 mins after Set 1, same GPS\n'
                '• Fundi writes reason in his own words\n'
                '• System compares client original description+photos vs fundi new description+photos (generic vision model)\n'
                '• Outputs scopeChangeScore 0-100 + fair price range from price book by category (not hardcoded)\n\n'
                'COUNTER RULES (No 0 or 5 insults):\n'
                '• If scopeChangeScore > 70 (genuine bigger job) -> client CANNOT counter 0 or 5. Minimum counter = 30% of requested extra. Show AI reason side-by-side.\n'
                '• If scopeChangeScore < 30 (no evidence) -> client CAN counter 0/5, fundi gets only transport if withdraws + fundi flagged.\n'
                '• Max 3 counters, then deadlock -> fundi chooses Continue old price OR Withdraw\n\n'
                'PUNISHMENT (Transport is refund, not compensation):\n'
                '• Genuine extra confirmed + client stubborn zeros + fundi withdraws -> Fundi gets transport + diagnostic fee (15% of labour or KES 800 min) from locked labour. Client loses that + platform keeps 5% fee. Client flagged zeroCounter.\n'
                '• Fake extra + fundi withdraws -> Fundi gets only transport, flagged fakeExtra.\n\n'
                'TODO BEFORE PUBLISH:\n'
                '1. Make Set 1 + Set 2 mandatory in fundi app (currently optional)\n'
                '2. Disable gallery, force in-app camera\n'
                '3. Implement generic anchor detection (fixed vs movable)\n'
                '4. Block 0/5 counters when genuine',
                style: GoogleFonts.inter(fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it, will make mandatory before publish',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showExplanation(context),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade400, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TODO: Make verification + evidence photos MANDATORY before publish',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to see full plan we agreed (2 sets, block 0/5, diagnostic fee) - DO NOT HARDCODE 140 jobs',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.info_outline, size: 18),
          ],
        ),
      ),
    );
  }
}
