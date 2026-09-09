import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});
  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  double _radius = 5.0; // km
  String _filter = 'distance'; // distance, rated, cheap, expensive

  final List<Map<String, dynamic>> _allFundis = [
    {
      'name': 'Otieno Wireman',
      'skill': 'Electrical',
      'rating': 4.9,
      'price': 1200,
      'distance': 1.2,
      'jobs': 124,
      'verified': true,
    },
    {
      'name': 'Akinyi Plumber',
      'skill': 'Plumbing',
      'rating': 4.7,
      'price': 800,
      'distance': 2.5,
      'jobs': 89,
      'verified': true,
    },
    {
      'name': 'Omondi Painter',
      'skill': 'Painting',
      'rating': 4.5,
      'price': 1500,
      'distance': 0.8,
      'jobs': 56,
      'verified': false,
    },
    {
      'name': 'Atieno Mason',
      'skill': 'Masonry',
      'rating': 5.0,
      'price': 2000,
      'distance': 4.2,
      'jobs': 210,
      'verified': true,
    },
    {
      'name': 'Ochieng Welder',
      'skill': 'Welding',
      'rating': 4.3,
      'price': 900,
      'distance': 6.0,
      'jobs': 34,
      'verified': true,
    },
    {
      'name': 'Awino Tiler',
      'skill': 'Tiling',
      'rating': 4.8,
      'price': 1100,
      'distance': 3.1,
      'jobs': 72,
      'verified': true,
    },
  ];

  List<Map<String, dynamic>> get filteredFundis {
    var list = _allFundis
        .where((f) => (f['distance'] as double) <= _radius)
        .toList();
    if (_filter == 'distance') {
      list.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );
    } else if (_filter == 'rated') {
      list.sort(
        (a, b) => (b['rating'] as double).compareTo(a['rating'] as double),
      );
    } else if (_filter == 'cheap') {
      list.sort((a, b) => (a['price'] as int).compareTo(b['price'] as int));
    } else if (_filter == 'expensive') {
      list.sort((a, b) => (b['price'] as int).compareTo(a['price'] as int));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final fundis = filteredFundis;
    return Column(
      children: [
        // FILTER BAR
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Near You',
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
                      '${_radius.toStringAsFixed(1)} km radius',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Slider(
                value: _radius,
                min: 1,
                max: 20,
                divisions: 19,
                label: '${_radius.toStringAsFixed(1)} km',
                activeColor: FundipapColors.blackGray,
                onChanged: (v) => setState(() => _radius = v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('1km', style: GoogleFonts.inter(fontSize: 10)),
                  Text('20km', style: GoogleFonts.inter(fontSize: 10)),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('Nearest', 'distance', Icons.near_me),
                    _chip('Top Rated', 'rated', Icons.star),
                    _chip('Cheapest', 'cheap', Icons.arrow_upward),
                    _chip('Price: High', 'expensive', Icons.arrow_downward),
                  ],
                ),
              ),
            ],
          ),
        ),
        // FUNDI LIST
        Expanded(
          child: fundis.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No fundis within ${_radius.toStringAsFixed(1)}km',
                        style: GoogleFonts.inter(),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: fundis.length,
                  itemBuilder: (context, i) {
                    var f = fundis[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: FundipapColors.primaryYellow,
                            child: Text(
                              f['name'][0],
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      f['name'],
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (f['verified'])
                                      const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Icon(
                                          Icons.verified,
                                          size: 14,
                                          color: FundipapColors.greenSuccess,
                                        ),
                                      ),
                                  ],
                                ),
                                Text(
                                  '${f['skill']} • ${f['jobs']} jobs',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 14,
                                      color: FundipapColors.primaryYellow,
                                    ),
                                    Text(
                                      ' ${f['rating']}',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.place,
                                      size: 14,
                                      color: Colors.black45,
                                    ),
                                    Text(
                                      ' ${f['distance']} km',
                                      style: GoogleFonts.inter(fontSize: 11),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'KES ${f['price']}',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                            ),
                            onPressed: () {},
                            child: Text(
                              'Hire',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _chip(String label, String value, IconData icon) {
    bool selected = _filter == value;
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
        onSelected: (_) => setState(() => _filter = value),
        labelStyle: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
