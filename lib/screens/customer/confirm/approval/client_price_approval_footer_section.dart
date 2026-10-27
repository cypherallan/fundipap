part of 'client_price_approval_screen.dart';

mixin FooterSectionMixin
    on
        State<ClientPriceApprovalScreen>,
        FieldsMixin,
        HelpersMixin,
        ActionsMixin {
  Widget buildNeedsExtraEscrowSection(
    Map<String, dynamic> job,
    int alreadyLockedCorrect,
    int extraToLock,
    int newTotal,
    bool isCounterAccepted,
    int acceptedCounterLabour,
    Map<String, dynamic> reneg,
    int extraLabor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green, width: 1.5),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 32),
          const SizedBox(height: 8),
          Text(
            'Extra KES $extraToLock Approved!',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Colors.green.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'You already locked KES $alreadyLockedCorrect. Go to timeline to lock extra KES $extraToLock and reach KES $newTotal.',
            style: GoogleFonts.inter(fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                'GO TO TIMELINE TO LOCK KES $extraToLock',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPendingActionsSection(
    Map<String, dynamic> job,
    int newLabor,
    int extraLabor,
    int alreadyLockedCorrect,
    int oldTransport,
    int extraToLock,
    int newTotal,
    List<Map<String, dynamic>> partsNeeded,
    bool isMaterialsOnly,
    int partsEstimateTotal,
    String tillNumber,
    int oldLabor,
  ) {
    bool hasParts = partsNeeded.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasParts) ...[
          Text(
            'Who will buy parts?',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          RadioListTile(
            value: 'client',
            groupValue: whoBuys,
            title: Text(
              'I will buy myself (SAFE)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.green,
              ),
            ),
            onChanged: (v) => setState(() => whoBuys = v!),
          ),
          RadioListTile(
            value: 'fundi',
            groupValue: whoBuys,
            title: Text(
              'Send fundi to buy',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.red),
            ),
            subtitle: Text(
              tillNumber.isEmpty
                  ? 'Fundi will find shop first'
                  : 'Pay KES $partsEstimateTotal to Till $tillNumber',
              style: GoogleFonts.inter(fontSize: 10),
            ),
            onChanged: (v) => setState(() => whoBuys = v!),
          ),
          const SizedBox(height: 12),
        ],
        if (!hasParts)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FundipapColors.greenSuccess,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: loading
                  ? null
                  : () => _acceptClientBuys(
                      job,
                      newLabor,
                      extraLabor,
                      alreadyLockedCorrect,
                      oldTransport,
                    ),
              child: Text(
                'Accept New Labour KES $extraLabor',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (hasParts) ...[
          if (whoBuys == 'client')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.greenSuccess,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: loading
                    ? null
                    : () => _acceptClientBuys(
                        job,
                        newLabor,
                        extraLabor,
                        alreadyLockedCorrect,
                        oldTransport,
                      ),
                child: Text(
                  isMaterialsOnly
                      ? 'Accept Materials - I will buy myself\nTotal materials KES $partsEstimateTotal'
                      : 'Accept - I will buy parts myself',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (whoBuys == 'fundi')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: loading
                    ? null
                    : () => _acceptFundiBuysAtRisk(
                        job,
                        newLabor,
                        extraLabor,
                        alreadyLockedCorrect,
                        oldTransport,
                      ),
                child: Text(
                  isMaterialsOnly
                      ? 'Accept - Send fundi to buy materials\nTotal materials KES $partsEstimateTotal to Till $tillNumber'
                      : 'Accept - Send fundi to buy',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
        const SizedBox(height: 10),
        Builder(
          builder: (context) {
            int currentRound = 0;
            bool hasEvidence = false;
            try {
              var renegData =
                  widget.job['renegotiation'] as Map<String, dynamic>? ?? {};
              currentRound = (renegData['counterRound'] ?? 0) as int;
              var ev = (renegData['evidencePhotoUrls'] ?? []) as List;
              var ver = (renegData['verificationPhotoUrls'] ?? []) as List;
              hasEvidence = ev.isNotEmpty || ver.isNotEmpty;
            } catch (_) {}
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasEvidence)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified,
                          size: 16,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Fundi provided site photos (verification + evidence). System confirms scope change.',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (currentRound >= 2)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Text(
                      'Round ${currentRound + 1}/3 - After 3 counters, fundi can choose to continue old price or withdraw with compensation.',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                // COUNTER + REJECT ROW - REJECT BACK
                Row(
                  children: [
                    if (!isMaterialsOnly)
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(
                                  'Counter Offer - Round ${currentRound + 1}',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Fundi requested extra KES $extraLabor. Enter your counter (0 allowed). No dispute on counter.',
                                      style: GoogleFonts.inter(fontSize: 10),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: counterPriceCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText:
                                            'Your extra labour offer (0 allowed)',
                                        helperText:
                                            'Min when verified: KES ${(extraLabor * 0.3).round()} (30% of requested).',
                                        helperStyle: GoogleFonts.inter(
                                          fontSize: 9,
                                        ),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: counterReasonCtrl,
                                      maxLines: 2,
                                      decoration: InputDecoration(
                                        labelText: 'Reason (required if 0)',
                                        hintText:
                                            'Why old price should cover it?',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _counter(
                                        oldLabor,
                                        alreadyLockedCorrect,
                                        oldTransport,
                                        extraLabor,
                                      );
                                    },
                                    child: const Text('Send Counter'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Text(
                            'Counter ${currentRound > 0 ? '(Round ${currentRound + 1})' : ''}',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    if (!isMaterialsOnly) const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 1.5),
                        ),
                        onPressed: loading
                            ? null
                            : () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text(
                                      'Reject Extra Labour?',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: Colors.red,
                                      ),
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'You are rejecting extra KES $extraLabor requested by fundi.',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.red.shade200,
                                            ),
                                          ),
                                          child: Text(
                                            'If you reject, fundi can DISPUTE. Fundi will be able to raise dispute and admin will review photos. Counter with 0 does NOT trigger dispute.',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: Colors.red.shade800,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: counterReasonCtrl,
                                          maxLines: 2,
                                          decoration: InputDecoration(
                                            labelText:
                                                'Reason for rejection (required)',
                                            hintText:
                                                'Why you reject extra labour?',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () {
                                          if (counterReasonCtrl.text
                                              .trim()
                                              .isEmpty) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Enter reason for rejection',
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          Navigator.pop(context);
                                          _rejectRequest(job, extraLabor);
                                        },
                                        child: const Text(
                                          'Reject - Fundi Can Dispute',
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                        child: Text(
                          'Reject',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _rejectRequest(Map<String, dynamic> job, int extraLabor) async {
    setState(() => loading = true);
    try {
      final jobId = widget.jobId;
      final fundiId = (job['fundiId'] ?? job['acceptedFundiId'] ?? '')
          .toString();
      final oldPrice =
          (job['agreedPrice'] ??
                  job['laborCost'] ??
                  job['originalLaborCost'] ??
                  0)
              is int
          ? job['agreedPrice'] ?? job['laborCost'] ?? 0
          : int.tryParse('${job['agreedPrice'] ?? job['laborCost'] ?? 0}') ?? 0;

      await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
        'renegotiation.status': 'rejected',
        'renegotiation.rejectedAt': FieldValue.serverTimestamp(),
        'renegotiation.rejectedBy': 'client',
        'renegotiation.rejectedReason': counterReasonCtrl.text.trim(),
        'renegotiation.extraLaborRequested': extraLabor,
        'status': 'dispute_pending',
        'hasClientRejected': true,
        'fundiCanDispute': true,
        'fundiHasUnread': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (fundiId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'toUserId': fundiId,
          'userId': fundiId,
          'jobId': jobId,
          'type': 'price_rejected',
          'title': 'Client rejected your new price request',
          'message':
              'Client rejected extra KES $extraLabor. Reason: ${counterReasonCtrl.text.trim()}. Tap to dispute or continue with KES $oldPrice',
          'isRead': false,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rejected. Fundi can dispute.'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget buildStatusDoneSection(String renegStatus, int newTotal) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'Status: ${renegStatus.toUpperCase()} - Total KES $newTotal',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: Colors.green,
          ),
        ),
      ),
    );
  }
}
