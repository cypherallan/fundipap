import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../theme/app_theme.dart';

class ConfirmFundiDetailsSection extends StatelessWidget {
  final Map<String, dynamic> combined;
  const ConfirmFundiDetailsSection({super.key, required this.combined});

  String _getUrl(dynamic e) => e is String ? e : (e['url'] ?? '').toString();
  String _getName(dynamic e) => e is String
      ? e.split('/').last.split('?').first
      : (e['name'] ?? 'File').toString();

  Future<void> _openFile(String url, String name, BuildContext context) async {
    if (url.isEmpty) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$name';
      final localFile = File(filePath);
      if (!await localFile.exists()) {
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.writeToFile(localFile);
      }
      await OpenFilex.open(filePath);
    } catch (_) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => Dialog(child: Image.network(url)),
        );
      }
    }
  }

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
    final fundiId =
        combined['uid'] ?? combined['id'] ?? combined['fundiId'] ?? '';

    var profession = combined['profession'] ?? combined['skill'] ?? 'Fundi';
    var otherSkills = List<String>.from(combined['otherSkills'] ?? []);
    var resumes = List<dynamic>.from(combined['resumes'] ?? []);
    var certs = List<dynamic>.from(combined['certificates'] ?? []);
    var portfolio = List<dynamic>.from(combined['portfolio'] ?? []);

    return StreamBuilder<DocumentSnapshot>(
      stream: fundiId.isNotEmpty
          ? FirebaseFirestore.instance
                .collection('fundis')
                .doc(fundiId)
                .snapshots()
          : null,
      builder: (context, snap) {
        final live = snap.data?.data() as Map<String, dynamic>? ?? {};
        final data = {...combined, ...live};

        var jobsDone =
            [
                  data['jobsCompleted'],
                  data['completedJobs'],
                  data['jobsDone'],
                  data['totalJobs'],
                  data['reviewsCount'],
                ]
                .where((e) => e != null)
                .map((e) => (e as num).toInt())
                .fold<int>(0, (a, b) => max(a, b));

        var ratingRaw =
            data['averageRating'] ??
            data['rating'] ??
            data['avgRating'] ??
            data['average_rating'] ??
            data['ratingAverage'];
        double rating = ratingRaw == null ? 4.5 : (ratingRaw as num).toDouble();

        var fraudRaw =
            data['fraudCount'] ??
            data['fraudCases'] ??
            data['fraud_count'] ??
            data['totalFraud'] ??
            0;
        int fraudCount = (fraudRaw as num).toInt();
        int ratingCount =
            (data['ratingCount'] ??
                    data['reviewsCount'] ??
                    data['totalRatings'] ??
                    0)
                as int;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                statCard('$jobsDone', 'Jobs Done', FundipapColors.greenSuccess),
                const SizedBox(width: 8),
                statCard(
                  '${rating.toStringAsFixed(1)}★',
                  '$ratingCount Ratings',
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
                  (s) => Chip(
                    label: Text(s, style: GoogleFonts.inter(fontSize: 11)),
                  ),
                ),
              ],
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
                  itemBuilder: (_, i) {
                    final url = _getUrl(portfolio[i]);
                    final name = _getName(portfolio[i]);
                    return GestureDetector(
                      onTap: () => _openFile(url, name, context),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(
                            image: NetworkImage(url),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
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
                        label: Text(
                          _getName(u),
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                        onPressed: () =>
                            _openFile(_getUrl(u), _getName(u), context),
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
                    _getName(u),
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => _openFile(_getUrl(u), _getName(u), context),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }
}
