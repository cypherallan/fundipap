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
  final int attempts;
  final int maxAttempts;
  final int cooldownSeconds;
  final bool isLocked;
  final String oldPrice;

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
    this.attempts = 0,
    this.maxAttempts = 5,
    this.cooldownSeconds = 0,
    this.isLocked = false,
    this.oldPrice = '0',
  });

  @override
  Widget build(BuildContext context) {
    final remaining = maxAttempts - attempts;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLocked ? Colors.red.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLocked
              ? Colors.red
              : hasValidVerification
              ? Colors.green
              : Colors.blue.shade200,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLocked
                    ? Icons.block
                    : hasValidVerification
                    ? Icons.verified
                    : Icons.verified_user,
                size: 16,
                color: isLocked
                    ? Colors.red
                    : hasValidVerification
                    ? Colors.green
                    : Colors.blue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isLocked
                      ? 'VERIFICATION LOCKED - FAILED $maxAttempts/$maxAttempts'
                      : 'SET 1 - VERIFICATION ($attempts/$maxAttempts) - Optional for testing',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    color: isLocked
                        ? Colors.red.shade800
                        : hasValidVerification
                        ? Colors.green.shade800
                        : Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (isLocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FAILED VERIFICATION 5 TIMES',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.red.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You cannot request new price. Work with OLD price: KES $oldPrice..',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade900,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Optional for testing. $attempts/$maxAttempts | Remaining: $remaining | ${cooldownSeconds > 0
                  ? 'Wait ${cooldownSeconds}s'
                  : attempts == 0
                  ? 'First free'
                  : attempts == 1
                  ? '4 left, no wait'
                  : attempts == 2
                  ? 'Next 30s'
                  : attempts == 3
                  ? 'Next 60s'
                  : 'Next 90s'}',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade800,
              ),
            ),
          if (selectedAnchorPhoto != null && !isLocked) ...[
            const SizedBox(height: 8),
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
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: LayoutBuilder(
                            builder: (c, cons) => Stack(
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
                                        color: Colors.black.withOpacity(0.25),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.white70,
                                              width: 1.5,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
          const SizedBox(height: 6),
          if (isLocked)
            SizedBox(
              width: double.infinity,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Work with old price KES $oldPrice',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: verifying || cooldownSeconds > 0 ? null : onTakePhoto,
              icon: Icon(
                verifying
                    ? Icons.hourglass_top
                    : cooldownSeconds > 0
                    ? Icons.timer
                    : Icons.camera_alt,
                size: 16,
                color: hasValidVerification ? Colors.green : Colors.blue,
              ),
              label: Text(
                verifying
                    ? 'Verifying...'
                    : cooldownSeconds > 0
                    ? 'Wait ${cooldownSeconds}s ($remaining left)'
                    : hasValidVerification
                    ? 'Verified ✓'
                    : attempts == 0
                    ? 'Retake revealing blurred part (Optional)'
                    : 'Retry - $remaining left',
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
