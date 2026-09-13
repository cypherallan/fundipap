/*import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class ConfirmFundiPage extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> jobData;
  final String bidId;
  final Map<String, dynamic> bidData;
  const ConfirmFundiPage({
    super.key,
    required this.jobId,
    required this.jobData,
    required this.bidId,
    required this.bidData,
  });
  @override
  State<ConfirmFundiPage> createState() => _ConfirmFundiPageState();
}

class _ConfirmFundiPageState extends State<ConfirmFundiPage> {
  Map<String, dynamic>? fundi;
  Map<String, dynamic>? user;
  bool loading = true;
  final List<String> rejectReasons = [
    'Price too high',
    'Found another fundi with better offer',
    'Poor ratings / fraud cases',
    'Not available quickly',
    'Client cancelled / changed mind',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var fundiId = widget.bidData['fundiId'];
    var fDoc = await FirebaseFirestore.instance
        .collection('fundis')
        .doc(fundiId)
        .get();
    var uDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(fundiId)
        .get();
    setState(() {
      fundi = fDoc.data();
      user = uDoc.data();
      loading = false;
    });
  }

  Future<void> _confirm() async {
    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobId)
        .update({
          'status': 'assigned',
          'assignedFundi': widget.bidData['fundiId'],
          'assignedFundiName': widget.bidData['fundiName'],
          'agreedPrice': widget.bidData['price'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobId)
        .collection('bids')
        .doc(widget.bidId)
        .update({'status': 'accepted'});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.bidData['fundiName']} confirmed!'),
        backgroundColor: FundipapColors.greenSuccess,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _rejectFundi() async {
    String selectedReason = rejectReasons[0];
    final otherCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(
            'Reject ${widget.bidData['fundiName']}?',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedReason,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
                items: rejectReasons
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r, style: GoogleFonts.inter(fontSize: 12)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setSt(() => selectedReason = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: otherCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: selectedReason == 'Other'
                      ? 'Explain reason *'
                      : 'More details (optional)',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FundipapColors.redAlert,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Reject',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobId)
        .collection('bids')
        .doc(widget.bidId)
        .update({
          'status': 'rejected',
          'rejectionCategory': selectedReason,
          'rejectionReason': otherCtrl.text.trim().isEmpty
              ? selectedReason
              : otherCtrl.text.trim(),
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectedBy': FirebaseAuth.instance.currentUser!.uid,
        });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.bidData['fundiName']} rejected'),
        backgroundColor: FundipapColors.redAlert,
      ),
    );
    Navigator.pop(context);
  }

  // <-- FRAUD REPORT - YOUR SNIPPET INTEGRATED HERE
  Future<void> _reportFraud() async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Report ${widget.bidData['fundiName']}',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'e.g. Asked for money upfront and disappeared',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FundipapColors.redAlert,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    var fundiId = widget.bidData['fundiId'];
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var jobId = widget.jobId;
    var reason = reasonCtrl.text.trim();

    await FirebaseFirestore.instance.collection('fraud_reports').add({
      'fundiId': fundiId,
      'clientId': uid,
      'jobId': jobId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance.collection('fundis').doc(fundiId).update({
      'fraudCount': FieldValue.increment(1),
      'fraudCases': FieldValue.increment(1),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report submitted. Admin will review.'),
        backgroundColor: FundipapColors.redAlert,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    var combined = {...?user, ...?fundi, ...widget.bidData};
    var name = combined['name'] ?? widget.bidData['fundiName'];
    var photo = combined['photoUrl'];
    var profession = combined['profession'] ?? combined['skill'] ?? 'Fundi';
    var otherSkills = List<String>.from(combined['otherSkills'] ?? []);
    var bio = combined['bio'] ?? 'No bio yet';
    var rating = (combined['rating'] ?? combined['averageRating'] ?? 4.5)
        .toDouble();
    var jobsDone =
        combined['jobsCompleted'] ??
        combined['completedJobs'] ??
        combined['jobsDone'] ??
        widget.bidData['jobsDone'] ??
        0;
    var fraudCount = combined['fraudCount'] ?? combined['fraudCases'] ?? 0;
    var resumes = List.from(combined['resumes'] ?? []);
    var certs = List.from(combined['certificates'] ?? []);
    var portfolio = List.from(combined['portfolio'] ?? []);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: Text(
          'Review Fundi',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag, color: FundipapColors.redAlert),
            onPressed: _reportFraud,
            tooltip: 'Report Fraud',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        side: const BorderSide(color: FundipapColors.redAlert),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _rejectFundi,
                      child: Text(
                        'REJECT',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          color: FundipapColors.redAlert,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.blackGray,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _confirm,
                      child: Text(
                        'CONFIRM • KES ${widget.bidData['price']}',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _reportFraud,
                icon: const Icon(
                  Icons.flag_outlined,
                  size: 14,
                  color: FundipapColors.redAlert,
                ),
                label: Text(
                  'Report fraud / scam',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: FundipapColors.redAlert,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: FundipapColors.primaryYellow,
                    backgroundImage: photo != null ? NetworkImage(photo) : null,
                    child: photo == null
                        ? Text(
                            name[0].toUpperCase(),
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 4),
                            if (combined['verified'] == true)
                              const Icon(
                                Icons.verified,
                                size: 16,
                                color: FundipapColors.greenSuccess,
                              ),
                          ],
                        ),
                        Text(
                          profession,
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: FundipapColors.blackGray,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bio,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statCard(
                  '${jobsDone}',
                  'Jobs Done',
                  FundipapColors.greenSuccess,
                ),
                const SizedBox(width: 8),
                _statCard(
                  '${rating.toStringAsFixed(1)}★',
                  '${combined['ratingCount'] ?? 0} Ratings',
                  Colors.amber.shade700,
                ),
                const SizedBox(width: 8),
                _statCard(
                  '$fraudCount',
                  'Fraud Cases',
                  fraudCount > 0 ? FundipapColors.redAlert : Colors.black54,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Skills & Experience',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text(
                    profession,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  backgroundColor: FundipapColors.primaryYellow,
                ),
                ...otherSkills.map(
                  (s) => Chip(
                    label: Text(s, style: GoogleFonts.inter(fontSize: 11)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Bio',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(bio, style: GoogleFonts.inter(fontSize: 12)),
            ),
            const SizedBox(height: 16),
            if (portfolio.isNotEmpty) ...[
              Text(
                'Past Work',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: portfolio.length,
                  itemBuilder: (_, i) => Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(
                        image: NetworkImage(portfolio[i]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (certs.isNotEmpty) ...[
              Text(
                'Certificates & Awards',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: certs
                    .map<Widget>(
                      (u) => ActionChip(
                        label: Text('Certificate ${certs.indexOf(u) + 1}'),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => Dialog(child: Image.network(u)),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
            if (resumes.isNotEmpty) ...[
              Text(
                'Resume / CV',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              ...resumes.map(
                (u) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.description),
                  title: Text(
                    'Resume ${resumes.indexOf(u) + 1}',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => Dialog(child: Image.network(u)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FundipapColors.primaryYellow.withOpacity(0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FundipapColors.primaryYellow),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bid for: ${widget.jobData['title']}',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Offered by you: KES ${widget.jobData['budget']}',
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                      Text(
                        'Fundi asks: KES ${widget.bidData['price']}',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Customer Feedbacks',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('fundis')
                  .doc(widget.bidData['fundiId'])
                  .collection('reviews')
                  .orderBy('createdAt', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.data!.docs.isEmpty) {
                  return Text(
                    'No feedbacks yet',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.black45,
                    ),
                  );
                }
                return Column(
                  children: snap.data!.docs.map((d) {
                    var r = d.data() as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            child: Text((r['clientName'] ?? 'C')[0]),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      r['clientName'] ?? 'Client',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${r['rating'] ?? 5}★',
                                      style: GoogleFonts.inter(fontSize: 11),
                                    ),
                                  ],
                                ),
                                Text(
                                  r['comment'] ?? '',
                                  style: GoogleFonts.inter(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
*/
