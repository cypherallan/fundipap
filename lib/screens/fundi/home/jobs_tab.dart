import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import 'job_list.dart';

class FundiHomeJobsTab extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearchChanged;
  final String mySkill;
  final Map<String, dynamic>? me;
  final int completedJobs;
  final int Function(Map<String, dynamic> job) relevanceScore;
  final Future<void> Function(BuildContext context, Map<String, dynamic> job)
  onBid;
  final dynamic currentPos;

  const FundiHomeJobsTab({
    super.key,
    required this.search,
    required this.onSearchChanged,
    required this.mySkill,
    required this.me,
    required this.completedJobs,
    required this.relevanceScore,
    required this.onBid,
    required this.currentPos,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: onSearchChanged,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search jobs...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              Chip(
                label: Text(
                  'For You: $mySkill',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                backgroundColor: FundipapColors.primaryYellow,
              ),
              Chip(
                label: Text(
                  'Kisumu • 5km',
                  style: GoogleFonts.inter(fontSize: 10),
                ),
                backgroundColor: Colors.white10,
                labelStyle: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Home • Jobs Near You',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Showing $mySkill jobs first',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 12),
          FundiHomeJobList(
            search: search,
            mySkill: mySkill,
            me: me,
            completedJobs: completedJobs,
            relevanceScore: relevanceScore,
            onBid: onBid,
            currentPos: currentPos,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
