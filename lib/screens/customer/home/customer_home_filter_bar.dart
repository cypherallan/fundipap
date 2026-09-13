import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class CustomerHomeFilterBar extends StatelessWidget {
  final double radius;
  final String filter;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<String> onFilterChanged;
  const CustomerHomeFilterBar({
    super.key,
    required this.radius,
    required this.filter,
    required this.onRadiusChanged,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fundis Near You',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: FundipapColors.primaryYellow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${radius.toStringAsFixed(1)} km',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: radius,
            min: 1,
            max: 20,
            divisions: 19,
            label: '${radius.toStringAsFixed(1)} km',
            activeColor: FundipapColors.blackGray,
            onChanged: onRadiusChanged,
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Nearest', 'distance', Icons.near_me),
                _chip('Top Rated', 'rated', Icons.star),
                _chip('Cheapest', 'cheap', Icons.arrow_upward),
                _chip('Price High', 'expensive', Icons.arrow_downward),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, IconData icon) {
    bool selected = filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: selected,
        selectedColor: FundipapColors.primaryYellow,
        onSelected: (_) => onFilterChanged(value),
        labelStyle: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
