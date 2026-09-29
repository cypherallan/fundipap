import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../services/job_cancel_service.dart';

Widget fixedCancelBtn(
  BuildContext context,
  String jobId,
  Map<String, dynamic> job,
) {
  return Container(
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
          side: BorderSide(color: Colors.red.shade400),
          foregroundColor: Colors.red.shade700,
        ),
        onPressed: () => JobCancelService.showCancelDialog(
          context: context,
          jobId: jobId,
          job: job,
          isClient: false,
        ),
        child: Text(
          'CANCEL JOB',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    ),
  );
}
