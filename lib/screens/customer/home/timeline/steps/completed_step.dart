import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../rating/rate_fundi_screen.dart';
import '../widgets/timeline_card.dart';
import '../timeline_context.dart';

class CompletedSteps {
  static bool handle(List<Widget> timeline, TimelineContext c) {
    if (c.status == 'completed' && !c.clientRated) {
      timeline.add(
        TimelineCard(
          title: 'Job completed by ${c.fundiName} - Done',
          body:
              'Payment KES ${c.job['totalReleasedAmount'] ?? c.alreadyLocked} released. Please rate ${c.fundiName} to clear this job.\nYou paid: Labour ${c.labour} + Transport ${c.transport} + App ${c.clientAppFee} = ${c.totalToPay}',
          icon: Icons.verified,
          isDone: true,
        ),
      );
      timeline.add(
        Card(
          color: Colors.orange.shade50,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.orange.shade700, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(
                  Icons.star_rate_rounded,
                  size: 48,
                  color: Colors.amber,
                ),
                const SizedBox(height: 8),
                Text(
                  'Rate ${c.fundiName} - Mandatory',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'This notification will be cleared only after you rate and review.',
                  style: GoogleFonts.inter(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.push(
                      c.context,
                      MaterialPageRoute(
                        builder: (_) => RateFundiScreen(
                          jobId: c.jobId,
                          fundiId: c.fundiId,
                          fundiName: c.fundiName,
                          trade: c.trade,
                        ),
                      ),
                    ),
                    child: Text(
                      'RATE ${c.fundiName.toUpperCase()} NOW',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return true;
    }
    if (c.status == 'completed' && c.clientRated) {
      timeline.add(
        TimelineCard(
          title: 'Job completed by ${c.fundiName} - Rated - Done',
          body:
              'You rated ${c.job['clientRating'] ?? 5} stars - KES ${c.job['totalReleasedAmount'] ?? c.alreadyLocked} released. Fundi received ${c.fundiAppFee} (after app maintenance cost).',
          icon: Icons.check_circle,
          isDone: true,
        ),
      );
      return true;
    }
    return false;
  }
}
