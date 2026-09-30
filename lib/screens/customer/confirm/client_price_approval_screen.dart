import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClientPriceApprovalScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> job;
  const ClientPriceApprovalScreen({
    super.key,
    required this.jobId,
    required this.job,
  });
  @override
  State<ClientPriceApprovalScreen> createState() =>
      _ClientPriceApprovalScreenState();
}

class _ClientPriceApprovalScreenState extends State<ClientPriceApprovalScreen> {
  final counterPriceCtrl = TextEditingController();
  final counterReasonCtrl = TextEditingController();
  bool loading = false;
  String whoBuys = 'client';

  int _toInt(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fb;
  }

  bool _toBool(dynamic v, [bool fb = false]) {
    if (v == null) return fb;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) return v.toLowerCase() == 'true' || v == '1';
    return fb;
  }

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
      int extraAppFee = newClientFee - oldClientFee;
      int extraToLock = extraLabor + extraAppFee;
      int newTotal = alreadyLockedCorrect + extraToLock;
      int newFundiReceives = newLabor - newFundiFee + oldTransport;

      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
            'agreedPrice': newLabor,
            'laborCost': newLabor,
            'laborPrice': newLabor,
            'transportFee': oldTransport,
            'clientAppFee': newClientFee,
            'fundiAppFee': newFundiFee,
            'totalClientPays': newTotal,
            'totalCost': newTotal,
            'fundiReceives': newFundiReceives,
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
            'renegotiation.oldTransportFee': oldTransport,
            'renegotiation.extraLabor': extraLabor,
            'renegotiation.newClientAppFee': newClientFee,
            'renegotiation.newTotalClientPays': newTotal,
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
    int alreadyLocked,
    int extraToLock,
    String whoBuysVal,
  ) async {
    setState(() => loading = true);
    try {
      int newTotal = alreadyLocked + extraToLock;
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
            'escrowAmount': newTotal,
            'extraEscrowStatus': 'paid',
            'escrowStatus': 'held',
            'status': whoBuysVal == 'client'
                ? 'waiting_for_client_to_buy_parts'
                : 'fundi_buying_parts',
            'renegotiation.status': whoBuysVal == 'client'
                ? 'accepted_client_buys_parts'
                : 'accepted_fundi_buys_at_client_risk',
            'renegotiation.currentPhase': whoBuysVal == 'client'
                ? 'waiting_for_client_to_buy_parts'
                : 'fundi_buying_parts',
            'renegotiation.whoBuysParts': whoBuysVal, // FIX: keep who buys
            'renegotiation.extraToLock': extraToLock,
            'renegotiation.extraEscrowPaidAt': FieldValue.serverTimestamp(),
            'fundiHasUnread': true,
            'customerHasUnread': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Fundi Requests Change',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          var job = snap.data!.data() as Map<String, dynamic>;
          var reneg = (job['renegotiation'] as Map<String, dynamic>?) ?? {};
          String renegStatus = (reneg['status'] ?? 'pending').toString();

          int oldLabor = _toInt(
            reneg['oldLabor'] ??
                reneg['oldPrice'] ??
                job['agreedPrice'] ??
                job['laborCost'] ??
                0,
          );
          int newLaborRaw = _toInt(
            reneg['newLaborTotal'] ?? reneg['newLaborPrice'] ?? 0,
          );
          if (newLaborRaw == 0)
            newLaborRaw = oldLabor + _toInt(reneg['extraLabor'] ?? 0);

          int acceptedCounterLabour = _toInt(
            reneg['acceptedCounterExtraLabor'] ??
                reneg['approvedExtra'] ?? // <- fundi accept saves this
                reneg['counterExtraLabor'] ??
                0,
          );
          int acceptedCounterToLock = _toInt(
            reneg['acceptedCounterExtraToLock'] ??
                reneg['approvedExtraToLock'] ??
                reneg['counterExtraToLock'] ??
                0,
          );
          bool isCounterAccepted =
              acceptedCounterLabour > 0 &&
              (renegStatus == 'approved' ||
                  renegStatus.contains('approved') ||
                  acceptedCounterToLock > 0);

          int newLabor = isCounterAccepted
              ? oldLabor + acceptedCounterLabour
              : newLaborRaw;
          int extraLabor = isCounterAccepted
              ? acceptedCounterLabour
              : (newLabor - oldLabor).clamp(0, 9999999);

          int oldTransport = _toInt(
            reneg['oldTransportFee'] ??
                widget.job['transportFee'] ??
                job['transportFee'] ??
                0,
          );
          int oldClientFee = (oldLabor * 0.05).round();
          int newClientFee = _toInt(
            reneg['newClientAppFee'] ?? (newLabor * 0.05).round(),
          );
          int extraAppFee = (newClientFee - oldClientFee).clamp(0, 999999);
          if (isCounterAccepted) {
            extraAppFee = _toInt(
              reneg['acceptedCounterExtraAppFee'] ??
                  reneg['counterExtraAppFee'] ??
                  extraAppFee,
            );
          }
          int alreadyLockedCorrect = oldLabor + oldTransport + oldClientFee;
          int extraToLock = extraLabor + extraAppFee;
          int newTotal = alreadyLockedCorrect + extraToLock;

          bool needsExtraEscrow =
              renegStatus.contains('pending_extra_escrow') ||
              renegStatus == 'approved' ||
              renegStatus == 'approved_pending_extra_escrow' ||
              _toBool(job['clientNeedsToTopup']);

          List<String> reasons = List<String>.from(
            reneg['reasons'] ?? [reneg['reason'] ?? 'Extra work'],
          );
          String tillNumber = (reneg['tillNumber'] ?? '').toString();
          List<Map<String, dynamic>> partsNeeded =
              List<Map<String, dynamic>>.from(
                reneg['partsNeeded'] ?? reneg['parts'] ?? [],
              );
          List<String> evidence = List<String>.from(
            reneg['evidencePhotoUrls'] ?? [],
          );
          int partsEstimateTotal = _toInt(reneg['partsEstimateTotal']);
          int calc = 0;
          for (var p in partsNeeded)
            calc += _toInt(p['qty'], 1) * _toInt(p['estPrice']);
          if (partsEstimateTotal == 0) partsEstimateTotal = calc;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Fundi visited site - new labour KES $newLabor (was $oldLabor). Transport KES $oldTransport unchanged.',
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Already locked:',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                          Text(
                            'KES $alreadyLockedCorrect',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Old Labour:',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                          Text(
                            'KES $oldLabor',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                        ],
                      ),
                      if (oldTransport > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Transport:',
                              style: GoogleFonts.inter(fontSize: 11),
                            ),
                            Text(
                              'KES $oldTransport',
                              style: GoogleFonts.inter(fontSize: 11),
                            ),
                          ],
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Extra Labour Requested:',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                          Text(
                            'KES $extraLabor',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'New App Maintenance Cost (5%):',
                            style: GoogleFonts.inter(fontSize: 10),
                          ),
                          Text(
                            'KES $extraAppFee',
                            style: GoogleFonts.inter(fontSize: 10),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Extra to lock now:',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: Colors.red,
                            ),
                          ),
                          Text(
                            'KES $extraToLock',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Reasons',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: reasons
                      .map(
                        (r) => Chip(
                          label: Text(
                            r,
                            style: GoogleFonts.inter(fontSize: 10),
                          ),
                          backgroundColor: FundipapColors.primaryYellow
                              .withOpacity(0.3),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                if (tillNumber.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.store, size: 16, color: Colors.blue),
                        const SizedBox(width: 6),
                        Text(
                          'Shop Till: $tillNumber',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'KES $partsEstimateTotal direct to shop',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (partsNeeded.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Parts Needed (${partsNeeded.length})',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...partsNeeded.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${p['name'] ?? ''} x${p['qty'] ?? 1} - KES ${_toInt(p['estPrice'])}',
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                    ),
                  ),
                ],
                if (evidence.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: evidence.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          evidence[i],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (needsExtraEscrow) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.lock, color: Colors.red.shade700, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          isCounterAccepted
                              ? 'Fundi accepted your counter KES $acceptedCounterLabour - Lock Extra KES $extraToLock'
                              : 'Lock Extra KES $extraToLock in Escrow',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.red.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isCounterAccepted
                              ? 'Fundi accepted your counter of KES $acceptedCounterLabour (was KES ${_toInt(reneg['extraLabor'] ?? extraLabor)}). You already locked KES $alreadyLockedCorrect. Lock extra KES $extraToLock to reach KES $newTotal before fundi starts.'
                              : 'You already locked KES $alreadyLockedCorrect. Lock extra KES $extraToLock to reach KES $newTotal before fundi starts.',
                          style: GoogleFonts.inter(fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 52),
                            ),
                            onPressed: loading
                                ? null
                                : () => _payExtraEscrow(
                                    alreadyLockedCorrect,
                                    extraToLock,
                                    whoBuys,
                                  ),
                            child: Text(
                              loading
                                  ? 'Processing...'
                                  : 'LOCK KES $extraToLock NOW',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (renegStatus == 'pending') ...[
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
                          'Accept - Pay extra KES $extraToLock to escrow + Buy parts yourself\nTotal will be KES $newTotal',
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
                          'Accept - Lock KES $extraToLock + Pay shop\nTotal KES $newTotal',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text(
                                  'Counter Offer - Enter Labour Only',
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: counterPriceCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText:
                                            'Your extra labour offer (e.g. 1000)',
                                        helperText:
                                            'Extra + 5% = total extra to lock. Transport already locked',
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    if (counterPriceCtrl.text.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Extra to lock: KES ${_toInt(counterPriceCtrl.text) + (_toInt(counterPriceCtrl.text) * 0.05).round()}',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: Colors.green,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
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
                      const SizedBox(width: 10),
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
                ] else
                  Container(
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
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
