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
            'agreedPrice': newLabor,
            'laborCost': newLabor,
            'transportFee': oldTransport,
            'clientAppFee': newClientFee,
            'fundiAppFee': newFundiFee,
            'totalClientPays': newTotal,
            'totalCost': newTotal,
            'fundiReceives': newLabor - newFundiFee + oldTransport,
            'extraLaborAmount': extraLabor,
            'extraClientAppFee': extraAppFee,
            'extraEscrowAmount': extraToLock,
            'extraToLock': extraToLock,
            'extraEscrowStatus': 'pending',
            'status': 'awaiting_extra_escrow',
            'renegotiation.status':
                'accepted_client_buys_parts_pending_extra_escrow',
            'renegotiation.whoBuysParts': 'client',
            'renegotiation.currentPhase': 'waiting_for_extra_escrow',
            'renegotiation.extraLabor': extraLabor,
            'renegotiation.extraToLock': extraToLock,
            'renegotiation.acceptedAt': FieldValue.serverTimestamp(),
            'fundiHasUnread': true,
            'customerHasUnread': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
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
      int oldLabor = newLabor - extraLabor;
      int oldClientFee = (oldLabor * 0.05).round();
      int newClientFee = (newLabor * 0.05).round();
      int newFundiFee = (newLabor * 0.05).round();
      int extraAppFee = newClientFee - oldClientFee;
      int extraToLock = extraLabor + extraAppFee;
      int newTotal = alreadyLockedCorrect + extraToLock;
      int newFundiReceives = newLabor - newFundiFee + oldTransport;
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
            'agreedPrice': newLabor,
            'laborCost': newLabor,
            'transportFee': oldTransport,
            'clientAppFee': newClientFee,
            'fundiAppFee': newFundiFee,
            'totalClientPays': newTotal,
            'totalCost': newTotal,
            'fundiReceives': newFundiReceives,
            'extraLaborAmount': extraLabor,
            'extraEscrowAmount': extraToLock,
            'extraToLock': extraToLock,
            'extraEscrowStatus': 'pending',
            'status': 'awaiting_extra_escrow',
            'renegotiation.status':
                'accepted_fundi_buys_at_client_risk_pending_extra_escrow',
            'renegotiation.whoBuysParts': 'fundi',
            'renegotiation.partsPaidTo': 'shop_direct',
            'renegotiation.currentPhase': 'waiting_for_extra_escrow',
            'renegotiation.oldTransportFee': oldTransport,
            'renegotiation.riskAccepted': true,
            'renegotiation.extraLabor': extraLabor,
            'renegotiation.newTotalClientPays': newTotal,
            'renegotiation.extraToLock': extraToLock,
            'renegotiation.acceptedAt': FieldValue.serverTimestamp(),
            'fundiHasUnread': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _payExtraEscrow(
    Map<String, dynamic> job,
    int alreadyLocked,
    int extraToLock,
    String whoBuysVal,
  ) async {
    setState(() => loading = true);
    try {
      // FIX: recompute from DB, don't trust passed alreadyLocked
      int oldTotal = _toInt(
        job['totalCost'] ??
            job['totalClientPays'] ??
            job['escrowAmount'] ??
            alreadyLocked,
      );
      if (oldTotal == 0) oldTotal = alreadyLocked;
      if (alreadyLocked == 0 || alreadyLocked == extraToLock) {
        alreadyLocked = oldTotal; // safety
      }
      // ensure alreadyLocked is at least oldTotal
      if (alreadyLocked < oldTotal) alreadyLocked = oldTotal;

      int newTotal = alreadyLocked + extraToLock;
      // final safety: if newTotal is just 1050, force 5400+1050=6450
      if (newTotal == extraToLock) {
        newTotal = oldTotal + extraToLock;
      }

      String fundiId =
          (job['assignedFundiId'] ??
                  job['fundiId'] ??
                  widget.job['assignedFundiId'] ??
                  '')
              .toString();

      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
            'escrowAmount': newTotal, // 6450 not 1050
            'totalClientPays': newTotal,
            'totalCost': newTotal,
            'extraEscrowStatus': 'paid',
            'escrowStatus': 'held',
            'extraTopupAmount': 0,
            'extraTopupToLock': 0,
            'extraToLock': 0,
            'extraLaborAmount': 0,
            'clientNeedsToTopup': false, // FIX: was true in other flow
            'renegotiation.extraLocked': true,
            'renegotiation.extraLockedAt': FieldValue.serverTimestamp(),
            'renegotiation.extraEscrowPaidAt': FieldValue.serverTimestamp(),
            'status': whoBuysVal == 'client'
                ? 'waiting_for_client_to_buy_parts'
                : 'fundi_buying_parts',
            'renegotiation.status': whoBuysVal == 'client'
                ? 'accepted_client_buys_parts'
                : 'accepted_fundi_buys_at_client_risk',
            'renegotiation.currentPhase': whoBuysVal == 'client'
                ? 'waiting_for_client_to_buy_parts'
                : 'fundi_buying_parts',
            'renegotiation.whoBuysParts': whoBuysVal,
            'fundiHasUnread': true,
            'customerHasUnread': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (fundiId.isNotEmpty) {
        try {
          var q = await FirebaseFirestore.instance
              .collection('fundis')
              .doc(fundiId)
              .collection('notifications')
              .where('jobId', isEqualTo: widget.jobId)
              .get();
          for (var d in q.docs) {
            var t = (d.data()['type'] ?? '').toString();
            if (t == 'awaiting_extra_escrow' ||
                t == 'renegotiation_counter' ||
                t == 'renegotiation_approved') {
              await d.reference.update({'isRead': true});
            }
          }
          await FirebaseFirestore.instance
              .collection('fundis')
              .doc(fundiId)
              .collection('notifications')
              .add({
                'jobId': widget.jobId,
                'type': 'extra_escrow_locked',
                'title': 'Client locked extra KES $extraToLock',
                'isRead': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
        } catch (_) {}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Extra KES $extraToLock locked. Total now KES $newTotal',
          ),
        ),
      );
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
    if (counterPriceCtrl.text.isEmpty) return;
    setState(() => loading = true);
    try {
      int counterExtraLabor = int.tryParse(counterPriceCtrl.text.trim()) ?? 0;
      if (counterExtraLabor <= 0) return;
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
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
            'status': 'renegotiation_countered_by_client',
            'renegotiation.status': 'countered_by_client',
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
            'fundiHasUnread': true,
            'customerHasUnread': true,
            'customerUnreadType': 'renegotiation_countered',
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (fundiId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'toUserId': fundiId,
          'toRole': 'fundi',
          'fromUserId': uid,
          'fromRole': 'client',
          'type': 'renegotiation_counter',
          'jobId': widget.jobId,
          'amount': counterExtraToLock,
          'extraLabor': counterExtraLabor,
          'title': 'Client countered extra work',
          'body':
              'Client countered your extra KES $extraRequested with KES $counterExtraLabor (KES $counterExtraToLock with fee)',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance
            .collection('fundis')
            .doc(fundiId)
            .collection('notifications')
            .add({
              'jobId': widget.jobId,
              'type': 'renegotiation_counter',
              'amount': counterExtraToLock,
              'extraLabor': counterExtraLabor,
              'createdAt': FieldValue.serverTimestamp(),
              'isRead': false,
            });
      }
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Counter sent: KES $counterExtraToLock (labour $counterExtraLabor + fee $counterExtraFee)',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}
