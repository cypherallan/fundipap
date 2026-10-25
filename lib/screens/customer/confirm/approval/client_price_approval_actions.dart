part of 'client_price_approval_screen.dart';

mixin ActionsMixin
    on State<ClientPriceApprovalScreen>, FieldsMixin, HelpersMixin {
  Future<void> _acceptClientBuys(
    Map<String, dynamic> job,
    int newLabor,
    int extraLabor,
    int alreadyLockedCorrect,
    int oldTransport,
  ) async {
    setState(() => loading = true);
    try {
      int oldLabor = _toInt(
        job['lastCounterAmount'] ??
            widget.job['lastCounterAmount'] ??
            job['laborCost'] ??
            widget.job['laborCost'] ??
            job['agreedPrice'] ??
            widget.job['agreedPrice'] ??
            newLabor - extraLabor,
      );
      int oldClientFee = (oldLabor * 0.05).round();
      int newClientFee = (newLabor * 0.05).round();
      int newFundiFee = (newLabor * 0.05).round();
      int extraAppFee = (newClientFee - oldClientFee).clamp(0, 999999);
      int extraToLock = extraLabor + extraAppFee;
      int newTotal = alreadyLockedCorrect + extraToLock;
      if (extraToLock == 0) {
        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .update({
              'agreedPrice': newLabor,
              'laborCost': newLabor,
              'transportFee': oldTransport,
              'clientAppFee': newClientFee,
              'fundiAppFee': newFundiFee,
              'totalClientPays': alreadyLockedCorrect,
              'totalCost': alreadyLockedCorrect,
              'fundiReceives': newLabor - newFundiFee + oldTransport,
              'extraLaborAmount': 0,
              'extraToLock': 0,
              'status': 'waiting_for_client_to_buy_parts',
              'renegotiation.status': 'accepted_client_buys_parts',
              'renegotiation.whoBuysParts': 'client',
              'renegotiation.currentPhase': 'waiting_for_client_to_buy_parts',
              'renegotiation.extraLabor': 0,
              'renegotiation.extraToLock': 0,
              'renegotiation.acceptedAt': FieldValue.serverTimestamp(),
              'fundiHasUnread': true,
              'customerHasUnread': false,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        if (mounted) Navigator.pop(context);
        return;
      }
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
            'agreedPrice': oldLabor,
            'laborCost': oldLabor,
            'transportFee': oldTransport,
            'totalClientPays': alreadyLockedCorrect,
            'totalCost': alreadyLockedCorrect,
            'escrowAmount': alreadyLockedCorrect,
            'extraLaborAmount': extraLabor,
            'extraClientAppFee': extraAppFee,
            'extraEscrowAmount': extraToLock,
            'extraToLock': extraToLock,
            'extraEscrowStatus': 'pending',
            'clientNeedsToTopup': true,
            'escrowStatus': 'pending_topup',
            'status': 'awaiting_extra_escrow',
            'renegotiation.status':
                'accepted_client_buys_parts_pending_extra_escrow',
            'renegotiation.whoBuysParts': 'client',
            'renegotiation.currentPhase': 'waiting_for_extra_escrow',
            'renegotiation.newLabor': newLabor,
            'renegotiation.newTotal': newTotal,
            'renegotiation.extraLabor': extraLabor,
            'renegotiation.extraToLock': extraToLock,
            'renegotiation.acceptedAt': FieldValue.serverTimestamp(),
            'fundiHasUnread': true,
            'customerHasUnread': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _acceptFundiBuysAtRisk(
    Map<String, dynamic> job,
    int newLabor,
    int extraLabor,
    int alreadyLockedCorrect,
    int oldTransport,
  ) async {
    setState(() => loading = true);
    try {
      int oldLabor = _toInt(
        job['lastCounterAmount'] ??
            widget.job['lastCounterAmount'] ??
            job['laborCost'] ??
            widget.job['laborCost'] ??
            job['agreedPrice'] ??
            widget.job['agreedPrice'] ??
            0,
      );
      if (oldLabor == 0) oldLabor = newLabor - extraLabor;
      int oldClientFee = (oldLabor * 0.05).round();
      int newClientFee = (newLabor * 0.05).round();
      int newFundiFee = (newLabor * 0.05).round();
      int extraAppFee = newClientFee - oldClientFee;
      int extraToLock = extraLabor + extraAppFee;
      int newTotal = alreadyLockedCorrect + extraToLock;
      int newFundiReceives = newLabor - newFundiFee + oldTransport;
      int oldFundiReceives = oldLabor - oldClientFee + oldTransport;

      if (extraToLock == 0) {
        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .update({
              'agreedPrice': newLabor,
              'laborCost': newLabor,
              'transportFee': oldTransport,
              'clientAppFee': newClientFee,
              'fundiAppFee': newFundiFee,
              'totalClientPays': alreadyLockedCorrect,
              'totalCost': alreadyLockedCorrect,
              'escrowAmount': alreadyLockedCorrect,
              'fundiReceives': newLabor - newFundiFee + oldTransport,
              'extraLaborAmount': 0,
              'extraToLock': 0,
              'extraEscrowStatus': 'not_needed',
              'clientNeedsToTopup': false,
              'escrowStatus': 'held',
              'status': 'fundi_buying_parts',
              'renegotiation.status': 'accepted_fundi_buys_at_client_risk',
              'renegotiation.whoBuysParts': 'fundi',
              'renegotiation.partsPaidTo': 'shop_direct',
              'renegotiation.currentPhase': 'fundi_buying_parts',
              'renegotiation.riskAccepted': true,
              'renegotiation.extraLabor': 0,
              'renegotiation.extraToLock': 0,
              'renegotiation.acceptedAt': FieldValue.serverTimestamp(),
              'fundiHasUnread': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        if (mounted) Navigator.pop(context);
        return;
      }

      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
            'agreedPrice': oldLabor,
            'laborCost': oldLabor,
            'transportFee': oldTransport,
            'clientAppFee': oldClientFee,
            'fundiAppFee': oldClientFee,
            'totalClientPays': alreadyLockedCorrect,
            'totalCost': alreadyLockedCorrect,
            'escrowAmount': alreadyLockedCorrect,
            'fundiReceives': oldFundiReceives,
            'extraLaborAmount': extraLabor,
            'extraEscrowAmount': extraToLock,
            'extraToLock': extraToLock,
            'extraEscrowStatus': 'pending',
            'clientNeedsToTopup': true,
            'escrowStatus': 'pending_topup',
            'status': 'awaiting_extra_escrow',
            'renegotiation.status':
                'accepted_fundi_buys_at_client_risk_pending_extra_escrow',
            'renegotiation.whoBuysParts': 'fundi',
            'renegotiation.partsPaidTo': 'shop_direct',
            'renegotiation.currentPhase': 'waiting_for_extra_escrow',
            'renegotiation.oldTransportFee': oldTransport,
            'renegotiation.oldLabor': oldLabor,
            'renegotiation.newLabor': newLabor,
            'renegotiation.riskAccepted': true,
            'renegotiation.extraLabor': extraLabor,
            'renegotiation.newTotalClientPays': newTotal,
            'renegotiation.newFundiReceives': newFundiReceives,
            'renegotiation.extraToLock': extraToLock,
            'renegotiation.acceptedAt': FieldValue.serverTimestamp(),
            'fundiHasUnread': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _counter(
    int oldLabor,
    int alreadyLockedCorrect,
    int oldTransport,
    int extraRequested,
  ) async {
    if (counterPriceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter counter amount (0 allowed)')),
      );
      return;
    }
    if (counterReasonCtrl.text.trim().isEmpty &&
        (int.tryParse(counterPriceCtrl.text.trim()) ?? 0) == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reason required when countering 0 - why old price covers it?',
          ),
        ),
      );
      return;
    }
    setState(() => loading = true);
    try {
      int counterExtraLabor = int.tryParse(counterPriceCtrl.text.trim()) ?? 0;
      bool hasEvidence = false;
      int currentRound = 0;
      int previousLowCounters = 0;
      try {
        var jobSnap = await FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .get();
        var reneg =
            (jobSnap.data()?['renegotiation'] as Map<String, dynamic>?) ?? {};
        var ev = (reneg['evidencePhotoUrls'] ?? []) as List;
        var ver = (reneg['verificationPhotoUrls'] ?? []) as List;
        hasEvidence = ev.isNotEmpty || ver.isNotEmpty;
        currentRound = (reneg['counterRound'] ?? 0) as int;
        previousLowCounters = (reneg['clientLowCounterCount'] ?? 0) as int;
      } catch (_) {}

      int minAllowed = (extraRequested * 0.3).round();
      if (hasEvidence &&
          counterExtraLabor > 0 &&
          counterExtraLabor < minAllowed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Counter too low for verified scope. Minimum when photos verified: KES $minAllowed (30% of KES $extraRequested).',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => loading = false);
        return;
      }
      if (hasEvidence && counterExtraLabor == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cannot counter 0 when fundi provided verified site photos showing bigger scope. Minimum is KES $minAllowed.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        setState(() => loading = false);
        return;
      }

      int counterExtraFee = (counterExtraLabor * 0.05).round();
      int counterExtraToLock = counterExtraLabor + counterExtraFee;
      int counterNewLaborTotal = oldLabor + counterExtraLabor;
      int counterNewTotalClientPays = alreadyLockedCorrect + counterExtraToLock;
      int counterNewFundiFee = (counterNewLaborTotal * 0.05).round();
      int counterFundiReceives =
          counterNewLaborTotal - counterNewFundiFee + oldTransport;
      String fundiId =
          (widget.job['assignedFundiId'] ??
                  widget.job['fundiId'] ??
                  widget.job['assignedFundi'] ??
                  '')
              .toString();
      final uid = FirebaseAuth.instance.currentUser?.uid;

      bool isLowCounter =
          counterExtraLabor == 0 || counterExtraLabor < minAllowed;
      int newRound = currentRound + 1;
      int newLowCount = isLowCounter
          ? previousLowCounters + 1
          : previousLowCounters;
      bool shouldDeadlock = newRound >= 3 && newLowCount >= 2;

      String nextStatus = shouldDeadlock
          ? 'price_review_deadlock'
          : 'renegotiation_countered_by_client';
      String nextRenegStatus = shouldDeadlock
          ? 'deadlock_client_low_counters'
          : 'countered_by_client';

      await FirebaseFirestore.instance.collection('jobs').doc(widget.jobId).update({
        'status': nextStatus,
        'renegotiation.status': nextRenegStatus,
        'renegotiation.counterExtraLabor': counterExtraLabor,
        'renegotiation.counterLabor': counterNewLaborTotal,
        'renegotiation.counterPrice': counterNewLaborTotal,
        'renegotiation.counterClientAppFee': counterExtraFee,
        'renegotiation.counterExtraToLock': counterExtraToLock,
        'renegotiation.counterFundiAppFee': counterExtraFee,
        'renegotiation.counterTotalClientPays': counterNewTotalClientPays,
        'renegotiation.counterTotalCost': counterNewTotalClientPays,
        'renegotiation.counterFundiReceives': counterFundiReceives,
        'renegotiation.counterTransportFee': oldTransport,
        'renegotiation.counterReason': counterReasonCtrl.text,
        'renegotiation.counteredAt': FieldValue.serverTimestamp(),
        'renegotiation.counteredExtraRequested': extraRequested,
        'renegotiation.counterRound': newRound,
        'renegotiation.clientLowCounterCount': newLowCount,
        'renegotiation.isLowCounter': isLowCounter,
        'renegotiation.hasEvidence': hasEvidence,
        'renegotiation.minAllowedWhenVerified': minAllowed,
        'fundiHasUnread': true,
        'customerUnreadType': 'renegotiation_countered',
        'updatedAt': FieldValue.serverTimestamp(),
        if (shouldDeadlock)
          'renegotiation.deadlockedAt': FieldValue.serverTimestamp(),
        if (shouldDeadlock)
          'renegotiation.deadlockReason':
              'Client countered 0 or <30% for $newRound rounds. Fundi to choose continue old price or withdraw with diagnostic fee.',
      });

      try {
        var clientId =
            (widget.job['customerId'] ?? widget.job['clientId'] ?? '')
                .toString();
        if (clientId.isNotEmpty && isLowCounter) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(clientId)
              .set({
                'clientFlags': {
                  'zeroCounterCount': FieldValue.increment(1),
                  'lowCounterCount': FieldValue.increment(1),
                  'lastLowCounterAt': FieldValue.serverTimestamp(),
                  'lastJobId': widget.jobId,
                },
              }, SetOptions(merge: true));
        }
      } catch (_) {}

      if (fundiId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'toUserId': fundiId,
          'toRole': 'fundi',
          'fromUserId': uid,
          'fromRole': 'client',
          'type': shouldDeadlock
              ? 'renegotiation_deadlock'
              : 'renegotiation_counter',
          'jobId': widget.jobId,
          'amount': counterExtraToLock,
          'extraLabor': counterExtraLabor,
          'title': shouldDeadlock
              ? 'Price review deadlocked - Your choice now'
              : 'Client countered extra work',
          'body': shouldDeadlock
              ? 'Client countered low $newRound times. You can continue with old price KES $oldLabor or withdraw with transport + diagnostic fee.'
              : 'Client countered your extra KES $extraRequested with KES $counterExtraLabor',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance
            .collection('fundis')
            .doc(fundiId)
            .collection('notifications')
            .add({
              'jobId': widget.jobId,
              'type': shouldDeadlock
                  ? 'renegotiation_deadlock'
                  : 'renegotiation_counter',
              'amount': counterExtraToLock,
              'extraLabor': counterExtraLabor,
              'createdAt': FieldValue.serverTimestamp(),
              'isRead': false,
            });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Counter sent: KES $counterExtraLabor - waiting for fundi',
          ),
        ),
      );
      Navigator.pop(context);
      if (shouldDeadlock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deadlock after $newRound low counters. Fundi will choose to continue or withdraw with compensation.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Counter sent: KES $counterExtraLabor (you will lock KES $counterExtraToLock) - Round $newRound/3',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}
