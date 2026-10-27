import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart'; // adjust path
import 'price_request_reasons.dart';

class ReasonChips extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const ReasonChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select ALL reasons that apply:',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: PriceRequestReasons.all.map((r) {
            final sel = selected.contains(r);
            return FilterChip(
              label: Text(r, style: GoogleFonts.inter(fontSize: 11)),
              selected: sel,
              selectedColor: FundipapColors.primaryYellow,
              onSelected: (v) {
                final next = Set<String>.from(selected);
                if (v) {
                  next.add(r);
                } else {
                  next.remove(r);
                }
                onChanged(next);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
