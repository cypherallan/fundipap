import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_waiting_card.dart';

class FundiPendingTab extends StatelessWidget {
  final Stream<QuerySnapshot> bidsStream;
  final Future<void> Function(
    DocumentReference bidRef,
    String jobId,
    double price,
  )
  onCounter;
  const FundiPendingTab({
    super.key,
    required this.bidsStream,
    required this.onCounter,
  });

  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: bidsStream,
      builder: (_, snap) {
        if (snap.hasError)
          return Center(child: SelectableText('Error: ${snap.error}'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        var filtered = snap.data!.docs.where((d) {
          var data = d.data() as Map<String, dynamic>;
          return (data['status'] == 'pending' ||
                  data['status'] == 'countered' ||
                  data['status'] == 'bidding' ||
                  data['status'] == 'client_counter') &&
              data['deletedForFundi'] != true;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'No pending offers',
              style: GoogleFonts.inter(color: Colors.black45),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            var bidDoc = filtered[i];
            var bid = bidDoc.data() as Map<String, dynamic>;
            var jobRef = bidDoc.reference.parent.parent!;
            var status = (bid['status'] ?? '').toString();
            var counterBy = (bid['counterBy'] ?? bid['lastCounterBy'] ?? '')
                .toString();
            var lastCounterBy = (bid['lastCounterBy'] ?? counterBy).toString();

            bool isClientCounter =
                (status == 'countered' && lastCounterBy != uid) ||
                status == 'client_counter' ||
                (status == 'countered' && bid['clientCounterAmount'] != null);
            bool isMyCounter = status == 'countered' && lastCounterBy == uid;

            int clientCounterAmt =
                ((bid['clientCounterAmount'] ??
                            bid['lastCounterAmount'] ??
                            bid['lastCounterPrice'] ??
                            bid['counterPrice'] ??
                            bid['clientCounterPrice'] ??
                            bid['price'] ??
                            0)
                        as num)
                    .toInt();
            int myBidPrice = ((bid['price'] ?? 0) as num).toInt();
            int lastAmt =
                ((bid['lastCounterAmount'] ??
                            bid['lastCounterPrice'] ??
                            myBidPrice)
                        as num)
                    .toInt();

            return FutureBuilder<DocumentSnapshot>(
              future: jobRef.get(),
              builder: (_, jobSnap) {
                var job = jobSnap.data?.data() as Map<String, dynamic>?;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isClientCounter
                          ? Colors.orange.shade300
                          : Colors.black12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PENDING • KES ${lastAmt}',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: Colors.amber.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              job?['title'] ?? 'Job',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              job?['location'] ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // CLIENT COUNTERED -> ACTION NEEDED
                      if (isClientCounter) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Client countered: KES $clientCounterAmt (Your bid KES $myBidPrice)',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        await bidDoc.reference.update({
                                          'status': 'rejected',
                                          'rejectedBy': uid,
                                          'rejectedAt':
                                              FieldValue.serverTimestamp(),
                                          'updatedAt':
                                              FieldValue.serverTimestamp(),
                                        });
                                        // notify client
                                        await FirebaseFirestore.instance
                                            .collection('notifications')
                                            .add({
                                              'toUserId':
                                                  job?['clientId'] ??
                                                  job?['customerId'],
                                              'type': 'bid_rejected',
                                              'jobId': jobRef.id,
                                              'bidId': bidDoc.id,
                                              'title': 'Fundi declined counter',
                                              'body':
                                                  'Fundi declined your counter KES $clientCounterAmt',
                                              'isRead': false,
                                              'createdAt':
                                                  FieldValue.serverTimestamp(),
                                            });
                                      },
                                      child: Text(
                                        'Reject',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => onCounter(
                                        bidDoc.reference,
                                        jobRef.id,
                                        clientCounterAmt.toDouble(),
                                      ),
                                      child: Text(
                                        'Counter',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            FundipapColors.greenSuccess,
                                      ),
                                      onPressed: () async {
                                        await bidDoc.reference.update({
                                          'status': 'accepted',
                                          'agreedPrice': clientCounterAmt,
                                          'price': clientCounterAmt,
                                          'lastCounterPrice': clientCounterAmt,
                                          'lastCounterAmount': clientCounterAmt,
                                          'acceptedAt':
                                              FieldValue.serverTimestamp(),
                                          'updatedAt':
                                              FieldValue.serverTimestamp(),
                                        });
                                        await FirebaseFirestore.instance
                                            .collection('jobs')
                                            .doc(jobRef.id)
                                            .update({
                                              'status': 'assigned',
                                              'assignedFundiId': uid,
                                              'agreedPrice': clientCounterAmt,
                                              'price': clientCounterAmt,
                                              'renegotiation': {
                                                'requested': false,
                                              },
                                              'priceHistory':
                                                  FieldValue.arrayUnion([
                                                    {
                                                      'price': clientCounterAmt,
                                                      'by': uid,
                                                      'type':
                                                          'accepted_client_counter',
                                                      'at': DateTime.now()
                                                          .toIso8601String(),
                                                    },
                                                  ]),
                                              'updatedAt':
                                                  FieldValue.serverTimestamp(),
                                            });
                                        await FirebaseFirestore.instance
                                            .collection('notifications')
                                            .add({
                                              'toUserId':
                                                  job?['clientId'] ??
                                                  job?['customerId'],
                                              'type': 'bid_accepted',
                                              'jobId': jobRef.id,
                                              'bidId': bidDoc.id,
                                              'title':
                                                  'Fundi accepted your counter',
                                              'body':
                                                  'Fundi accepted KES $clientCounterAmt • Job assigned',
                                              'isRead': false,
                                              'createdAt':
                                                  FieldValue.serverTimestamp(),
                                            });
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Accepted KES $clientCounterAmt - Job assigned',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text(
                                        'Accept',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ] else if (isMyCounter) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: OrangeAnimatedWaitingCard(
                            title: 'Counter sent • KES $lastAmt',
                            message:
                                'You countered KES $lastAmt. Waiting for client to respond...',
                          ),
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: Text(
                            'Waiting for client to accept your KES $myBidPrice',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
