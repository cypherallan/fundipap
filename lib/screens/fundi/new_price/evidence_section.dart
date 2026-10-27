import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class EvidenceSection extends StatelessWidget {
  final dynamic state;
  const EvidenceSection({super.key, required this.state});

  void _showEvidenceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take photo - Camera'),
                onTap: () async {
                  Navigator.pop(ctx);
                  var img = await state.picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 60,
                  );
                  if (img != null) {
                    state.setState(() => state.evidencePhotos.add(img));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery (multiple)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  var imgs = await state.picker.pickMultiImage(
                    imageQuality: 60,
                  );
                  if (imgs.isNotEmpty) {
                    state.setState(() => state.evidencePhotos.addAll(imgs));
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showOldPartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.pop(ctx);
                  var img = await state.picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 60,
                  );
                  if (img != null) {
                    state.setState(() => state.oldPartPhotos.add(img));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.pop(ctx);
                  var img = await state.picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 60,
                  );
                  if (img != null) {
                    state.setState(() => state.oldPartPhotos.add(img));
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool needsReplacement = state.selectedReasons.contains(
      'Replacement needed (old part damaged)',
    );
    return Column(
      children: [
        Container(
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
                  const Icon(
                    Icons.photo_camera,
                    size: 16,
                    color: Colors.orange,
                  ),
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
                children: state.evidencePhotos.map<Widget>((x) {
                  return Stack(
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
                          onTap: () => state.setState(
                            () => state.evidencePhotos.remove(x),
                          ),
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
                  );
                }).toList(),
              ),
              OutlinedButton.icon(
                onPressed: () => _showEvidenceSheet(context),
                icon: const Icon(Icons.photo, size: 16),
                label: const Text(
                  'Add evidence photos - why extra needed',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        if (needsReplacement) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'OLD damaged part photo',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: Colors.red,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            children: state.oldPartPhotos.map<Widget>((x) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(x.path),
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              );
            }).toList(),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
            ),
            onPressed: () => _showOldPartSheet(context),
            icon: const Icon(Icons.camera_alt, size: 16, color: Colors.red),
            label: const Text(
              'Photo of OLD part',
              style: TextStyle(color: Colors.red, fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }
}
