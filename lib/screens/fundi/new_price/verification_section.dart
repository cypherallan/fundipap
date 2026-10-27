import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class VerificationSection extends StatelessWidget {
  final dynamic state;
  const VerificationSection({super.key, required this.state});

  void _showVerificationSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo - Camera ONLY'),
              onTap: () async {
                Navigator.pop(ctx);
                var img = await state.picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 70,
                );
                if (img != null) {
                  state.setState(() => state.verificationPhotos.add(img));
                  await state.runAnchorCheck(img.path);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasValid = state.verificationPhotos.isNotEmpty && state.anchorVerified;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasValid ? Colors.green : Colors.blue.shade200,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasValid ? Icons.verified : Icons.verified_user,
                size: 16,
                color: hasValid ? Colors.green : Colors.blue,
              ),
              const SizedBox(width: 6),
              Text(
                'SET 1 - VERIFICATION (Optional for testing) - Prove you are on site',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  color: hasValid
                      ? Colors.green.shade800
                      : Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Optional for now. When added: system picks random client photo, blurs fixed anchor (non-movable). Retake revealing it to prove on site.',
            style: GoogleFonts.inter(fontSize: 9, color: Colors.blue.shade800),
          ),
          if (state.selectedAnchorPhoto != null) ...[
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
              onTap: () => showDialog(
                context: context,
                builder: (ctx) => Dialog(
                  backgroundColor: Colors.black,
                  insetPadding: const EdgeInsets.all(12),
                  child: Stack(
                    children: [
                      Center(
                        child: InteractiveViewer(
                          child: Image.network(
                            state.selectedAnchorPhoto!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (c, cons) => Stack(
                            children: [
                              Positioned(
                                left: cons.maxWidth * state.blurRect.left,
                                top:
                                    cons.maxHeight * 0.3 +
                                    cons.maxHeight * state.blurRect.top * 0.4,
                                width: cons.maxWidth * state.blurRect.width,
                                height: cons.maxHeight * state.blurRect.height,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 20,
                                      sigmaY: 20,
                                    ),
                                    child: Container(
                                      color: Colors.black.withOpacity(0.2),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                    ],
                  ),
                ),
              ),
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final w = constraints.maxWidth;
                  const h = 120.0;
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          state.selectedAnchorPhoto!,
                          height: h,
                          width: w,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        left: w * state.blurRect.left,
                        top: h * state.blurRect.top,
                        width: w * state.blurRect.width,
                        height: h * state.blurRect.height,
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
            children: state.verificationPhotos
                .map<Widget>(
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
          if (state.verifying) const LinearProgressIndicator(),
          if (state.verifyReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                state.verifyReason!,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: state.anchorVerified ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: state.verifying
                ? null
                : () => _showVerificationSourceSheet(context),
            icon: Icon(
              state.verifying ? Icons.hourglass_top : Icons.camera_alt,
              size: 16,
              color: hasValid ? Colors.green : Colors.blue,
            ),
            label: Text(
              state.verifying
                  ? 'Verifying with Vision API...'
                  : hasValid
                  ? 'Verified ✓ Retake if needed'
                  : 'Retake revealing blurred anchor (in-app camera)',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: hasValid ? Colors.green.shade800 : Colors.blue.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
