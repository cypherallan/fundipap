import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../data/job_taxonomy.dart';

class CategorySelectionSection extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final List<Map<String, dynamic>> searchResults;
  final ValueChanged<Map<String, dynamic>> onSelectFromSearch;

  final String categoryId;
  final String? subcategoryId;
  final String? faultId;
  final String serviceFilter;
  final List filteredSubcategories;
  final List faults;

  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String?> onSubcategoryChanged;
  final ValueChanged<String?> onFaultChanged;

  const CategorySelectionSection({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.searchResults,
    required this.onSelectFromSearch,
    required this.categoryId,
    required this.subcategoryId,
    required this.faultId,
    required this.serviceFilter,
    required this.filteredSubcategories,
    required this.faults,
    required this.onCategoryChanged,
    required this.onFilterChanged,
    required this.onSubcategoryChanged,
    required this.onFaultChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search e.g TV mounting, plumbing...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: onClearSearch,
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
        ),
        if (searchQuery.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: searchResults.isEmpty
                ? ListTile(
                    dense: true,
                    title: Text(
                      'No result for "$searchQuery"',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: searchResults.length,
                    itemBuilder: (_, i) {
                      final r = searchResults[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          r['subcategoryName'],
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          r['categoryName'],
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                        onTap: () => onSelectFromSearch(r),
                      );
                    },
                  ),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: categoryId,
          isExpanded: true,
          alignment: AlignmentDirectional.centerStart,
          decoration: const InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: FundiTaxonomy.categories.map((c) {
            final isTop = c['isTop6'] == true;
            final count = (c['subcategories'] as List).length;
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
            if (v != null) onCategoryChanged(v);
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Filter Services:',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
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
            onFilterChanged(newSel.first);
          },
        ),
        const SizedBox(height: 12),
        if (filteredSubcategories.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: subcategoryId,
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
              final ss = s as Map<String, dynamic>;
              final isInstall = (ss['id'] as String).toLowerCase().contains(
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
            onChanged: onSubcategoryChanged,
          ),
        const SizedBox(height: 12),
        if (faults.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: faultId,
            isExpanded: true,
            alignment: AlignmentDirectional.centerStart,
            decoration: const InputDecoration(
              labelText: 'Specific Fault / Detail',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: faults.map((f) {
              final ff = f as Map<String, dynamic>;
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
            onChanged: onFaultChanged,
          ),
        if (faults.isNotEmpty) const SizedBox(height: 12),
      ],
    );
  }
}
