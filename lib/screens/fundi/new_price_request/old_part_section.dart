import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class OldPartSection extends StatelessWidget {
  final List<XFile> oldPartPhotos;
  final VoidCallback onAdd;

  const OldPartSection({
    super.key,
    required this.oldPartPhotos,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'OLD damaged part photo',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            color: Colors.red,
          ),
        ),
        Wrap(
          spacing: 6,
          children: oldPartPhotos
              .map(
                (x) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(x.path),
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
              )
              .toList(),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
          ),
          onPressed: onAdd,
          icon: const Icon(Icons.camera_alt, size: 16, color: Colors.red),
          label: const Text(
            'Photo of OLD part',
            style: TextStyle(color: Colors.red, fontSize: 11),
          ),
        ),
      ],
    );
  }
}
