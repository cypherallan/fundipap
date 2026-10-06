import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../widgets/fundi_badge_chip.dart';
import '../../models/customer_home_models.dart';
import '../../../../../services/fundi_badge_service.dart';

class PendingFilterBar extends StatelessWidget {
  final FilterType value;
  final double distanceKm; // 0-20
  final ValueChanged<FilterType> onChanged;
  final ValueChanged<double> onDistanceChanged;

  const PendingFilterBar({
    super.key,
    required this.value,
    required this.distanceKm,
    required this.onChanged,
    required this.onDistanceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<FilterType>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.filter_list, size: 18),
              items: [
                DropdownMenuItem(
                  value: FilterType.all,
                  child: Text(
                    'Filter By',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: FilterType.nearby,
                  child: Row(
                    children: [
                      const Icon(Icons.near_me, size: 14, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        'Distance • ${distanceKm.toInt()}km',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: FilterType.verified,
                  child: Row(
                    children: [
                      const Icon(Icons.verified, size: 14, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text(
                        'Verified',
                        style: GoogleFonts.montserrat(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: FilterType.topRated,
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        'Top Rated 4.5+',
                        style: GoogleFonts.montserrat(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: FilterType.highReferral,
                  child: Row(
                    children: [
                      const Icon(Icons.people, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'High Referral 10+',
                        style: GoogleFonts.montserrat(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: FilterType.clean,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.clean_hands,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Clean Record',
                        style: GoogleFonts.montserrat(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: FilterType.badge,
                  child: Row(
                    children: [
                      Text(
                        'Badge Ranking',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const FundiBadgeChip(level: BadgeLevel.gold),
                    ],
                  ),
                ),
              ],
              onChanged: (v) => onChanged(v!),
            ),
          ),
        ),
        if (value == FilterType.nearby) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '0 km',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                    Text(
                      '${distanceKm.toInt()} km radius',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.green.shade900,
                      ),
                    ),
                    Text(
                      '20 km',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: distanceKm,
                  min: 0,
                  max: 20,
                  divisions: 20,
                  activeColor: Colors.green.shade700,
                  label: '${distanceKm.toInt()} km',
                  onChanged: onDistanceChanged,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
