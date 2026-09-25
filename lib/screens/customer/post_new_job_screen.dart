import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/location_service.dart';
import '../../data/job_taxonomy.dart';
import '../../services/dynamic_pricing_service.dart';
import '../../services/pricing_service.dart';

class PostNewJobScreen extends StatefulWidget {
  final String? jobId;
  final Map<String, dynamic>? existingJob;
  const PostNewJobScreen({super.key, this.jobId, this.existingJob});
  @override
  State<PostNewJobScreen> createState() => _PostNewJobScreenState();
}

class _PostNewJobScreenState extends State<PostNewJobScreen> {
  final titleC = TextEditingController();
  final descC = TextEditingController();
  String categoryId = FundiTaxonomy.categories[0]['id'] as String;
  String? subcategoryId;
  String? faultId;
  String serviceFilter = 'all'; // all, install, repair

  List<File> photos = [];
  List<String> existingPhotos = [];
  bool loading = false;
  bool get isEdit => widget.jobId != null;

  Map<String, dynamic> get selectedCategory =>
      FundiTaxonomy.categories.firstWhere(
        (c) => c['id'] == categoryId,
        orElse: () => FundiTaxonomy.categories[0],
      );

  List get allSubcategories => selectedCategory['subcategories'] as List;

  List get filteredSubcategories {
    if (serviceFilter == 'all') return allSubcategories;
    return allSubcategories.where((s) {
      var id = (s['id'] as String).toLowerCase();
      var name = (s['name'] as String).toLowerCase();
      bool isInstall = id.contains('install') || name.contains('install');
      if (serviceFilter == 'install') return isInstall;
      if (serviceFilter == 'repair') return !isInstall;
      return true;
    }).toList();
  }

  Map<String, dynamic>? get selectedSub {
    if (subcategoryId == null) return null;
    try {
      return filteredSubcategories.cast<Map<String, dynamic>>().firstWhere(
        (s) => s['id'] == subcategoryId,
      );
    } catch (_) {
      // fallback to all subcategories for edit mode
      try {
        return allSubcategories.cast<Map<String, dynamic>>().firstWhere(
          (s) => s['id'] == subcategoryId,
        );
      } catch (_) {
        return null;
      }
    }
  }

  List get faults =>
      selectedSub == null ? [] : (selectedSub!['faults'] ?? []) as List;

  int get siteVisitFee => PricingService.getSiteVisitFee(categoryId);

  @override
  void initState() {
    super.initState();
    if (widget.existingJob != null) {
      var j = widget.existingJob!;
      titleC.text = j['title'] ?? '';
      descC.text = j['description'] ?? '';
      categoryId =
          j['categoryId'] ?? j['category'] ?? FundiTaxonomy.categories[0]['id'];
      if (!FundiTaxonomy.categories.any((c) => c['id'] == categoryId)) {
        var match = FundiTaxonomy.categories.firstWhere(
          (c) => c['slug'] == categoryId,
          orElse: () => FundiTaxonomy.categories[0],
        );
        categoryId = match['id'];
      }
      subcategoryId = j['subcategoryId'];
      faultId = j['faultId'];
      existingPhotos = List<String>.from(j['photos'] ?? j['images'] ?? []);
      // auto-detect filter from existing subcategory
      if (subcategoryId != null) {
        var sid = subcategoryId!.toLowerCase();
        if (sid.contains('install'))
          serviceFilter = 'install';
        else if (sid.contains('repair') || sid.contains('_'))
          serviceFilter = 'repair';
      }
    } else {
      var firstSubs = FundiTaxonomy.categories[0]['subcategories'] as List;
      if (firstSubs.isNotEmpty) subcategoryId = firstSubs[0]['id'];
    }
  }

  void _onCategoryChanged(String v) {
    setState(() {
      categoryId = v;
      var subs =
          FundiTaxonomy.categories.firstWhere(
                (cc) => cc['id'] == v,
              )['subcategories']
              as List;
      // apply current filter
      var filtered = subs.where((s) {
        var id = (s['id'] as String).toLowerCase();
        var name = (s['name'] as String).toLowerCase();
        bool isInstall = id.contains('install') || name.contains('install');
        if (serviceFilter == 'install') return isInstall;
        if (serviceFilter == 'repair') return !isInstall;
        return true;
      }).toList();
      if (filtered.isNotEmpty) {
        subcategoryId = filtered[0]['id'] as String;
      } else {
        subcategoryId = subs.isNotEmpty ? subs[0]['id'] as String : null;
        serviceFilter = 'all'; // reset if filter yields empty
      }
      faultId = null;
    });
  }

  void _onFilterChanged(String newFilter) {
    setState(() {
      serviceFilter = newFilter;
      var filtered = filteredSubcategories;
      if (filtered.isNotEmpty) {
        // if current subcategory not in filtered, switch to first filtered
        if (!filtered.any((s) => (s['id'] == subcategoryId))) {
          subcategoryId = filtered[0]['id'] as String;
          faultId = null;
        }
      }
    });
  }

  Future<void> pickPhotos() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() => photos.addAll(picked.map((e) => File(e.path))));
    }
  }

  Future<void> submit() async {
    if (titleC.text.isEmpty || descC.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill title and description')),
      );
      return;
    }
    if (subcategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select service type')));
      return;
    }

    setState(() => loading = true);
    try {
      var uid = FirebaseAuth.instance.currentUser!.uid;
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      var uData = userDoc.data() ?? {};

      var pos = await LocationService.determinePosition(context);
      if (pos == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not get GPS. Enable location and try again.',
              ),
            ),
          );
          setState(() => loading = false);
        }
        return;
      }

      List<String> newUrls = [];
      for (var f in photos) {
        var ref = FirebaseStorage.instance.ref().child(
          'jobs/${uid}_${DateTime.now().millisecondsSinceEpoch}_${f.path.split('/').last}',
        );
        await ref.putFile(f);
        newUrls.add(await ref.getDownloadURL());
      }
      List<String> allPhotos = [...existingPhotos, ...newUrls];

      var cat = selectedCategory;
      var sub = selectedSub;
      var priceInfo = await PricingService.getPriceToShow(
        categoryId: categoryId,
        subcategoryId: subcategoryId!,
        faultId: faultId,
      );

      Map<String, dynamic> jobPayload = {
        'title': titleC.text.trim(),
        'description': descC.text.trim(),
        'categoryId': categoryId,
        'categorySlug': cat['slug'],
        'categoryName': cat['name'],
        'category': cat['slug'],
        'subcategoryId': subcategoryId,
        'subcategoryName': sub?['name'] ?? '',
        'serviceFilter': serviceFilter,
        'isInstallation': (subcategoryId!.toLowerCase().contains('install')),
        'faultId': faultId,
        'faultName': faultId != null
            ? (faults.cast<Map>().firstWhere(
                (ff) => ff['id'] == faultId,
                orElse: () => {"name": faultId},
              )['name'])
            : '',
        // DYNAMIC PRICING FIELDS
        'pricingSource': priceInfo['source'],
        'systemPriceMin': priceInfo['min'],
        'systemPriceMax': priceInfo['max'],
        'systemPriceAvg': priceInfo['avg'],
        'marketAvg': priceInfo['avg'],
        'marketCount': priceInfo['count'],
        'siteVisitFee': siteVisitFee,
        'estimatedTotal': (priceInfo['avg'] as int) + siteVisitFee,
        'pricingVersion': PricingService.version,
        'priceDictatedBy': 'fundi_market',
        'requiresSiteVisit': true,
        // backward compat
        'budget': priceInfo['avg'],
        'offeredPrice': priceInfo['avg'],
        'budgetMin': priceInfo['min'],
        'budgetMax': priceInfo['max'],
        'photos': allPhotos,
        'images': allPhotos,
        'customerLat': pos.latitude,
        'customerLng': pos.longitude,
        'clientLat': pos.latitude,
        'clientLng': pos.longitude,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'clientLocation': GeoPoint(pos.latitude, pos.longitude),
        'customerLocation': GeoPoint(pos.latitude, pos.longitude),
        'locationGeoPoint': GeoPoint(pos.latitude, pos.longitude),
        'location':
            'Kisumu ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isEdit) {
        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .update(jobPayload);
      } else {
        jobPayload.addAll({
          'customerId': uid,
          'clientId': uid,
          'customerName': uData['name'] ?? 'Client',
          'customerUsername': uData['username'] ?? uData['name'] ?? 'Client',
          'clientUsername': uData['username'] ?? uData['name'] ?? 'Client',
          'status': 'open',
          'createdAt': FieldValue.serverTimestamp(),
          'escrowStatus': 'pending',
        });
        await FirebaseFirestore.instance.collection('jobs').add(jobPayload);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Job posted: ${cat['name']} > ${sub?['name']} - ${priceInfo['rangeText']}',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Job' : 'Post Job - Fundi Will Bid Price',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        backgroundColor: FundipapColors.blackGray,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titleC,
              decoration: const InputDecoration(
                labelText:
                    'Job Title e.g TV Mounting Milimani, Dishwasher Install Tom Mboya',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: categoryId,
              isExpanded: true,
              alignment: AlignmentDirectional.centerStart,
              decoration: const InputDecoration(
                labelText: 'Category (24) - All Installations Covered',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: FundiTaxonomy.categories.map((c) {
                bool isTop = c['isTop6'] == true;
                int count = (c['subcategories'] as List).length;
                return DropdownMenuItem(
                  value: c['id'] as String,
                  child: Text(
                    '${isTop ? '⭐ ' : '• '}${c['name']} ($count)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isTop ? FontWeight.w700 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) _onCategoryChanged(v);
              },
            ),
            const SizedBox(height: 12),
            // NEW: Installation / Repair Filter - critical for 180+ services
            Text(
              'Filter Services:',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: FundipapColors.blackGray,
                selectedForegroundColor: Colors.white,
                foregroundColor: Colors.black87,
                backgroundColor: Colors.grey.shade100,
              ),
              segments: const [
                ButtonSegment(
                  value: 'all',
                  label: Text('All'),
                  icon: Icon(Icons.list, size: 16),
                ),
                ButtonSegment(
                  value: 'install',
                  label: Text('Installations'),
                  icon: Icon(Icons.build, size: 16),
                ),
                ButtonSegment(
                  value: 'repair',
                  label: Text('Repairs'),
                  icon: Icon(Icons.handyman, size: 16),
                ),
              ],
              selected: {serviceFilter},
              onSelectionChanged: (Set<String> newSel) {
                _onFilterChanged(newSel.first);
              },
            ),
            const SizedBox(height: 12),
            if (filteredSubcategories.isNotEmpty)
              DropdownButtonFormField<String>(
                value: subcategoryId,
                isExpanded: true,
                alignment: AlignmentDirectional.centerStart,
                decoration: InputDecoration(
                  labelText:
                      'Service Type (${filteredSubcategories.length} in ${serviceFilter.toUpperCase()})',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  helperText: serviceFilter == 'install'
                      ? 'All installation types - TVs, dishwashers, cookers, soundbars, etc.'
                      : null,
                ),
                items: filteredSubcategories.map((s) {
                  var ss = s as Map<String, dynamic>;
                  bool isInstall = (ss['id'] as String).toLowerCase().contains(
                    'install',
                  );
                  return DropdownMenuItem(
                    value: ss['id'] as String,
                    child: Text(
                      '${isInstall ? '🟢' : '🟠'} ${ss['name']}',
                      style: GoogleFonts.inter(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() {
                  subcategoryId = v;
                  faultId = null;
                }),
              ),
            const SizedBox(height: 12),
            if (faults.isNotEmpty)
              DropdownButtonFormField<String>(
                value: faultId,
                isExpanded: true,
                alignment: AlignmentDirectional.centerStart,
                decoration: const InputDecoration(
                  labelText: 'Specific Fault / Detail',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: faults.map((f) {
                  var ff = f as Map<String, dynamic>;
                  return DropdownMenuItem(
                    value: ff['id'] as String,
                    child: Text(
                      ff['name'] as String,
                      style: GoogleFonts.inter(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => faultId = v),
              ),
            if (faults.isNotEmpty) const SizedBox(height: 12),
            TextField(
              controller: descC,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText:
                    'Describe job + what you have tried (e.g. new TV, need wall mount, bricks wall)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // DYNAMIC MARKET PRICE CARD
            if (subcategoryId != null)
              StreamBuilder<DocumentSnapshot>(
                stream: DynamicPricingService.statsStream(
                  categoryId,
                  subcategoryId!,
                  faultId: faultId,
                ),
                builder: (context, snap) {
                  var stats = snap.data?.data() as Map<String, dynamic>?;
                  bool hasMarket = stats != null && (stats['count'] ?? 0) >= 5;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: hasMarket
                          ? Colors.green.shade50
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasMarket
                            ? Colors.green.shade300
                            : Colors.amber.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              hasMarket
                                  ? Icons.analytics
                                  : Icons.lightbulb_outline,
                              size: 18,
                              color: hasMarket
                                  ? Colors.green.shade800
                                  : Colors.black87,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                hasMarket
                                    ? 'Market Average (Fundi Bids)'
                                    : 'System Estimate (Fundis will set real price)',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (stats == null)
                          Text(
                            'No history yet for ${selectedCategory['name']} > ${selectedSub?['name'] ?? ''}. You will be first - fundis will bid and system will learn.',
                            style: GoogleFonts.inter(fontSize: 11),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DynamicPricingService.formatRange(stats),
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Based on ${stats['count']} fundi bids • Min ${stats['min']} • Max ${stats['max']} • Avg ${stats['avg']}',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                              ),
                              if ((stats['count'] ?? 0) < 5)
                                Text(
                                  'Still learning - need ${5 - (stats['count'] as int)} more bids. Showing system estimate for now.',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                            ],
                          ),
                        if (stats == null)
                          FutureBuilder<Map<String, dynamic>>(
                            future: PricingService.getPriceToShow(
                              categoryId: categoryId,
                              subcategoryId: subcategoryId!,
                              faultId: faultId,
                            ),
                            builder: (_, priceSnap) {
                              if (!priceSnap.hasData) return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  priceSnap.data!['rangeText'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.handshake_outlined,
                              size: 14,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Fundi sets price when bidding. You negotiate until mutual price. Extra labor only after site visit + your approval.',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: pickPhotos,
              icon: const Icon(Icons.photo),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                foregroundColor: Colors.black87,
              ),
              label: Text(
                existingPhotos.isEmpty && photos.isEmpty
                    ? 'Add Photos (Optional)'
                    : '${existingPhotos.length + photos.length} photos added - tap to add more',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Photos help fundis bid accurately but not required',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.black54),
            ),
            if (existingPhotos.isNotEmpty || photos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...existingPhotos.map(
                      (url) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: InkWell(
                              onTap: () =>
                                  setState(() => existingPhotos.remove(url)),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...photos.map(
                      (f) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              f,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: InkWell(
                              onTap: () => setState(() => photos.remove(f)),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: loading ? null : submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.blackGray,
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        isEdit
                            ? 'SAVE CHANGES'
                            : 'POST JOB - FUNDIS WILL BID PRICE',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
