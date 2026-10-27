import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class VerificationSection extends StatelessWidget {
  final String? selectedAnchorPhoto;
  final Rect blurRect;
  final List<XFile> verificationPhotos;
  final bool verifying;
  final bool anchorVerified;
  final String? verifyReason;
  final VoidCallback onTakePhoto;
  final bool hasValidVerification;

  const VerificationSection({
    super.key,
    required this.selectedAnchorPhoto,
    required this.blurRect,
    required this.verificationPhotos,
    required this.verifying,
    required this.anchorVerified,
    required this.verifyReason,
    required this.onTakePhoto,
    required this.hasValidVerification,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasValidVerification ? Colors.green : Colors.blue.shade200,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasValidVerification ? Icons.verified : Icons.verified_user,
                size: 16,
                color: hasValidVerification ? Colors.green : Colors.blue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'SET 1 - VERIFICATION (Optional for testing) - Prove you are on site',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    color: hasValidVerification
                        ? Colors.green.shade800
                        : Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Optional for now. When added: system picks random client photo, blurs fixed anchor (non-movable). Retake revealing it to prove on site.',
            style: GoogleFonts.inter(fontSize: 9, color: Colors.blue.shade800),
          ),
          if (selectedAnchorPhoto != null) ...[
            const SizedBox(height: 8),
            Text(
              'Client anchor - blurred part must be revealed in your retake (tap to view full):',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => Dialog(
                    backgroundColor: Colors.black,
                    insetPadding: const EdgeInsets.all(12),
                    child: Stack(
                      children: [
                        // FIXED: blur INSIDE InteractiveViewer so it tracks zoom/pan
                        Center(
                          child: InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: LayoutBuilder(
                              builder: (c, cons) {
                                return Stack(
                                  children: [
                                    Image.network(
                                      selectedAnchorPhoto!,
                                      fit: BoxFit.contain,
                                    ),
                                    Positioned(
                                      left: cons.maxWidth * blurRect.left,
                                      top: cons.maxHeight * blurRect.top,
                                      width: cons.maxWidth * blurRect.width,
                                      height: cons.maxHeight * blurRect.height,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                            sigmaX: 22,
                                            sigmaY: 22,
                                          ),
                                          child: Container(
                                            color: Colors.black.withOpacity(
                                              0.25,
                                            ),
                                            // border so fundi sees where to shoot
                                            child: Container(
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.white70,
                                                  width: 1.5,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        // Close + label stay outside viewer so they don't zoom
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Blurred area = fixed anchor you must reveal in your retake. Pinch to zoom - blur moves with image.',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final w = constraints.maxWidth;
                  const h = 120.0;
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          selectedAnchorPhoto!,
                          height: h,
                          width: w,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        left: w * blurRect.left,
                        top: h * blurRect.top,
                        width: w * blurRect.width,
                        height: h * blurRect.height,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.25),
                                border: Border.all(
                                  color: Colors.white70,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.zoom_in,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Tap to enlarge',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: verificationPhotos
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
          if (verifying) const LinearProgressIndicator(),
          if (verifyReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                verifyReason!,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: anchorVerified ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: verifying ? null : onTakePhoto,
            icon: Icon(
              verifying ? Icons.hourglass_top : Icons.camera_alt,
              size: 16,
              color: hasValidVerification ? Colors.green : Colors.blue,
            ),
            label: Text(
              verifying
                  ? 'Verifying. Please Wait...'
                  : hasValidVerification
                  ? 'Verified ✓ Retake if needed'
                  : 'Retake the photo to reveal the blurred part',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: hasValidVerification
                    ? Colors.green.shade800
                    : Colors.blue.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
