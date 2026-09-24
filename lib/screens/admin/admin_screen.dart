import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../data/job_taxonomy.dart';
import '../../services/pricing_service.dart';
import '../auth/role_select_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool seeding = false;
  String seedLog = '';

  Future<void> seedAllTaxonomy() async {
    setState(() {
      seeding = true;
      seedLog = 'Seeding 24 categories...';
    });
    var db = FirebaseFirestore.instance;
    int catCount = 0;
    int subCount = 0;
    int pricingCount = 0;

    try {
      for (var cat in FundiTaxonomy.categories) {
        String catId = cat['id'];
        var subs = cat['subcategories'] as List;

        // 1. Category doc
        await db.collection('jobCategories').doc(catId).set({
          'name': cat['name'],
          'slug': cat['slug'],
          'sw': cat['sw'] ?? '',
          'icon': cat['icon'],
          'order': cat['order'],
          'isTop6': cat['isTop6'] ?? false,
          'description': cat['desc'] ?? '',
          'subCount': subs.length,
          'active': true,
          'priceDictatedBy': 'system',
          'requiresSiteVisit': true,
          'siteVisitFee': FundiTaxonomy.siteVisitFeeStandard,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        catCount++;

        // 2. Subcategories + pricingRules
        for (var sub in subs) {
          var s = sub as Map<String, dynamic>;
          await db
              .collection('jobCategories')
              .doc(catId)
              .collection('subcategories')
              .doc(s['id'])
              .set({
                'name': s['name'],
                'priceMin': s['priceMin'],
                'priceMax': s['priceMax'],
                'priceAvg': ((s['priceMin'] + s['priceMax']) / 2).round(),
                'faults': s['faults'] ?? [],
                'faultCount': (s['faults'] as List?)?.length ?? 0,
                'active': true,
                'siteVisitFee': FundiTaxonomy.siteVisitFeeStandard,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
          subCount++;

          String pricingDocId = '${catId}__${s['id']}';
          await db.collection('pricingRules').doc(pricingDocId).set({
            'categoryId': catId,
            'categoryName': cat['name'],
            'categorySlug': cat['slug'],
            'subcategoryId': s['id'],
            'subcategoryName': s['name'],
            'priceMin': s['priceMin'],
            'priceMax': s['priceMax'],
            'priceAvg': ((s['priceMin'] + s['priceMax']) / 2).round(),
            'siteVisitFee': FundiTaxonomy.siteVisitFeeStandard,
            'siteVisitFeeOther': FundiTaxonomy.siteVisitFeeOther,
            'currency': 'KES',
            'pricingVersion': PricingService.version,
            'priceDictatedBy': 'system', // SYSTEM DICTATES, NOT CLIENT/FUNDI
            'requiresSiteVisit': true,
            'maxExtraPercent': 100,
            'commissionPercent': PricingService.commissionPercent,
            'active': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          pricingCount++;
        }
      }

      setState(() {
        seedLog =
            '✅ Done: $catCount categories, $subCount subcategories, $pricingCount pricingRules';
        seeding = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(seedLog),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      setState(() {
        seedLog = '❌ Error: $e';
        seeding = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(seedLog), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> clearAllTaxonomy() async {
    var confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all categories?'),
        content: const Text(
          'This will delete jobCategories and pricingRules. Use only if you want to re-seed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      seeding = true;
      seedLog = 'Clearing...';
    });
    var db = FirebaseFirestore.instance;
    var cats = await db.collection('jobCategories').get();
    for (var d in cats.docs) {
      var subs = await d.reference.collection('subcategories').get();
      for (var s in subs.docs) {
        await s.reference.delete();
      }
      await d.reference.delete();
    }
    var pricing = await db.collection('pricingRules').get();
    for (var p in pricing.docs) {
      await p.reference.delete();
    }
    setState(() {
      seeding = false;
      seedLog = 'Cleared all taxonomy';
    });
  }

  @override
  Widget build(BuildContext context) {
    final fundis = [
      {'name': 'Otieno Wireman', 'partsRate': 85, 'extraAvg': 650},
      {'name': 'Akinyi Plumber', 'partsRate': 25, 'extraAvg': 120},
      {'name': 'Omondi Painter', 'partsRate': 45, 'extraAvg': 300},
      {'name': 'Atieno Mason', 'partsRate': 75, 'extraAvg': 800},
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Use 3 dots menu to Logout')),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'FundiPap Admin - 24 Categories',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          backgroundColor: FundipapColors.blackGray,
          foregroundColor: Colors.white,
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'logout') {
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                    (r) => false,
                  );
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        // ... rest of body same
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === SEED CONTROLS ===
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.category, color: Colors.black87),
                        const SizedBox(width: 8),
                        Text(
                          '24 CATEGORIES TAXONOMY - SYSTEM PRICING',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rule: Client & Fundi NEVER dictate price. System dictates via pricingRules. Site visit KES ${FundiTaxonomy.siteVisitFeeStandard} mandatory.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          icon: seeding
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.cloud_upload,
                                  color: Colors.white,
                                ),
                          label: Text(
                            seeding
                                ? 'Seeding...'
                                : 'SEED 24 CATEGORIES + PRICING',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FundipapColors.blackGray,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onPressed: seeding ? null : seedAllTaxonomy,
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete_forever, size: 18),
                          label: const Text(
                            'CLEAR ALL',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          onPressed: seeding ? null : clearAllTaxonomy,
                        ),
                      ],
                    ),
                    if (seedLog.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Text(
                          seedLog,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Live count from Firestore
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('jobCategories')
                          .snapshots(),
                      builder: (_, snap) {
                        if (!snap.hasData) {
                          return Text(
                            'Loading categories...',
                            style: GoogleFonts.inter(fontSize: 11),
                          );
                        }
                        int count = snap.data!.docs.length;
                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: count == 24
                                    ? Colors.green
                                    : Colors.orange,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$count / 24 Categories in DB',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('pricingRules')
                                  .snapshots(),
                              builder: (_, pSnap) {
                                int pCount = pSnap.hasData
                                    ? pSnap.data!.docs.length
                                    : 0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$pCount pricingRules',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Text(
                'Top 6 Money Makers (80% jobs Kisumu/Nairobi)',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: FundiTaxonomy.categories
                    .where((c) => c['isTop6'] == true)
                    .map(
                      (c) => Chip(
                        label: Text(
                          c['name'],
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: Colors.green.shade50,
                        side: BorderSide(color: Colors.green.shade200),
                      ),
                    )
                    .toList(),
              ),

              const SizedBox(height: 20),
              Text(
                'Fundi Parts Request Monitoring',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'RED >70% parts request = fundi avoids buying, pushes to client. GREEN <30% = good fundi who buys parts.',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FundipapColors.blackGray,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'FUNDI',
                              style: GoogleFonts.montserrat(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'PARTS REQ RATE',
                              style: GoogleFonts.montserrat(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'EXTRA AVG',
                              style: GoogleFonts.montserrat(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'STATUS',
                              style: GoogleFonts.montserrat(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...fundis.map((f) {
                      int rate = f['partsRate'] as int;
                      Color statusColor = rate > 70
                          ? FundipapColors.redAlert
                          : (rate < 30
                                ? FundipapColors.greenSuccess
                                : FundipapColors.primaryYellow);
                      String statusText = rate > 70
                          ? 'RED >70%'
                          : (rate < 30 ? 'GREEN <30%' : 'YELLOW');
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.black12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                f['name'] as String,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '$rate%',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'KES ${f['extraAvg']}',
                                style: GoogleFonts.inter(fontSize: 13),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  statusText,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Text(
                'Live Categories in Firestore',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('jobCategories')
                    .orderBy('order')
                    .snapshots(),
                builder: (_, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.data!.docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'No categories yet. Click SEED button above.',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    );
                  }
                  return Column(
                    children: snap.data!.docs.map((doc) {
                      var d = doc.data() as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              '${d['order'] ?? ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          title: Text(
                            d['name'] ?? doc.id,
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            '${d['subCount'] ?? 0} subcategories • ${d['slug'] ?? ''} • Site fee KES ${d['siteVisitFee'] ?? 500}',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (d['isTop6'] == true)
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              (d['isTop6'] == true) ? 'TOP 6' : 'OTHER 18',
                              style: GoogleFonts.montserrat(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
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
        ),
      ),
    );
  }
}
