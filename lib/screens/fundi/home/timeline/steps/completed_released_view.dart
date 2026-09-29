import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../theme/app_theme.dart';
import '../widgets/timeline_card.dart';
import '../widgets/fee_row.dart';
import '../widgets/chat_sheet.dart';
import '../fundi_timeline_actions.dart';
import '../fundi_timeline_context.dart';
import '../../../rating/rate_client_screen.dart';

Widget buildCompletedReleasedView(
  BuildContext context,
  FundiTimelineContext c,
) {
  List<Widget> doneTimeline = [];
  if (!c.fundiConfirmedPayment) {
    doneTimeline.add(
      Card(
        color: Colors.green.shade50,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.green.shade700, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 48,
                color: Colors.green.shade700,
              ),
              const SizedBox(height: 8),
              Text(
                'KES ${c.releasedAmount} Released!',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    feeRow('Labour cost:', 'KES ${c.labour}'),
                    feeRow('Transport:', '+ KES ${c.transport}'),
                    feeRow('App maintenance cost:', '- KES ${c.fundiAppFee}'),
                    const Divider(),
                    feeRow(
                      'Total to receive:',
                      'KES ${c.releasedAmount}',
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'KES ${c.fundiReceives} has been released by ${c.clientName}. Confirm your M-Pesa.',
                style: GoogleFonts.inter(fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FundipapColors.greenSuccess,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => FundiTimelineActions.confirmPaymentReceived(
                    context,
                    c.jobId,
                    c.clientId,
                    c.clientName,
                    c.jobTitle,
                  ),
                  child: Text(
                    'YES, I HAVE RECEIVED KES ${c.fundiReceives}',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } else if (!c.fundiRatedClient) {
    doneTimeline.add(
      fundiCard(
        color: Colors.green.shade50,
        border: Colors.green,
        icon: Icons.account_balance_wallet,
        iconColor: Colors.green,
        title: 'KES ${c.releasedAmount} confirmed - Done',
        message:
            'You confirmed receipt: Labour KES ${c.labour} + Transport KES ${c.transport} - App KES ${c.fundiAppFee} = KES ${c.fundiReceives}',
        time: 'Done',
        isDone: true,
      ),
    );
    doneTimeline.add(
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
              Icon(Icons.star_rate_rounded, size: 48, color: Colors.amber),
              Text(
                'Rate ${c.clientName} - Mandatory',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
              ),
              Text(
                'Mandatory to clear this job.',
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
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RateClientScreen(
                        jobId: c.jobId,
                        clientId: c.clientId,
                        clientName: c.clientName,
                        trade: c.jobTitle,
                      ),
                    ),
                  ),
                  child: Text(
                    'RATE ${c.clientName} NOW',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } else {
    doneTimeline.add(
      fundiCard(
        color: Colors.green.shade50,
        border: Colors.green,
        icon: Icons.check_circle,
        iconColor: Colors.green,
        title: 'Completed & Rated - Done',
        message: 'KES ${c.releasedAmount} received and client rated - cleared',
        time: 'Done',
        isDone: true,
      ),
    );
  }

  return Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => FundiTimelineActions.goBackToMyJobs(context, tab: 2),
      ),
      title: Text(
        c.clientName,
        style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
      ),
      backgroundColor: FundipapColors.blackGray,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          onPressed: () => openChatSheet(context, c.jobId, c.clientName),
        ),
      ],
    ),
    body: ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: doneTimeline.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => doneTimeline[i],
    ),
  );
}
