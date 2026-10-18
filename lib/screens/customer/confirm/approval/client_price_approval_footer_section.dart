
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
              onPressed: () {
                Navigator.pop(context);
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
        // AGREED: No Reject - Counter only, 0 allowed but tracked, generic for 140 jobs
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
                            'Fundi provided site photos (verification + evidence). System confirms scope change. Low counters flagged.',
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
                      'Round ${currentRound + 1}/3 - After 3 low counters, fundi can choose to continue old price or withdraw with compensation (transport + diagnostic fee from your locked amount).',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
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
                                      'Fundi requested extra KES $extraLabor. Enter your counter (0 allowed). If 0, explain why old price covers it.',
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
                                            'Min when verified: KES ${(extraLabor * 0.3).round()} (30% of requested). Transport already locked',
                                        helperStyle: GoogleFonts.inter(
                                          fontSize: 9,
                                        ),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    if (counterPriceCtrl.text.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Builder(
                                          builder: (_) {
                                            int cVal =
                                                int.tryParse(
                                                  counterPriceCtrl.text,
                                                ) ??
                                                0;
                                            int minAllowed = (extraLabor * 0.3)
                                                .round();
                                            bool isLow =
                                                hasEvidence &&
                                                cVal < minAllowed;
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Extra to lock: KES ${cVal + (cVal * 0.05).round()}',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                if (isLow)
                                                  Text(
                                                    '⚠️ Counter too low for verified scope. Minimum when photos verified: KES $minAllowed. Low counters flagged and after 3 rounds fundi gets diagnostic fee from your locked amount.',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 9,
                                                      color: Colors.red,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                if (!hasEvidence && cVal == 0)
                                                  Text(
                                                    'You countered 0 - fundi will be asked to re-counter with better evidence. After 3 rounds, deadlock -> fundi chooses.',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 9,
                                                      color: Colors
                                                          .orange
                                                          .shade800,
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
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
                    if (!isMaterialsOnly) const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'No Reject - counter with 0 if old price covers it',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
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
