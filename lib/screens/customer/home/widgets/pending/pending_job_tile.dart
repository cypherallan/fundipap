import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../theme/app_theme.dart';
import '../../models/customer_home_models.dart';
import '../../helpers/customer_home_utils.dart';
import 'pending_bid_list.dart';
import '../../../post_new_job_screen.dart';

class PendingJobTile extends StatelessWidget {
  final QueryDocumentSnapshot jobDoc;
  final FilterType filter;
  final Position? userPos;

  const PendingJobTile({
    super.key,
    required this.jobDoc,
    required this.filter,
    required this.userPos,
  });

  Future<void> _confirmDelete(BuildContext context, String jobId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Delete Job?',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this job?',
          style: GoogleFonts.inter(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Yes',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      deleteJob(jobId);
    }
  }

  @override
  Widget build(BuildContext context) {
    var job = jobDoc.data() as Map<String, dynamic>;
    var jobId = jobDoc.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: FundipapColors.blackGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                (job['title'] ?? 'J')[0].toUpperCase(),
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          title: Text(
            job['title'] ?? 'Untitled Job',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: FundipapColors.primaryYellow.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'KES ${job['budgetMin'] ?? job['budget'] ?? '-'} - ${job['budgetMax'] ?? ''}',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('jobs')
                      .doc(jobId)
                      .collection('bids')
                      .snapshots(),
                  builder: (_, s) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${s.data?.docs.length ?? 0} bids',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // EDIT + DELETE ICONS INSTEAD OF 3 DOTS
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PostNewJobScreen(jobId: jobId, existingJob: job),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F1F1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_outlined, size: 18),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _confirmDelete(context, jobId),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEAEA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 20),
            ],
          ),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 10),
            PendingBidList(
              jobId: jobId,
              job: job,
              filter: filter,
              userPos: userPos,
            ),
          ],
        ),
      ),
    );
  }
}
