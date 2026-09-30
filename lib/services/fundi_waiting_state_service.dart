import 'package:cloud_firestore/cloud_firestore.dart';

enum FundiWaitingType {
  bidSent,
  clientCounter,
  myCounter,
  waitingEscrow,
  travelling,
  startSiteVisit,
  none,
}

class FundiWaitingState {
  final FundiWaitingType type;
  final String title; // for timeline orange card
  final String message; // for timeline orange card
  final String notificationCategory; // for home notification
  final int price;
  final bool isCounter;
  const FundiWaitingState({
    required this.type,
    required this.title,
    required this.message,
    required this.notificationCategory,
    required this.price,
    this.isCounter = false,
  });
}

FundiWaitingState? getFundiWaitingState({
  required Map<String, dynamic> job,
  required Map<String, dynamic> bid,
  required List<DocumentSnapshot> counterOffers,
  required String uid,
}) {
  int toInt(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? fb;
  }

  String bidStatus = (bid['status'] ?? '').toString();
  String lastBy = (bid['lastCounterBy'] ?? bid['counterBy'] ?? '').toString();
  bool isClientCounter =
      (bidStatus == 'countered' && lastBy != uid) ||
      bidStatus == 'client_counter';
  bool isMyCounter = bidStatus == 'countered' && lastBy == uid;

  String status = (job['status'] ?? '').toString();
  String escrow = (job['escrowStatus'] ?? 'pending').toString();
  bool escrowDone =
      escrow == 'held' || escrow == 'paid' || escrow == 'released';
  bool siteDone =
      (job['siteVisitDone'] == true) || (job['siteVisited'] == true);
  bool travelling = (job['travelling'] == true) || status == 'travelling';

  int labour = toInt(
    job['laborCost'] ?? job['agreedPrice'] ?? bid['price'] ?? 0,
  );
  int transport = toInt(job['transportFee'] ?? 0);
  int fundiSees = labour + transport;
  int myBid = toInt(bid['price'] ?? 0);
  int clientCounterAmt = toInt(
    bid['lastCounterAmount'] ??
        bid['lastCounterPrice'] ??
        bid['clientCounterAmount'] ??
        0,
  );
  int lastAmt = toInt(
    bid['lastCounterAmount'] ?? bid['lastCounterPrice'] ?? myBid,
  );

  String clientName = (job['clientName'] ?? bid['clientName'] ?? 'Client')
      .toString();

  // Priority 1: client countered you - needs your action
  if (isClientCounter) {
    return FundiWaitingState(
      type: FundiWaitingType.clientCounter,
      title: 'Client countered your labour charges',
      message: '$clientName • Tap to view • Client countered!',
      notificationCategory: 'Client countered your labour charges',
      price: clientCounterAmt,
      isCounter: true,
    );
  }
  // Priority 2: you countered - waiting client
  if (isMyCounter) {
    return FundiWaitingState(
      type: FundiWaitingType.myCounter,
      title: 'You countered • KES $lastAmt - Waiting for client to react',
      message:
          'You countered KES $lastAmt. Waiting for $clientName to accept...',
      notificationCategory:
          'Waiting for $clientName to react to your counter KES $lastAmt',
      price: lastAmt,
    );
  }
  // Priority 3: assigned but escrow not locked
  if (status == 'assigned' && !escrowDone) {
    return FundiWaitingState(
      type: FundiWaitingType.waitingEscrow,
      title: 'Waiting for client to lock KES $fundiSees to escrow',
      message: '$clientName • Tap to view • Waiting to lock escrow',
      notificationCategory:
          'Waiting for $clientName to lock KES $fundiSees to escrow',
      price: fundiSees,
    );
  }
  // Priority 4: bid sent pending
  if (bidStatus == 'pending' || bidStatus == 'bidding') {
    return FundiWaitingState(
      type: FundiWaitingType.bidSent,
      title: 'Bid sent - KES $myBid - Waiting for client to react',
      message: '$clientName • Tap to view • Waiting for client',
      notificationCategory: 'Bid sent - KES $myBid • ${job['title'] ?? ''}',
      price: myBid,
    );
  }
  // Priority 5: escrow done but not started site visit
  if (escrowDone && !siteDone && !travelling) {
    return FundiWaitingState(
      type: FundiWaitingType.startSiteVisit,
      title: 'Escrow locked - KES $fundiSees - Start site visit now',
      message: 'Client locked KES $fundiSees. Start travelling',
      notificationCategory: 'Escrow locked - Start site visit KES $fundiSees',
      price: fundiSees,
    );
  }
  if (travelling) {
    return FundiWaitingState(
      type: FundiWaitingType.travelling,
      title: 'You are on the way',
      message: 'Travelling to client',
      notificationCategory: 'You are on the way to $clientName',
      price: fundiSees,
    );
  }
  return null; // no waiting, all done
}
