import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../data/job_taxonomy.dart';
import '../../../services/pricing_service.dart';
import 'category_selection_section.dart';
import 'photos_section.dart';
import '../services/post_job_service.dart';

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
  final searchC = TextEditingController();

  String searchQuery = '';
  String categoryId = FundiTaxonomy.categories[0]['id'] as String;
  String? subcategoryId;
  String? faultId;
  String serviceFilter = 'all';

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
      final id = (s['id'] as String).toLowerCase();
      final name = (s['name'] as String).toLowerCase();
      final isInstall = id.contains('install') || name.contains('install');
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

  List<Map<String, dynamic>> get searchResults {
    if (searchQuery.trim().isEmpty) return [];
    final q = searchQuery.toLowerCase();
    final List<Map<String, dynamic>> res = [];
    for (final cat in FundiTaxonomy.categories) {
      for (final sub in cat['subcategories'] as List) {
        final subMap = sub as Map<String, dynamic>;
        final subName = (subMap['name'] as String).toLowerCase();
        final catName = (cat['name'] as String).toLowerCase();
        if (subName.contains(q) || catName.contains(q)) {
          res.add({
            'categoryId': cat['id'],
            'categoryName': cat['name'],
            'subcategoryId': subMap['id'],
            'subcategoryName': subMap['name'],
          });
        }
      }
    }
    return res.take(8).toList();
  }

  void _selectFromSearch(Map<String, dynamic> r) {
    setState(() {
      categoryId = r['categoryId'] as String;
      subcategoryId = r['subcategoryId'] as String;
      faultId = null;
      searchQuery = '';
      searchC.clear();
      final sid = subcategoryId!.toLowerCase();
      serviceFilter = sid.contains('install') ? 'install' : 'repair';
    });
  }

  @override
  void dispose() {
    titleC.dispose();
    descC.dispose();
    searchC.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.existingJob != null) {
      final j = widget.existingJob!;
      titleC.text = j['title'] ?? '';
      descC.text = j['description'] ?? '';
      categoryId =
          j['categoryId'] ?? j['category'] ?? FundiTaxonomy.categories[0]['id'];
      if (!FundiTaxonomy.categories.any((c) => c['id'] == categoryId)) {
        final match = FundiTaxonomy.categories.firstWhere(
          (c) => c['slug'] == categoryId,
          orElse: () => FundiTaxonomy.categories[0],
        );
        categoryId = match['id'];
      }
      subcategoryId = j['subcategoryId'];
      faultId = j['faultId'];
      existingPhotos = List<String>.from(j['photos'] ?? j['images'] ?? []);
      if (subcategoryId != null) {
        final sid = subcategoryId!.toLowerCase();
        if (sid.contains('install')) {
          serviceFilter = 'install';
        } else if (sid.contains('repair') || sid.contains('_')) {
          serviceFilter = 'repair';
        }
      }
    } else {
      final firstSubs = FundiTaxonomy.categories[0]['subcategories'] as List;
      if (firstSubs.isNotEmpty) subcategoryId = firstSubs[0]['id'];
    }
  }

  void _onCategoryChanged(String v) {
    setState(() {
      categoryId = v;
      final subs =
          FundiTaxonomy.categories.firstWhere(
                (cc) => cc['id'] == v,
              )['subcategories']
              as List;
      final filtered = subs.where((s) {
        final id = (s['id'] as String).toLowerCase();
        final name = (s['name'] as String).toLowerCase();
        final isInstall = id.contains('install') || name.contains('install');
        if (serviceFilter == 'install') return isInstall;
        if (serviceFilter == 'repair') return !isInstall;
        return true;
      }).toList();
      if (filtered.isNotEmpty) {
        subcategoryId = filtered[0]['id'] as String;
      } else {
        subcategoryId = subs.isNotEmpty ? subs[0]['id'] as String : null;
        serviceFilter = 'all';
      }
      faultId = null;
    });
  }

  void _onFilterChanged(String newFilter) {
    setState(() {
      serviceFilter = newFilter;
      final filtered = filteredSubcategories;
      if (filtered.isNotEmpty) {
        if (!filtered.any((s) => s['id'] == subcategoryId)) {
          subcategoryId = filtered[0]['id'] as String;
          faultId = null;
        }
      }
    });
  }

  Future<void> _pickPhotos() async {
    await PhotosSection.showPhotoSourceSheet(
      context: context,
      onPhotoAdded: (file) => setState(() => photos.add(file)),
      onPhotosAdded: (files) => setState(() => photos.addAll(files)),
    );
  }

  Future<void> _submit() async {
    setState(() => loading = true);
    try {
      await PostJobService.submit(
        context: context,
        isEdit: isEdit,
        jobId: widget.jobId,
        title: titleC.text,
        description: descC.text,
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        faultId: faultId,
        serviceFilter: serviceFilter,
        photos: photos,
        existingPhotos: existingPhotos,
        selectedCategory: selectedCategory,
        selectedSub: selectedSub,
        faults: faults,
        siteVisitFee: siteVisitFee,
      );
    } catch (_) {
      // error already shown in service
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
            CategorySelectionSection(
              searchController: searchC,
              searchQuery: searchQuery,
              onSearchChanged: (v) => setState(() => searchQuery = v),
              onClearSearch: () => setState(() {
                searchQuery = '';
                searchC.clear();
              }),
              searchResults: searchResults,
              onSelectFromSearch: _selectFromSearch,
              categoryId: categoryId,
              subcategoryId: subcategoryId,
              faultId: faultId,
              serviceFilter: serviceFilter,
              filteredSubcategories: filteredSubcategories,
              faults: faults,
              onCategoryChanged: _onCategoryChanged,
              onFilterChanged: _onFilterChanged,
              onSubcategoryChanged: (v) => setState(() {
                subcategoryId = v;
                faultId = null;
              }),
              onFaultChanged: (v) => setState(() => faultId = v),
            ),
            TextField(
              controller: titleC,
              decoration: const InputDecoration(
                labelText: 'Job Title e.g TV Mounting',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
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
           
            PhotosSection(
              photos: photos,
              existingPhotos: existingPhotos,
              onPickPhotos: _pickPhotos,
              onRemoveExisting: (url) =>
                  setState(() => existingPhotos.remove(url)),
              onRemoveLocal: (f) => setState(() => photos.remove(f)),
            ),
            const SizedBox(height: 20),
            // Location notice
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FundipapColors.primaryYellow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: FundipapColors.primaryYellow,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FUNDI NAVIGATION LOCATION',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fundi will navigate to the location you set when posting the job.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: loading ? null : _submit,
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
