import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

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

  double _toDouble(dynamic v, [double fb = 0]) {
    if (v == null) return fb;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fb;
  }

  Future<void> _acceptClientBuys(
    Map<String, dynamic> job,
    int newLabor,
    int extraLabor,
    int alreadyLocked,
  ) async {
    setState(() => loading = true);
    try {
      int transport = _toInt(
        job['transportFee'] ?? widget.job['transportFee'] ?? 0,
      );
      int newClientFee = (newLabor * 0.05).round();
      int newFundiFee = (newLabor * 0.05).round();
      int newTotal = newLabor + transport + newClientFee;
      int extraToLock = newTotal - alreadyLocked;
      int newFundiReceives = newLabor - newFundiFee + transport;
      if (extraToLock > 0) {
        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .update({
              'agreedPrice': newLabor,
              'laborCost': newLabor,
              'laborPrice': newLabor,
              'transportFee': transport,
              'clientAppFee': newClientFee,
              'fundiAppFee': newFundiFee,
              'totalClientPays': newTotal,
              'totalCost': newTotal,
              'fundiReceives': newFundiReceives,
              'extraLaborAmount': extraLabor,
              'extraClientAppFee': newClientFee - (alreadyLocked > 0 ? 0 : 0),
              'extraEscrowAmount': extraToLock,
              'extraToLock': extraToLock,
              'extraEscrowStatus': 'pending',
              'status': job['status'],
              'renegotiation.status':
                  'accepted_client_buys_parts_pending_extra_escrow',
              'renegotiation.whoBuysParts': 'client',
              'renegotiation.currentPhase': 'waiting_for_extra_escrow',
              'renegotiation.extraLabor': extraLabor,
              'renegotiation.newClientAppFee': newClientFee,
              'renegotiation.newTotalClientPays': newTotal,
              'renegotiation.extraToLock': extraToLock,
              'renegotiation.acceptedAt': FieldValue.serverTimestamp(),
              'fundiHasUnread': true,
              'customerHasUnread': false,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } else {
        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .update({
              'agreedPrice': newLabor,
              'laborCost': newLabor,
              'transportFee': transport,
              'clientAppFee': newClientFee,
              'fundiAppFee': newFundiFee,
              'totalClientPays': newTotal,
              'totalCost': newTotal,
              'fundiReceives': newFundiReceives,
              'status': 'in_progress',
              'renegotiation.status': 'accepted_client_buys_parts',
              'renegotiation.whoBuysParts': 'client',
              'renegotiation.currentPhase': 'waiting_for_client_to_buy_parts',
              'renegotiation.acceptedAt': FieldValue.serverTimestamp(),
              'fundiHasUnread': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        if (!mounted) return;
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _acceptFundiBuysAtRisk(
    Map<String, dynamic> job,
    int newLabor,
    int extraLabor,
  ) async {
    setState(() => loading = true);
    try {
      int transport = _toInt(
        job['transportFee'] ?? widget.job['transportFee'] ?? 0,
      );
      int alreadyLocked = _toInt(job['escrowAmount'] ?? 0);
      int newClientFee = (newLabor * 0.05).round();
      int newFundiFee = (newLabor * 0.05).round();
      int newTotal = newLabor + transport + newClientFee;
      int extraToLock = newTotal - alreadyLocked;
      int newFundiReceives = newLabor - newFundiFee + transport;
      if (extraToLock > 0) {
        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .update({
              'agreedPrice': newLabor,
              'laborCost': newLabor,
              'transportFee': transport,
              'clientAppFee': newClientFee,
              'fundiAppFee': newFundiFee,
              'totalClientPays': newTotal,
              'totalCost': newTotal,
              'fundiReceives': newFundiReceives,
              'extraLaborAmount': extraLabor,
              'extraEscrowAmount': extraToLock,
              'extraToLock': extraToLock,
              'extraEscrowStatus': 'pending',
              'status': job['status'],
              'renegotiation.status':
                  'accepted_fundi_buys_at_client_risk_pending_extra_escrow',
              'renegotiation.whoBuysParts': 'fundi',
              'renegotiation.partsPaidTo': 'shop_direct',
              'renegotiation.currentPhase': 'waiting_for_extra_escrow',
              'renegotiation.riskAccepted': true,
              'renegotiation.extraLabor': extraLabor,
              'renegotiation.newTotalClientPays': newTotal,
              'renegotiation.extraToLock': extraToLock,
              'renegotiation.acceptedAt': FieldValue.serverTimestamp(),
              'fundiHasUnread': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } else {
        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .update({
              'agreedPrice': newLabor,
              'laborCost': newLabor,
              'transportFee': transport,
              'clientAppFee': newClientFee,
              'fundiAppFee': newFundiFee,
              'totalClientPays': newTotal,
              'totalCost': newTotal,
              'fundiReceives': newFundiReceives,
              'status': 'in_progress',
              'renegotiation.status': 'accepted_fundi_buys_at_client_risk',
              'renegotiation.whoBuysParts': 'fundi',
              'renegotiation.partsPaidTo': 'shop_direct',
              'renegotiation.currentPhase': 'fundi_buying_parts',
              'renegotiation.riskAccepted': true,
              'renegotiation.acceptedAt': FieldValue.serverTimestamp(),
              'fundiHasUnread': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        if (!mounted) return;
        Navigator.pop(context);
      }
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
            'status': 'in_progress',
            'renegotiation.status': whoBuysVal == 'client'
                ? 'accepted_client_buys_parts'
                : 'accepted_fundi_buys_at_client_risk',
            'renegotiation.currentPhase': whoBuysVal == 'client'
                ? 'waiting_for_client_to_buy_parts'
                : 'fundi_buying_parts',
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

  Future<void> _counter(int newLabor) async {
    if (counterPriceCtrl.text.isEmpty) return;
    setState(() => loading = true);
    try {
      int counterLabor = int.tryParse(counterPriceCtrl.text) ?? newLabor;
      int transport = _toInt(widget.job['transportFee'] ?? 0);
      int counterClientFee = (counterLabor * 0.05).round();
      int counterFundiFee = (counterLabor * 0.05).round();
      int counterTotal = counterLabor + transport + counterClientFee;
      int counterFundiReceives = counterLabor - counterFundiFee + transport;
      int alreadyLocked = _toInt(
        widget.job['escrowAmount'] ??
            widget.job['totalClientPays'] ??
            widget.job['totalCost'] ??
            0,
      );
      int extraToLock = counterTotal - alreadyLocked;

      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
            'renegotiation.status': 'countered_by_client',
            'renegotiation.counterLabor': counterLabor,
            'renegotiation.counterPrice': counterLabor,
            'renegotiation.counterClientAppFee': counterClientFee,
            'renegotiation.counterFundiAppFee': counterFundiFee,
            'renegotiation.counterTotalClientPays': counterTotal,
            'renegotiation.counterTotalCost': counterTotal,
            'renegotiation.counterFundiReceives': counterFundiReceives,
            'renegotiation.counterTransportFee': transport,
            'renegotiation.counterExtraToLock': extraToLock,
            'renegotiation.counterReason': counterReasonCtrl.text,
            'renegotiation.counteredAt': FieldValue.serverTimestamp(),
            'fundiHasUnread': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Counter sent: KES $counterTotal = $counterLabor + $transport + $counterClientFee (Fundi gets $counterFundiReceives)',
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
          int oldLabor = _toInt(
            reneg['oldLabor'] ??
                reneg['oldPrice'] ??
                job['agreedPrice'] ??
                job['laborCost'] ??
                0,
          );
          int newLabor = _toInt(
            reneg['newLaborTotal'] ?? reneg['newLaborPrice'] ?? 0,
          );
          if (newLabor == 0)
            newLabor = oldLabor + _toInt(reneg['extraLabor'] ?? 0);
          int extraLabor = (newLabor - oldLabor).clamp(0, 9999999);
          int alreadyLocked = _toInt(
            job['escrowAmount'] ??
                job['totalClientPays'] ??
                job['totalCost'] ??
                oldLabor,
          );
          String renegStatus = (reneg['status'] ?? 'pending').toString();
          bool needsExtraEscrow = renegStatus.contains('pending_extra_escrow');
          int transport = _toInt(
            job['transportFee'] ?? widget.job['transportFee'] ?? 0,
          );
          double km = _toDouble(
            job['transportDistanceKm'] ??
                widget.job['transportDistanceKm'] ??
                0,
          );
          String mode =
              (job['transportMode'] ?? widget.job['transportMode'] ?? 'boda')
                  .toString();
          String transportLabel = km > 0
              ? 'Transport ($mode ${km.toStringAsFixed(1)}km)'
              : 'Transport ($mode)';
          int oldClientFee = (oldLabor * 0.05).round();
          int newClientFee = _toInt(
            reneg['newClientAppFee'] ?? (newLabor * 0.05).round(),
          );
          int newFundiFee = (newLabor * 0.05).round();
          int newTotal = _toInt(
            reneg['newTotalClientPays'] ?? newLabor + transport + newClientFee,
          );
          int extraToLock = _toInt(
            reneg['extraToLock'] ?? newTotal - alreadyLocked,
          );
          int fundiReceives = newLabor - newFundiFee + transport;
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
                          'Fundi visited site - new labour KES $newLabor (was $oldLabor). Transport unchanged.',
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
                            'KES $alreadyLocked',
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'New Labour:',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                          Text(
                            'KES $newLabor',
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
                            transportLabel,
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                          Text(
                            'KES $transport',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Old App fee 5%:',
                            style: GoogleFonts.inter(fontSize: 10),
                          ),
                          Text(
                            'KES $oldClientFee',
                            style: GoogleFonts.inter(fontSize: 10),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'New App fee 5% of $newLabor:',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'KES $newClientFee',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'New total to lock:',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'KES $newTotal',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
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
                      Text(
                        'Formula: $newLabor + $transport + $newClientFee = $newTotal | Extra = $newTotal - $alreadyLocked',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        'Fundi will receive: KES $fundiReceives = $newLabor - $newFundiFee + $transport',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                        ),
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
                if (tillNumber.isEmpty && partsNeeded.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      'Fundi will scout shops and send Till after you accept - KES $partsEstimateTotal',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (partsNeeded.isNotEmpty) ...[
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
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Parts Total:',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'KES $partsEstimateTotal',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
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
                          'Lock Extra KES $extraToLock in Escrow',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.red.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'You already locked KES $alreadyLocked. Lock extra KES $extraToLock to reach KES $newTotal (Labour $newLabor + Transport $transport + App $newClientFee) before fundi starts.',
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
                                    alreadyLocked,
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
                                alreadyLocked,
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
                                            'Your labour offer (e.g. 5500)',
                                        helperText:
                                            'We auto add transport $transport + 5%',
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                    if (counterPriceCtrl.text.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Total will be: KES ${(_toInt(counterPriceCtrl.text) + transport + (_toInt(counterPriceCtrl.text) * 0.05).round())} = labour ${_toInt(counterPriceCtrl.text)} + transport $transport + fee ${(_toInt(counterPriceCtrl.text) * 0.05).round()}',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: Colors.green,
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
                                    onPressed: () => _counter(newLabor),
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
                        'Status: ${renegStatus.toUpperCase()} - Total KES $newTotal (Extra KES $extraToLock)',
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
