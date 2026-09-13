import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ConfirmFundiDetailsSection extends StatelessWidget {
  final Map<String, dynamic> combined;
  const ConfirmFundiDetailsSection({super.key, required this.combined});

  Widget statCard(String value, String label, Color color) {
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

  @override
  Widget build(BuildContext context) {
    var profession = combined['profession'] ?? combined['skill'] ?? 'Fundi';
    var otherSkills = List<String>.from(combined['otherSkills'] ?? []);
    var bio = combined['bio'] ?? 'No bio yet';
    var rating = (combined['rating'] ?? combined['averageRating'] ?? 4.5)
        .toDouble();
    var jobsDone =
        combined['jobsCompleted'] ??
        combined['completedJobs'] ??
        combined['jobsDone'] ??
        combined['jobsDone'] ??
        0;
    var fraudCount = combined['fraudCount'] ?? combined['fraudCases'] ?? 0;
    var resumes = List.from(combined['resumes'] ?? []);
    var certs = List.from(combined['certificates'] ?? []);
    var portfolio = List.from(combined['portfolio'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            statCard('$jobsDone', 'Jobs Done', FundipapColors.greenSuccess),
            const SizedBox(width: 8),
            statCard(
              '${rating.toStringAsFixed(1)}★',
              '${combined['ratingCount'] ?? 0} Ratings',
              Colors.amber.shade700,
            ),
            const SizedBox(width: 8),
            statCard(
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
              (s) =>
                  Chip(label: Text(s, style: GoogleFonts.inter(fontSize: 11))),
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
      ],
    );
  }
}
