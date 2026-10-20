import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../data/job_taxonomy.dart';

class TaxonomyService {
  static Future<String> seedAll() async {
    var db = FirebaseFirestore.instance;
    int catCount = 0, subCount = 0, pricingCount = 0;
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
        'subCount': subs.length,
        'active': true,
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
              'active': true,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        subCount++;
        await db.collection('pricingRules').doc('${catId}__${s['id']}').set({
          'categoryId': catId,
          'categoryName': cat['name'],
          'subcategoryId': s['id'],
          'subcategoryName': s['name'],
          'priceMin': s['priceMin'],
          'priceMax': s['priceMax'],
          'priceAvg': ((s['priceMin'] + s['priceMax']) / 2).round(),
          'siteVisitFee': FundiTaxonomy.siteVisitFeeStandard,
          'active': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        pricingCount++;
      }
    }
    return '✅ Done: $catCount cats, $subCount subs, $pricingCount rules';
  }

  static Future<void> clearAll(BuildContext context) async {
    var confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Clear all?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    var db = FirebaseFirestore.instance;
    var cats = await db.collection('jobCategories').get();
    for (var d in cats.docs) {
      var subs = await d.reference.collection('subcategories').get();
      for (var s in subs.docs) await s.reference.delete();
      await d.reference.delete();
    }
    var pricing = await db.collection('pricingRules').get();
    for (var p in pricing.docs) await p.reference.delete();
  }
}
