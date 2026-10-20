import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/job_taxonomy.dart';
import '../widgets/taxonomy_seed_card.dart';
import '../widgets/fundi_monitor_table.dart';

class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaxonomySeedCard(),
          SizedBox(height: 20),
          Text(
            'Top 6 Money Makers',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
          ),
          Wrap(
            spacing: 8,
            children: FundiTaxonomy.categories
                .where((c) => c['isTop6'] == true)
                .map(
                  (c) => Chip(
                    label: Text(
                      c['name'],
                      style: GoogleFonts.inter(fontSize: 10),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 20),
          FundiMonitorTable(),
          SizedBox(height: 24),
          Text(
            'Live Categories',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('jobCategories')
                .orderBy('order')
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) return CircularProgressIndicator();
              return Column(
                children: snap.data!.docs.map((doc) {
                  var d = doc.data() as Map;
                  return Card(
                    child: ListTile(
                      title: Text(
                        d['name'] ?? doc.id,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '${d['subCount'] ?? 0} subs • ${d['slug'] ?? ''}',
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
