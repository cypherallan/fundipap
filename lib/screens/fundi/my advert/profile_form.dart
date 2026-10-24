import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../data/job_taxonomy.dart';

class ProfileForm extends StatelessWidget {
  final String selectedCategoryId;
  final List<String> selectedCategoryIds;
  final List<String> selectedSubcategoryIds;
  final Map selectedCategory;
  final List subcategories;
  final TextEditingController bioCtrl;
  final TextEditingController keywordCtrl;
  final TextEditingController expCtrl;
  final ValueChanged<String?> onCategoryChanged;
  final Function(String id, bool selected) onSubToggle;
  final Function(String id, bool selected) onOtherToggle;
  final VoidCallback onSave;

  const ProfileForm({
    super.key,
    required this.selectedCategoryId,
    required this.selectedCategoryIds,
    required this.selectedSubcategoryIds,
    required this.selectedCategory,
    required this.subcategories,
    required this.bioCtrl,
    required this.keywordCtrl,
    required this.expCtrl,
    required this.onCategoryChanged,
    required this.onSubToggle,
    required this.onOtherToggle,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Primary Profession * (24 Categories)',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: selectedCategoryId,
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          items: FundiTaxonomy.categories.map((c) {
            bool isTop = c['isTop6'] == true;
            return DropdownMenuItem(
              value: c['id'] as String,
              child: Row(
                children: [
                  Text(isTop ? '⭐ ' : '', style: const TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      c['name'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isTop ? FontWeight.w700 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onCategoryChanged,
        ),
        const SizedBox(height: 12),
        if (subcategories.isNotEmpty) ...[
          Text(
            'What you do inside ${selectedCategory['name']} - Select sub-services',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: subcategories.map((s) {
              var ss = s as Map<String, dynamic>;
              bool sel = selectedSubcategoryIds.contains(ss['id']);
              return FilterChip(
                label: Text(
                  ss['name'] as String,
                  style: GoogleFonts.inter(fontSize: 11),
                ),
                selected: sel,
                selectedColor: FundipapColors.primaryYellow.withOpacity(0.4),
                onSelected: (v) => onSubToggle(ss['id'], v),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Years of Experience',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: expCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'e.g. 5',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Other Categories You Also Do (24)',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Clients searching these categories will also see you',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: FundiTaxonomy.categories
              .where((c) => c['id'] != selectedCategoryId)
              .map((c) {
                bool sel = selectedCategoryIds.contains(c['id']);
                bool isTop = c['isTop6'] == true;
                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isTop)
                        const Text('⭐ ', style: TextStyle(fontSize: 10)),
                      Text(
                        c['name'] as String,
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                    ],
                  ),
                  selected: sel,
                  selectedColor: FundipapColors.primaryYellow.withOpacity(0.3),
                  onSelected: (v) => onOtherToggle(c['id'] as String, v),
                );
              })
              .toList(),
        ),
        const SizedBox(height: 20),
        Text(
          'Search Keyword',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: keywordCtrl,
          decoration: InputDecoration(
            labelText: 'e.g. plumbing, wiring, washing machine',
            hintText: '${selectedCategory['slug']}',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Bio / About You',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: bioCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText:
                'e.g I install & repair washing machines... 5 years experience...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: FundipapColors.blackGray,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
            ),
            child: Text(
              'Update Profile',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
