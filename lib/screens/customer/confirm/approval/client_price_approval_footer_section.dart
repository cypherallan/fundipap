part of 'client_price_approval_screen.dart';

mixin FooterSectionMixin
    on
        State<ClientPriceApprovalScreen>,
        FieldsMixin,
        HelpersMixin,
        ActionsMixin {
  // FIXED - No more LOCK button here, only redirect to timeline
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
              onPressed: () {
                Navigator.pop(
                  context,
                ); // Back to timeline where real LOCK button lives
              },
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

  // Keep buildPendingActionsSection and buildStatusDoneSection SAME as before
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
        Row(
          children: [
            if (!isMaterialsOnly)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Counter Offer - Enter Labour Only'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: counterPriceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText:
                                    'Your extra labour offer (e.g. 1000)',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            TextField(
                              controller: counterReasonCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Reason',
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
                            onPressed: () => _counter(
                              oldLabor,
                              alreadyLockedCorrect,
                              oldTransport,
                              extraLabor,
                            ),
                            child: const Text('Send Counter'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Counter'),
                ),
              ),
            if (!isMaterialsOnly) const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('jobs')
                      .doc(widget.jobId)
                      .update({'renegotiation.status': 'rejected'});
                  if (!mounted) return;
                  Navigator.pop(context);
                },
                child: const Text(
                  'Reject',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ],
    );
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
