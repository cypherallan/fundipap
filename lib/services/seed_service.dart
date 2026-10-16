import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/job_taxonomy.dart';
import '../services/pricing_service.dart';

Future<void> seedAllTaxonomy(BuildContext context) async {
  var db = FirebaseFirestore.instance;
  int catCount = 0;
  int subCount = 0;

  try {
    for (var cat in FundiTaxonomy.categories) {
      String catId = cat['id'];
      var subs = cat['subcategories'] as List;

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
            }, SetOptions(merge: true));
        subCount++;

        String pricingDocId = '${catId}__${s['id']}';
        await db.collection('pricingRules').doc(pricingDocId).set({
          'categoryId': catId,
          'categoryName': cat['name'],
          'subcategoryId': s['id'],
          'subcategoryName': s['name'],
          'priceMin': s['priceMin'],
          'priceMax': s['priceMax'],
          'siteVisitFee': FundiTaxonomy.siteVisitFeeStandard,
          'pricingVersion': PricingService.version,
          'priceDictatedBy': 'system',
          'active': true,
        }, SetOptions(merge: true));
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Seeded $catCount categories, $subCount subcategories + pricingRules',
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Seed error: $e')));
    }
  }
}
