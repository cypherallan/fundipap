import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class EvidenceSection extends StatelessWidget {
  final List<XFile> evidencePhotos;
  final VoidCallback onAdd;
  final ValueChanged<XFile> onRemove;

  const EvidenceSection({
    super.key,
    required this.evidencePhotos,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_camera, size: 16, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                'SET 2 - EVIDENCE (Optional for now)',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'New photos showing WHY extra needed (no space, no water, bigger scope, materials). Taken within 10 mins after Set 1, same GPS. Generic - not hardcoded.',
            style: GoogleFonts.inter(
              fontSize: 9,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: evidencePhotos
                .map(
                  (x) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(x.path),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => onRemove(x),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.photo, size: 16),
            label: const Text(
              'Add evidence photos - why extra needed',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
