import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'part_needed.dart';

class PartsNeededSection extends StatelessWidget {
  final List<PartNeeded> parts;
  final TextEditingController tillCtrl;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onChanged;

  const PartsNeededSection({
    super.key,
    required this.parts,
    required this.tillCtrl,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Parts Needed (Client will buy)',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        ...parts.asMap().entries.map((e) {
          final idx = e.key;
          final p = e.value;
          return Container(
            key: ValueKey(p.name),
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
                    controller: p.name,
                    onChanged: (_) => onChanged(),
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
                    controller: p.qty,
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
                    controller: p.model,
                    onChanged: (_) => onChanged(),
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
                    controller: p.estPrice,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Est Price',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => onRemove(idx),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        TextField(
          controller: tillCtrl,
          decoration: InputDecoration(
            labelText: 'Till Number (Optional)',
            hintText: 'Leave blank if you dont know shops around',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
