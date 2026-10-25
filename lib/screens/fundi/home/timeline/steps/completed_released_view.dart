import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../theme/app_theme.dart';
import '../widgets/timeline_card.dart';
import '../widgets/fee_row.dart';
import '../widgets/chat_sheet.dart';
import '../fundi_timeline_actions.dart';
import '../fundi_timeline_context.dart';
import '../../../rating/rate_client_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../support/contact_admin_screen.dart';

Widget buildCompletedReleasedView(
  BuildContext context,
  FundiTimelineContext c,
) {
  var job = c.job;
  bool isAutoResolved =
      (job['lastDisputeStatus'] ?? '').toString() == 'resolved_explained';
  bool isEscalated =
      (job['lastDisputeStatus'] ?? '').toString() == 'escalated_to_support';
  bool isUnderReview =
      !isAutoResolved &&
      !isEscalated &&
      ((job['lastDisputeStatus'] ?? '').toString() == 'open' ||
          (job['status'] ?? '').toString() == 'payment_disputed_by_fundi');

  if (isEscalated) {
    int _toIntSafe(dynamic v, int fb) {
      if (v == null) return fb;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is num) return v.toInt();
      String s = v.toString().replaceAll(RegExp(r'[^0-9]'), '');
      if (s.isEmpty) return fb;
      return int.tryParse(s) ?? fb;
    }

    int amt = _toIntSafe(job['fundiPayoutAmount'], c.releasedAmount);
    String b2c = (job['lastB2CId'] ?? '').toString();
    String c2b = (job['lastC2BId'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => FundiTimelineActions.goBackToMyJobs(context, tab: 2),
        ),
        title: Text(
          'Escalated to support - KES $amt',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        backgroundColor: FundipapColors.blackGray,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade300),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.support_agent, size: 48, color: Colors.blue),
                SizedBox(height: 12),
                Text(
                  'Escalated to support',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your case KES $amt\nB2C: $b2c\nC2B: $c2b\nSupport team will check your M-Pesa statement.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ContactAdminScreen(
                            jobId: c.jobId,
                            b2cId: b2c,
                            c2bId: c2b,
                            finalAmount: amt,
                            clientName: c.clientName,
                            jobTitle: c.jobTitle,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'CONTACT SUPPORT',
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
      ),
    );
  }

  if (isUnderReview) {
    int _toIntSafe(dynamic v, int fb) {
      if (v == null) return fb;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is num) return v.toInt();
      String s = v.toString().replaceAll(RegExp(r'[^0-9]'), '');
      if (s.isEmpty) return fb;
      return int.tryParse(s) ?? fb;
    }

    int amt = _toIntSafe(job['fundiPayoutAmount'], c.releasedAmount);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => FundiTimelineActions.goBackToMyJobs(context, tab: 2),
        ),
        title: Text(
          'Dispute under review - KES $amt',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        backgroundColor: FundipapColors.blackGray,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_top, size: 48, color: Colors.orange),
                SizedBox(height: 12),
                Text(
                  'Dispute under review',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Admin is checking your payment KES $amt\nB2C: ${job['lastB2CId'] ?? 'pending'}\nC2B: ${job['lastC2BId'] ?? ''}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                SizedBox(height: 16),
                Text(
                  'You will be notified when resolved. Do not create duplicate dispute.',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  if (isAutoResolved) {
    int _toIntSafe(dynamic v, int fb) {
      if (v == null) return fb;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is num) return v.toInt();
      String s = v.toString().replaceAll(RegExp(r'[^0-9]'), '');
      if (s.isEmpty) return fb;
      return int.tryParse(s) ?? fb;
    }

    int finalAmount = _toIntSafe(job['fundiPayoutAmount'], c.releasedAmount);
    String b2cId = (job['lastB2CId'] ?? job['b2cTransactionId'] ?? '')
        .toString();
    String c2bId = (job['lastC2BId'] ?? job['c2bTransactionId'] ?? '')
        .toString();
    String msg = (job['lastDisputeMessage'] ?? job['lastAutoCheck'] ?? '')
        .toString();
    int feePct = _toIntSafe(job['fundiCommissionPct'], 5);
    String lastDisputeId = (job['lastDisputeId'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => FundiTimelineActions.goBackToMyJobs(context, tab: 2),
        ),
        title: Text(
          'Dispute resolved - KES $finalAmount',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        backgroundColor: FundipapColors.blackGray,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'System auto-checked - you got correct amount',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  'Client released KES $finalAmount',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                Text(msg, style: GoogleFonts.inter(fontSize: 11)),
                Divider(height: 20),
                Text(
                  'Your actual Fundipap receipt',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      feeRow('Base labour:', 'KES ${c.labour}'),
                      feeRow('Transport:', '+ KES ${c.transport}'),
                      if ((c.deductionThisJob ?? 0) > 0)
                        feeRow(
                          'Penalty deduction:',
                          '- KES ${c.deductionThisJob!.toStringAsFixed(0)}',
                          bold: true,
                        ),
                      feeRow(
                        'App maintenance (${feePct}%):',
                        '- KES ${c.fundiAppFee}',
                      ),
                      Divider(),
                      feeRow('Total sent:', 'KES $finalAmount', bold: true),
                      SizedBox(height: 8),
                      feeRow('C2B ID:', c2bId),
                      feeRow('B2C ID:', b2cId),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FundipapColors.greenSuccess,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  if (lastDisputeId.isNotEmpty) {
                    await FirebaseFirestore.instance
                        .collection('disputes')
                        .doc(lastDisputeId)
                        .update({
                          'status': 'closed_confirmed',
                          'fundiConfirmedAt': FieldValue.serverTimestamp(),
                          'fundiConfirmed': true,
                        });
                  }
                  await FirebaseFirestore.instance
                      .collection('jobs')
                      .doc(c.jobId)
                      .update({
                        'lastDisputeStatus': 'resolved_confirmed',
                        'autoResolvedConfirmedAt': FieldValue.serverTimestamp(),
                        'status': 'completed',
                        'fundiConfirmedPayment': true,
                      });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Job closed - thank you!')),
                    );
                    FundiTimelineActions.goBackToMyJobs(context, tab: 2);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(
                'YES, CONFIRM KES $finalAmount & CLOSE JOB',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
                side: BorderSide(color: Colors.blue.shade700, width: 1.5),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContactAdminScreen(
                      jobId: c.jobId,
                      b2cId: b2cId,
                      c2bId: c2bId,
                      finalAmount: finalAmount,
                      clientName: c.clientName,
                      jobTitle: c.jobTitle,
                    ),
                  ),
                );
              },
              child: Text(
                'CONTACT SUPPORT - STILL WRONG?',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'If still wrong, contact support with M-Pesa statement and screenshots.',
            style: GoogleFonts.inter(fontSize: 10, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

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
                    if ((c.deductionThisJob ?? 0) > 0) ...[
                      feeRow(
                        'Penalty deduction:',
                        '- KES ${c.deductionThisJob!.toStringAsFixed(0)}',
                        bold: true,
                      ),
                    ],
                    feeRow('App maintenance cost:', '- KES ${c.fundiAppFee}'),
                    const Divider(),
                    feeRow(
                      'Total to receive:',
                      'KES ${c.releasedAmount}',
                      bold: true,
                    ),
                    // Show ledger IDs for KRA proof
                    const SizedBox(height: 8),
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('mpesaPayouts')
                          .doc(c.jobId)
                          .get(),
                      builder: (_, snap) {
                        if (!snap.hasData || !snap.data!.exists)
                          return const SizedBox();
                        var d = snap.data!.data() as Map<String, dynamic>;
                        return Column(
                          children: [
                            feeRow('C2B ID:', '${d['c2bTransactionId'] ?? ''}'),
                            feeRow('B2C ID:', '${d['b2cTransactionId'] ?? ''}'),
                          ],
                        );
                      },
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
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FundipapColors.redAlert,
                    side: BorderSide(
                      color: FundipapColors.redAlert,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _openNotReceivedDispute(context, c),
                  child: Text(
                    'NO, I DID NOT RECEIVE KES ${c.fundiReceives}',
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
    // ... keep your rating card same as before
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
              const Icon(
                Icons.star_rate_rounded,
                size: 48,
                color: Colors.amber,
              ),
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
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => doneTimeline[i],
    ),
  );
}

void _openNotReceivedDispute(BuildContext context, FundiTimelineContext c) {
  String selected = 'not_received_any';
  final partialController = TextEditingController();
  final detailsController = TextEditingController();
  DateTime releaseTime = c.releasedAt ?? DateTime.now();

  Future<DateTime> getReleaseTime() async {
    if (c.releasedAt != null) return c.releasedAt!;
    try {
      var snap = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(c.jobId)
          .get();
      var d = snap.data() ?? {};
      var ts =
          d['paymentReleasedAt'] ??
          d['releasedAt'] ??
          d['fundiPaymentReleasedAt'] ??
          d['completedAt'];
      if (ts is Timestamp) return ts.toDate();
      if (ts is String) return DateTime.tryParse(ts) ?? DateTime.now();
    } catch (_) {}
    return DateTime.now();
  }

  showDialog(
    context: context,
    builder: (ctx) {
      return FutureBuilder<DateTime>(
        future: getReleaseTime(),
        builder: (ctx, snap) {
          final rt = snap.data ?? releaseTime;
          return StatefulBuilder(
            builder: (ctx, setSt) {
              final now = DateTime.now();
              final elapsed = now.difference(rt);
              final remaining = rt
                  .add(const Duration(hours: 2))
                  .difference(now);
              final isPast2Hours = elapsed.inHours >= 2;
              final canDisputeNow = selected == 'partial' ? true : isPast2Hours;

              String buildDescription() {
                final extra = detailsController.text.trim();
                final extraPart = extra.isNotEmpty
                    ? '\nAdditional: $extra'
                    : '';
                if (selected == 'not_received_any') {
                  return 'I did not receive any money. Client ${c.clientName} says KES ${c.releasedAmount} (I should receive KES ${c.fundiReceives}) was released for job ${c.jobTitle} (${c.jobId}) at $rt, but my M-Pesa has not received anything. Waited ${elapsed.inMinutes} mins. payoutDoc: mpesaPayouts/${c.jobId} $extraPart';
                } else {
                  final rec = partialController.text.trim();
                  return 'I received but not full. Expected KES ${c.fundiReceives}, received KES ${rec.isEmpty ? 'UNKNOWN' : rec} from ${c.clientName} for job ${c.jobTitle} (${c.jobId}).$extraPart';
                }
              }

              return AlertDialog(
                title: Text(
                  'Payment Issue',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selected,
                        decoration: InputDecoration(
                          labelText: 'What happened?',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'not_received_any',
                            child: Text(
                              'I did not receive any money',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'partial',
                            child: Text(
                              'I received but not full KES ${c.fundiReceives}',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                          ),
                        ],
                        onChanged: (v) => setSt(() => selected = v!),
                      ),
                      const SizedBox(height: 12),
                      if (selected == 'not_received_any') ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isPast2Hours
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isPast2Hours
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isPast2Hours
                                    ? Icons.check_circle
                                    : Icons.hourglass_bottom,
                                size: 18,
                                color: isPast2Hours
                                    ? Colors.green
                                    : Colors.orange.shade800,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isPast2Hours
                                      ? '2 hours passed since release. You can now raise dispute.'
                                      : 'M-Pesa can delay up to 2 hours. Released ${elapsed.inMinutes} mins ago.\nPlease wait ${remaining.inMinutes > 0 ? '${remaining.inMinutes} mins' : 'a bit more'} before disputing.',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (selected == 'partial') ...[
                        TextField(
                          controller: partialController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'How much did you receive?',
                            prefixText: 'KES ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Partial payments have no M-Pesa delay - you can dispute immediately.',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: detailsController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Additional details (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canDisputeNow
                          ? FundipapColors.redAlert
                          : Colors.grey,
                    ),
                    onPressed: canDisputeNow
                        ? () async {
                            if (selected == 'partial' &&
                                partialController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Enter amount received'),
                                ),
                              );
                              return;
                            }
                            final reason = selected == 'not_received_any'
                                ? 'Payment not received at all'
                                : 'Partial payment received';
                            final desc = buildDescription();
                            Navigator.pop(ctx);
                            await FundiTimelineActions.openDispute(
                              context,
                              c.jobId,
                              c.clientId,
                              reason: reason,
                              description: desc,
                            );
                          }
                        : null,
                    child: Text(
                      canDisputeNow
                          ? 'OPEN DISPUTE'
                          : 'WAIT ${remaining.inMinutes}M',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}
