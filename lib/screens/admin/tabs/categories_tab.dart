import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
          FundiMonitorTable(),
          SizedBox(height: 24),
          Text(
            'Live Categories',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('categories')
                .orderBy('name')
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
                        '${(d['subcategories'] as List?)?.length ?? 0} subs • ${d['slug'] ?? ''} • ${d['pricingMode'] ?? 'market'}',
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
