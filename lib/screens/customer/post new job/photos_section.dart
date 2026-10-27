import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class PhotosSection extends StatelessWidget {
  final List<File> photos;
  final List<String> existingPhotos;
  final VoidCallback onPickPhotos;
  final ValueChanged<String> onRemoveExisting;
  final ValueChanged<File> onRemoveLocal;

  const PhotosSection({
    super.key,
    required this.photos,
    required this.existingPhotos,
    required this.onPickPhotos,
    required this.onRemoveExisting,
    required this.onRemoveLocal,
  });

  static Future<void> showPhotoSourceSheet({
    required BuildContext context,
    required void Function(File) onPhotoAdded,
    required void Function(List<File>) onPhotosAdded,
  }) async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(
                'Take photo with camera',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final XFile? shot = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (shot != null) {
                  onPhotoAdded(File(shot.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(
                'Choose from gallery',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final picked = await picker.pickMultiImage(imageQuality: 80);
                if (picked.isNotEmpty) {
                  onPhotosAdded(picked.map((e) => File(e.path)).toList());
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: onPickPhotos,
          icon: const Icon(Icons.photo),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            foregroundColor: Colors.black87,
          ),
          label: Text(
            existingPhotos.isEmpty && photos.isEmpty
                ? 'Add Photos (Optional)'
                : '${existingPhotos.length + photos.length} photos added - tap to add more',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Photos help fundis bid accurately but not required',
          style: GoogleFonts.inter(fontSize: 10, color: Colors.black54),
        ),
        if (existingPhotos.isNotEmpty || photos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...existingPhotos.map(
                  (url) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () => onRemoveExisting(url),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...photos.map(
                  (f) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          f,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () => onRemoveLocal(f),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
