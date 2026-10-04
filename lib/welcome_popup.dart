// lib/welcome_popup.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class WelcomePopup extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback? onSkip;

  const WelcomePopup({
    super.key,
    required this.onContinue,
    this.onSkip,
  });

  @override
  State<WelcomePopup> createState() => _WelcomePopupState();
}

class _WelcomePopupState extends State<WelcomePopup>
    with SingleTickerProviderStateMixin {
  // ✅ Drives the continuous rotation
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6), // one full rotation every 6 s
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Sizes
    const double badgeSize = 110; // outer badge diameter
    const double ringWidth = 4; // ring thickness
    const double innerPadding = 6; // gap between ring and logo

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ═══════════════════════════════════════════════════
            // ✅ Spinning Gradient Ring + Stationary Logo
            // ═══════════════════════════════════════════════════
            SizedBox(
              width: badgeSize,
              height: badgeSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1) Outer soft glow (static)
                  Container(
                    width: badgeSize,
                    height: badgeSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.shade700.withOpacity(0.35),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.green.shade200.withOpacity(0.6),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),

                  // 2) Rotating gradient ring (the "spinning" part)
                  RotationTransition(
                    turns: _spinController,
                    child: CustomPaint(
                      size: const Size(badgeSize, badgeSize),
                      painter: _SpinningRingPainter(
                        ringWidth: ringWidth,
                        colors: [
                          Colors.green.shade400,
                          Colors.green.shade700,
                          Colors.lightGreen.shade400,
                          Colors.green.shade400,
                        ],
                      ),
                    ),
                  ),

                  // 3) Stationary white inner disk + logo
                  Container(
                    width: badgeSize - (ringWidth * 2) - (innerPadding * 2),
                    height: badgeSize - (ringWidth * 2) - (innerPadding * 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.gavel_rounded,
                          size: 48,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              "স্বাগতম উকিল  অ্যাপে!",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            const Text(
              "আপনার আইনি সহায়তার সেরা অ্যাডভোকেট খুঁজুন, প্রশ্ন করুন, ফ্রি কনসালটেশন নিন এবং কেস ম্যানেজ করুন সহজেই।",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed:
                      widget.onSkip ?? () => Navigator.pop(context),
                  child: const Text(
                    "পরে দেখব",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: widget.onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "শুরু করি",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Custom painter — draws a smooth gradient ring
// The ring is rotated externally via RotationTransition.
// ============================================================
class _SpinningRingPainter extends CustomPainter {
  final double ringWidth;
  final List<Color> colors;

  _SpinningRingPainter({
    required this.ringWidth,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - ringWidth) / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: colors,
        // smooth blending — a full 360° sweep
        stops: const [0.0, 0.33, 0.66, 1.0],
        startAngle: 0,
        endAngle: math.pi * 2,
        transform: const GradientRotation(0),
      ).createShader(rect);

    canvas.drawCircle(center, radius, paint);

    // Add a light "comet tail" overlay for extra shine
    final shinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth * 0.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.7),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.05, 0.10],
        startAngle: 0,
        endAngle: math.pi * 2,
      ).createShader(rect);

    canvas.drawCircle(center, radius, shinePaint);
  }

  @override
  bool shouldRepaint(covariant _SpinningRingPainter old) {
    return old.ringWidth != ringWidth || old.colors != colors;
  }
}