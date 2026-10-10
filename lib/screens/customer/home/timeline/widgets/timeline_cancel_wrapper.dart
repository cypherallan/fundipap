import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/cancel/client_cancel_service.dart';
import '../../../../fundi/services/cancel/fundi_cancel_service.dart';

class TimelineCancelWrapper extends StatelessWidget {
  final Widget child;
  final bool canCancel;
  final String jobId;
  final Map<String, dynamic> job;
  final bool isClient;

  const TimelineCancelWrapper({
    super.key,
    required this.child,
    required this.canCancel,
    required this.jobId,
    required this.job,
    required this.isClient,
  });

  @override
  Widget build(BuildContext context) {
    final status = (job['status'] ?? '').toString().toLowerCase();
    final isCancelled = status.contains('cancel');
    final isCompleted =
        status == 'completed' ||
        status == 'job_completed' ||
        status == 'released';
    if (isCancelled || isCompleted) return child;

    final bool isBlocked = !canCancel;

    return Column(
      children: [
        Expanded(child: child),
        Container(
          padding: EdgeInsets.fromLTRB(
            12,
            8,
            12,
            12 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0x1A000000))),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isBlocked ? Colors.grey.shade400 : Colors.red.shade400,
                ),
                foregroundColor: isBlocked
                    ? Colors.grey.shade600
                    : Colors.red.shade700,
              ),
              onPressed: () {
                if (isBlocked) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(
                        'Cannot cancel now',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      content: Text(
                        'You cannot cancel this job now.',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                } else {
                  if (isClient) {
                    ClientCancelService.showCancelDialog(
                      context: context,
                      jobId: jobId,
                      job: job,
                    );
                  } else {
                    FundiCancelService.showCancelDialog(
                      context: context,
                      jobId: jobId,
                      job: job,
                    );
                  }
                }
              },
              child: Text(
                'CANCEL JOB',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
