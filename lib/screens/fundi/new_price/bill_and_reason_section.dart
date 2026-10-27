import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ReasonAndBillSection extends StatelessWidget {
  final dynamic state;
  const ReasonAndBillSection({super.key, required this.state});

  Widget _billRow(
    String l,
    String v, {
    bool highlight = false,
    bool highlightYellow = false,
    bool small = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: small ? 9 : 11,
            ),
          ),
          Text(
            v,
            style: GoogleFonts.montserrat(
              color: highlightYellow
                  ? FundipapColors.primaryYellow
                  : Colors.white,
              fontWeight: highlight || highlightYellow
                  ? FontWeight.w800
                  : FontWeight.w600,
              fontSize: small
                  ? 10
                  : highlightYellow
                  ? 13
                  : 11,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool needsParts = state.needsParts;
    bool needsLabor = state.needsLabor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current: Labour KES ${state.oldLabor} + Transport KES ${state.transport} = KES ${state.oldLabor + state.transport}',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              Text(
                'Transport does not change. App Maintenance Cost = ${state.clientFeePct}% client, ${state.fundiFeePct}% you (${state.badge?.badgeLevel.name ?? 'bronze'}).',
                style: GoogleFonts.inter(fontSize: 10, color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
          children: state.allReasons.map<Widget>((r) {
            bool sel = state.selectedReasons.contains(r);
            return FilterChip(
              label: Text(r, style: GoogleFonts.inter(fontSize: 11)),
              selected: sel,
              selectedColor: FundipapColors.primaryYellow,
              onSelected: (v) => state.setState(() {
                if (v)
                  state.selectedReasons.add(r);
                else {
                  state.selectedReasons.remove(r);
                  bool stillLabor =
                      state.selectedReasons.contains(
                        'Job bigger / more work than expected',
                      ) ||
                      state.selectedReasons.contains('Extra labor required') ||
                      state.selectedReasons.contains(
                        'Transport / distance extra',
                      );
                  bool stillParts =
                      state.selectedReasons.contains(
                        'New parts / materials needed',
                      ) ||
                      state.selectedReasons.contains(
                        'Replacement needed (old part damaged)',
                      );
                  if (!stillLabor) state.extraLaborCtrl.text = '0';
                  if (!stillParts) state._clearParts();
                }
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: state.detailsCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Explain in detail',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (needsLabor) ...[
          const SizedBox(height: 16),
          Text(
            'Extra Labor',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: state.extraLaborCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => state.setState(() {}),
            decoration: InputDecoration(
              labelText: 'Extra Labor KES',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
        if (needsParts) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Parts Needed (Client will buy)',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
              ),
              TextButton.icon(
                onPressed: state._addPartNeeded,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          ...state.partsNeeded.asMap().entries.map((e) {
            int idx = e.key;
            var p = e.value;
            return Container(
              key: ValueKey(p['name']),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: p['name'],
                      onChanged: (_) => state.setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Part e.g. 1 inch pipe',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: p['qty'],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Qty',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: p['model'],
                      onChanged: (_) => state.setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Model',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: p['estPrice'],
                      keyboardType: TextInputType.number,
                      onChanged: (_) => state.setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Est Price',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        state.setState(() => state.partsNeeded.removeAt(idx)),
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  ),
                ],
              ),
            );
          }),
        ],
        if (needsParts) ...[
          const SizedBox(height: 12),
          TextField(
            controller: state.tillCtrl,
            decoration: InputDecoration(
              labelText: 'Till Number (Optional)',
              hintText: 'Leave blank if you dont know shops around',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FundipapColors.blackGray,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bill Summary - NEW PRICE',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              _billRow('Old Labour:', 'KES ${state.oldLabor}'),
              _billRow(
                'Extra Labour:',
                'KES ${state.extraLabor}',
                highlight: true,
              ),
              _billRow(
                'New Labour Total:',
                'KES ${state.newLaborTotal}',
                highlight: true,
              ),
              _billRow('Transport (same):', 'KES ${state.transport}'),
              const Divider(color: Colors.white24),
              _billRow(
                'Old Total Paid:',
                'KES ${state.oldLabor + state.transport}',
              ),
              _billRow(
                'Extra to Lock Now:',
                'KES ${needsLabor ? state.extraLabor : 0}',
                highlightYellow: true,
              ),
              const SizedBox(height: 6),
              Text(
                needsParts
                    ? 'Parts: ${state.partsNeeded.where((p) => (p['name']?.text.trim().isNotEmpty ?? false)).length} items - KES ${state.partsEstimateTotal} separate (client buys)'
                    : 'No parts requested',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
