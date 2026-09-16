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
  bool acceptedRisk = false;

  Map<String, dynamic> get reneg => widget.job['renegotiation'] ?? {};

  Future<void> _acceptClientBuys() async {
    setState(() => loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
            'agreedPrice': reneg['newLaborTotal'], // labor only!
            'laborPrice': reneg['newLaborTotal'],
            'status': 'confirmed', // KEEP IT IN CONFIRMED
            'renegotiation.status': 'accepted_client_buys_parts',
            'renegotiation.whoBuysParts': 'client',
            'renegotiation.currentPhase': 'waiting_for_client_to_buy_parts',
            'renegotiation.acceptedAt': FieldValue.serverTimestamp(),
            'renegotiation.acceptedBy': 'client',
          });
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _acceptFundiBuysAtRisk() async {
    setState(() => loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
            'agreedPrice': reneg['newLaborTotal'],
            'laborPrice': reneg['newLaborTotal'],
            'status': 'confirmed', // KEEP IT IN CONFIRMED
            'renegotiation.status': 'accepted_fundi_buys_at_client_risk',
            'renegotiation.whoBuysParts': 'fundi',
            'renegotiation.partsPaidTo': 'shop_direct',
            'renegotiation.currentPhase': 'fundi_buying_parts',
            'renegotiation.riskAccepted': true,
            'renegotiation.acceptedAt': FieldValue.serverTimestamp(),
            'renegotiation.acceptedBy': 'client',
          });
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _counter() async {
    if (counterPriceCtrl.text.isEmpty) return;
    setState(() => loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
            'renegotiation.status': 'countered_by_client',
            'renegotiation.counterPrice':
                int.tryParse(counterPriceCtrl.text) ?? reneg['newLaborTotal'],
            'renegotiation.counterReason': counterReasonCtrl.text,
            'renegotiation.counteredAt': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Counter offer sent')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showCounterDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Counter Offer Labor',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Fundi asks Labor KES ${reneg['newLaborTotal']}. What will you offer?',
              style: GoogleFonts.inter(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: counterPriceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Your labor offer KES',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: counterReasonCtrl,
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
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
            onPressed: _counter,
            child: const Text('Send Counter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> reasons = List<String>.from(
      reneg['reasons'] ?? [reneg['reason'] ?? 'Extra work'],
    );
    List<Map<String, dynamic>> partsNeeded = List<Map<String, dynamic>>.from(
      reneg['partsNeeded'] ?? reneg['parts'] ?? [],
    );
    List<String> evidence = List<String>.from(reneg['evidencePhotoUrls'] ?? []);
    List<String> oldParts = List<String>.from(reneg['oldPartPhotoUrls'] ?? []);

    int oldLabor =
        (reneg['oldLabor'] ??
                reneg['oldPrice'] ??
                widget.job['agreedPrice'] ??
                0)
            as int;
    int extraLabor = (reneg['extraLabor'] ?? 0) as int;
    int newLabor =
        (reneg['newLaborTotal'] ??
                reneg['newLaborPrice'] ??
                oldLabor + extraLabor)
            as int;
    String tillNumber = (reneg['tillNumber'] ?? '').toString();

    // SAFE total - handles null, String, int
    int partsEstimateTotal = 0;
    var raw = reneg['partsEstimateTotal'];
    if (raw is int) partsEstimateTotal = raw;
    if (raw is String) partsEstimateTotal = int.tryParse(raw) ?? 0;

    // ALWAYS recalculate from parts if total is 0 or null
    int calculatedTotal = 0;
    for (var p in partsNeeded) {
      // qty can be int or String or null
      int qty = 1;
      if (p['qty'] is int)
        qty = p['qty'];
      else {
        qty = int.tryParse(p['qty'].toString()) ?? 1;
      }

      int price = 0;
      if (p['estPrice'] is int) {
        price = p['estPrice'];
      } else {
        price = int.tryParse(p['estPrice'].toString()) ?? 0;
      }

      calculatedTotal += qty * price;
    }
    if (partsEstimateTotal == 0) partsEstimateTotal = calculatedTotal;

    int pendingExtra = extraLabor;
    int clientPaysToShopDirect = partsEstimateTotal;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Fundi Requests Change',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
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
                      'Fundi visited site - needs extra labor + materials. You control who buys materials.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                      label: Text(r, style: GoogleFonts.inter(fontSize: 10)),
                      backgroundColor: FundipapColors.primaryYellow.withOpacity(
                        0.3,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text(
              'Fundi Explanation:',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                reneg['reasonDetails'] ?? '',
                style: GoogleFonts.inter(fontSize: 12),
              ),
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LABOR ONLY (No parts cost in app)',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Old Labor:',
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                      Text(
                        'KES $oldLabor',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (extraLabor > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '+ Extra Labor:',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                          Text(
                            'KES $extraLabor',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: FundipapColors.blackGray,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'New Labor Total:',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'KES $newLabor',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Parts Needed (${partsNeeded.where((p) => p['name'].toString().trim().isNotEmpty).length} items) - YOU BUY:',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...partsNeeded
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${p['name'] ?? ''} x${p['qty'] ?? 1}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${p['model'] ?? ''}',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Builder(
                                    builder: (_) {
                                      int price = 0;
                                      if (p['estPrice'] is int) {
                                        price = p['estPrice'];
                                      } else {
                                        price =
                                            int.tryParse(
                                              p['estPrice'].toString(),
                                            ) ??
                                            0;
                                      }
                                      if (price == 0) return const SizedBox();
                                      return Text(
                                        'KES $price each',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          color: Colors.black54,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Estimated Parts Total:',
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
                  const SizedBox(height: 8),
                  // TILL LOGIC HERE
                  if (tillNumber.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        '⚠ Fundi will scout shops in your area and send you payment details after you accept "Send fundi"',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.store,
                                size: 16,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Shop Till: $tillNumber',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'KES $partsEstimateTotal to be paid DIRECTLY to shop, NOT to FundiPap escrow',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            if (evidence.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Site Evidence:',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
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
            if (oldParts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Old Damaged Part:',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: oldParts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      oldParts[i],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
            if (reneg['status'] == 'pending') ...[
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
                  'I will buy myself (SAFE - 0% risk)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.green,
                  ),
                ),
                subtitle: Text(
                  'You shop for the part/materials yourself. No Money sent to fundi.',
                  style: GoogleFonts.inter(fontSize: 10),
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
                      ? 'Fundi will find shop in your area first'
                      : 'You send KES $partsEstimateTotal to Till $tillNumber',
                  style: GoogleFonts.inter(fontSize: 10),
                ),
                onChanged: (v) => setState(() => whoBuys = v!),
              ),

              if (whoBuys == 'fundi')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚠ WARNING: If you send fundi money for parts/materials and he disappears, FundiPap is NOT liable. This risk is 100% yours. Fundis can collude with sellers to inflate prices.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      CheckboxListTile(
                        value: acceptedRisk,
                        title: Text(
                          'I understand, risk is entirely mine',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onChanged: (v) => setState(() => acceptedRisk = v!),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                    ],
                  ),
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
                    onPressed: loading ? null : _acceptClientBuys,
                    child: Text(
                      'Accept - I Will Buy Parts (Pay only KES $newLabor labor to FundiPap)',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
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
                    onPressed: (loading || !acceptedRisk)
                        ? null
                        : _acceptFundiBuysAtRisk,
                    child: Text(
                      tillNumber.isEmpty
                          ? 'Accept - Let Fundi Scout Shops'
                          : 'Accept - I will pay KES $clientPaysToShopDirect to Shop Till $tillNumber directly + KES $pendingExtra labor to FundiPap - I Accept Risk',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
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
                      onPressed: _showCounterDialog,
                      child: Text(
                        'Counter Labor',
                        style: GoogleFonts.montserrat(fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('jobs')
                            .doc(widget.jobId)
                            .update({'renegotiation.status': 'rejected'});
                        if (!mounted) return;
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Reject',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: Colors.red,
                        ),
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
                    'Status: ${reneg['status']?.toString().toUpperCase()}',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
