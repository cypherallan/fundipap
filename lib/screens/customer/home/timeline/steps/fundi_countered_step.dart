import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/timeline_card.dart';
import '../timeline_context.dart';

class FundiCounteredSteps {
  static bool handle(List<Widget> t, TimelineContext c) {
    final lastRole = (c.job['lastCounterByRole'] ?? '').toString();
    final status = c.status.toLowerCase();
    if (status != 'countered' || lastRole != 'fundi') return false;

    final lastAmt = (c.job['lastCounterAmount'] ?? c.labour).toString();
    final prevAmt = (c.job['clientCounterAmount'] ?? '').toString();

    t.add(
      TimelineCard(
        title: prevAmt.isNotEmpty
            ? 'Fundi countered KES $prevAmt with KES $lastAmt'
            : 'Fundi countered - KES $lastAmt',
        body:
            '${c.fundiNameStr} countered your offer. Accept KES $lastAmt or counter again.',
        icon: Icons.compare_arrows,
        isDone: false,
        action: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final jobRef = FirebaseFirestore.instance
                      .collection('jobs')
                      .doc(c.jobId);
                  final bids = await jobRef
                      .collection('bids')
                      .where('status', whereIn: ['countered', 'pending'])
                      .get();
                  for (var b in bids.docs) {
                    await b.reference.update({
                      'status': 'accepted',
                      'agreedPrice': int.tryParse(lastAmt) ?? c.labour,
                    });
                  }
                  await jobRef.update({
                    'status': 'assigned',
                    'agreedPrice': int.tryParse(lastAmt) ?? c.labour,
                    'currentLabour': int.tryParse(lastAmt) ?? c.labour,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                },
                child: Text('Accept KES $lastAmt'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  final ctrl = TextEditingController();
                  showDialog(
                    context: c.context,
                    builder: (_) => AlertDialog(
                      title: const Text('Counter fundi'),
                      content: TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Your offer',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c.context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final v = int.tryParse(ctrl.text);
                            if (v == null) return;
                            await FirebaseFirestore.instance
                                .collection('jobs')
                                .doc(c.jobId)
                                .update({
                                  'status': 'countered',
                                  'lastCounterByRole': 'client',
                                  'lastCounterAmount': v,
                                  'clientCounterAmount': v,
                                  'priceHistory': FieldValue.arrayUnion([
                                    {
                                      'price': v,
                                      'by': 'client',
                                      'type': 'counter',
                                      'at': DateTime.now().toIso8601String(),
                                    },
                                  ]),
                                });
                            if (c.context.mounted) Navigator.pop(c.context);
                          },
                          child: const Text('Counter'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Counter offer'),
              ),
            ),
          ],
        ),
      ),
    );
    return true; // stop timeline here, show only this
  }
}
