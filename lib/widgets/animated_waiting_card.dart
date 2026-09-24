import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrangeAnimatedWaitingCard extends StatefulWidget {
  final String title;
  final String message;
  final Widget? action;
  final VoidCallback? onTap;
  const OrangeAnimatedWaitingCard({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.onTap,
  });

  @override
  State<OrangeAnimatedWaitingCard> createState() =>
      _OrangeAnimatedWaitingCardState();
}

class _OrangeAnimatedWaitingCardState extends State<OrangeAnimatedWaitingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _MovingBorderPainter(progress: _controller.value),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.hourglass_top,
                          size: 18,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.message,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.black87,
                    ),
                  ),
                  if (widget.action != null) ...[
                    const SizedBox(height: 10),
                    widget.action!,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MovingBorderPainter extends CustomPainter {
  final double progress;
  _MovingBorderPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );
    final path = Path()..addRRect(rrect);
    final basePaint = Paint()
      ..color = Colors.orange.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(path, basePaint);
    final metrics = path.computeMetrics().first;
    final total = metrics.length;
    final seg = total * 0.30;
    final start = (progress * total) % total;
    double end = start + seg;
    final movingPaint = Paint()
      ..color = Colors.orange.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    if (end <= total) {
      canvas.drawPath(metrics.extractPath(start, end), movingPaint);
    } else {
      canvas.drawPath(metrics.extractPath(start, total), movingPaint);
      canvas.drawPath(metrics.extractPath(0, end - total), movingPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MovingBorderPainter old) =>
      old.progress != progress;
}
