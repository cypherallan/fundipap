import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/taxonomy_seed_card.dart';

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

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('categories')
                .snapshots(),
            builder: (_, snap) {
              int catCount = snap.data?.docs.length ?? 0;
              int subCount = 0;
              if (snap.hasData) {
                for (var d in snap.data!.docs) {
                  var m = d.data() as Map;
                  subCount += (m['subcategories'] as List?)?.length ?? 0;
                }
              }
              return Row(
                children: [
                  _miniStat('$catCount', 'Categories'),
                  SizedBox(width: 12),
                  _miniStat('$subCount', 'Subcategories'),
                  SizedBox(width: 12),
                  _miniStat(
                    '${catCount == 0 ? "Not seeded" : "Live"}',
                    'Status',
                    green: catCount > 0,
                  ),
                ],
              );
            },
          ),

          SizedBox(height: 24),
          Text(
            'Live Categories',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('categories')
                .orderBy('name')
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData)
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              if (snap.data!.docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 40,
                        color: Colors.black26,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No categories yet',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tap "Seed Taxonomy" above to create them',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: snap.data!.docs.map((doc) {
                  var d = doc.data() as Map;
                  var subs = (d['subcategories'] as List?) ?? [];
                  return Container(
                    margin: EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Color(0xFFFFD60A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.build, size: 20),
                      ),
                      title: Text(
                        d['name'] ?? doc.id,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '${subs.length} subcategories • ${d['pricingMode'] ?? 'market'}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                      trailing: Text(
                        '${subs.length}',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                        ),
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

  Widget _miniStat(String v, String l, {bool green = false}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              v,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: green ? Colors.green : Colors.black,
              ),
            ),
            Text(
              l,
              style: GoogleFonts.inter(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
