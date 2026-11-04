import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished, required this.language});
  final VoidCallback onFinished;
  final String language;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 4300);
  late final AnimationController _scene;
  late final AnimationController _loading;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scene = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200))..repeat();
    _loading = AnimationController(vsync: this, duration: _duration)..forward();
    _timer = Timer(_duration, () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scene.dispose();
    _loading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF72C9F5), Color(0xFFDDF4FF), Color(0xFFF8FFF3)],
            stops: [0, .56, 1],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 650;
              return Column(
                children: [
                  SizedBox(height: compact ? 91 : 112, child: _header(compact)),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, bounds) {
                        final w = bounds.maxWidth;
                        final h = bounds.maxHeight;
                        final animalW = w * .46;
                        final animalH = animalW * .62;
                        final milkSize = w * .49 < h * .48 ? w * .49 : h * .48;
                        return AnimatedBuilder(
                          animation: _scene,
                          builder: (context, child) {
                            final t = _scene.value;
                            return ClipRect(
                              child: Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  const Positioned.fill(child: CustomPaint(painter: _FarmPainter())),
                                  Positioned(
                                    left: _animalX(t + .12, w, animalW),
                                    top: h * .31,
                                    width: animalW,
                                    height: animalH,
                                    child: CustomPaint(painter: _AnimalPainter(buffalo: false, phase: t * math.pi * 8)),
                                  ),
                                  Positioned(
                                    left: _animalX(t + .53, w, animalW),
                                    top: h * .48,
                                    width: animalW,
                                    height: animalH,
                                    child: CustomPaint(painter: _AnimalPainter(buffalo: true, phase: t * math.pi * 8 + 1.2)),
                                  ),
                                  Positioned(
                                    right: w * .015,
                                    bottom: h * .025,
                                    width: milkSize,
                                    height: milkSize,
                                    child: AnimatedBuilder(
                                      animation: _loading,
                                      builder: (context, child) => CustomPaint(painter: _MilkPainter(progress: _loading.value)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  _footer(compact),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double _animalX(double value, double width, double animalWidth) {
    final t = value % 1;
    return -animalWidth + t * (width + animalWidth);
  }

  Widget _header(bool compact) {
    final logoSize = compact ? 52.0 : 62.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, compact ? 3 : 9, 20, 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFB7E5FF), width: 2),
              boxShadow: const [BoxShadow(color: Color(0x33004B9B), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Image.asset(
              'assets/images/milk_account_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.local_drink_rounded, color: Color(0xFF0756C9), size: 38),
            ),
          ),
          const SizedBox(width: 13),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'دودھ کا کھاتہ',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  color: const Color(0xFF06377C),
                  fontSize: compact ? 27 : 31,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              const Text('MILK ACCOUNT', style: TextStyle(color: Color(0xFF0756A9), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 3.1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footer(bool compact) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 7, 22, compact ? 8 : 13),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.language == 'en' ? 'Milk accounting, made easy' : widget.language == 'hi' ? 'दूध का हिसाब, अब आसान' : 'دودھ کا حساب، اب آسان',
            textAlign: TextAlign.center,
            textDirection: widget.language == 'ur' ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(fontFamily: widget.language == 'ur' ? 'NotoNaskhArabic' : null, color: const Color(0xFF06377C), fontSize: compact ? 23 : 27, fontWeight: FontWeight.w800, height: 1.15),
          ),
          const SizedBox(height: 2),
          Text(
            widget.language == 'en' ? 'SMART MILK COLLECTION & ACCOUNT MANAGEMENT' : widget.language == 'hi' ? 'स्मार्ट दूध संग्रह और खाता प्रबंधन' : 'دودھ جمع کرنے اور کھاتے کا آسان نظام',
            textAlign: TextAlign.center,
            style: TextStyle(color: const Color(0xFF24527B), fontSize: compact ? 8 : 9, fontWeight: FontWeight.w900, letterSpacing: .7),
          ),
          SizedBox(height: compact ? 10 : 15),
          AnimatedBuilder(
            animation: _loading,
            builder: (context, child) => Container(
              height: 10,
              width: double.infinity,
              decoration: BoxDecoration(color: const Color(0xFFD5E4EB), borderRadius: BorderRadius.circular(20)),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: _loading.value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF087BE8), Color(0xFF12BFAE)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.language == 'en' ? 'Loading app, please wait...' : widget.language == 'hi' ? 'ऐप लोड हो रही है, कृपया प्रतीक्षा करें...' : 'ایپ لوڈ ہو رہی ہے، براہِ کرم انتظار کریں...',
            textDirection: widget.language == 'en' ? TextDirection.ltr : TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: widget.language == 'en' ? null : 'NotoNaskhArabic', color: const Color(0xFF073B83), fontSize: compact ? 12 : 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _FarmPainter extends CustomPainter {
  const _FarmPainter();
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final shortSide = w < h ? w : h;
    canvas.drawRect(
      Offset.zero & s,
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF9DDEFA), Color(0xFFEAF9FF)]).createShader(Offset.zero & s),
    );
    final sun = Offset(w * .81, h * .17);
    canvas.drawCircle(sun, shortSide * .075, Paint()..color = const Color(0xFFFFE99B));
    canvas.drawCircle(sun, shortSide * .105, Paint()..color = const Color(0x55FFF0B5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));
    _cloud(canvas, Offset(w * .16, h * .16), .82);
    _cloud(canvas, Offset(w * .62, h * .25), .60);

    final hill = Path()
      ..moveTo(0, h * .55)
      ..cubicTo(w * .18, h * .36, w * .31, h * .49, w * .47, h * .51)
      ..cubicTo(w * .69, h * .39, w * .82, h * .38, w, h * .51)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFF73C58A));

    final meadow = Path()
      ..moveTo(0, h * .62)
      ..cubicTo(w * .21, h * .50, w * .35, h * .63, w * .55, h * .59)
      ..cubicTo(w * .77, h * .53, w * .87, h * .58, w, h * .55)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      meadow,
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF75C957), Color(0xFF269C4D)]).createShader(Offset(0, h * .54) & Size(w, h * .46)),
    );

    final grass = Paint()..color = const Color(0xFFB7E77B)..strokeWidth = 2..strokeCap = StrokeCap.round;
    for (var i = 0; i < 20; i++) {
      final x = w * (i / 20);
      final y = h * (.86 + (i % 3) * .035);
      canvas.drawLine(Offset(x, y), Offset(x - 3, y - 9), grass);
      canvas.drawLine(Offset(x + 2, y), Offset(x + 6, y - 7), grass);
    }
    for (var i = 0; i < 8; i++) {
      final x = w * ((i * 37 % 97) / 100);
      final y = h * (.77 + (i % 3) * .055);
      canvas.drawCircle(Offset(x, y), 2.5, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(x, y), 1.2, Paint()..color = const Color(0xFFFFD65B));
    }
  }

  void _cloud(Canvas canvas, Offset c, double k) {
    final p = Paint()..color = const Color(0xDFFFFFFF);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(0, 5 * k), width: 75 * k, height: 22 * k), Radius.circular(14 * k)), p);
    canvas.drawCircle(c.translate(-19 * k, 0), 14 * k, p);
    canvas.drawCircle(c.translate(1 * k, -8 * k), 19 * k, p);
    canvas.drawCircle(c.translate(22 * k, 1 * k), 13 * k, p);
  }
  @override
  bool shouldRepaint(covariant _FarmPainter oldDelegate) => false;
}

class _AnimalPainter extends CustomPainter {
  const _AnimalPainter({required this.buffalo, required this.phase});
  final bool buffalo;
  final double phase;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 220, size.height / 135);
    canvas.drawOval(const Rect.fromLTWH(39, 107, 143, 16), Paint()..color = const Color(0x332B5734));
    final legs = Paint()
      ..color = buffalo ? const Color(0xFF29343C) : const Color(0xFFEDEBE2)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final hooves = Paint()..color = const Color(0xFF273341)..strokeWidth = 7..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final x = [75.0, 111.0, 145.0, 164.0][i];
      canvas.save();
      canvas.translate(x, 88);
      canvas.rotate(math.sin(phase + i * 1.7) * .55);
      canvas.drawLine(Offset.zero, const Offset(0, 26), legs);
      canvas.drawLine(const Offset(0, 25), const Offset(5, 27), hooves);
      canvas.restore();
    }
    final coat = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: buffalo ? const [Color(0xFF53616A), Color(0xFF26343E)] : const [Color(0xFFFFFFFF), Color(0xFFE5E7DF)],
      ).createShader(const Rect.fromLTWH(38, 35, 140, 68));
    canvas.drawOval(const Rect.fromLTWH(42, 38, 127, 59), coat);
    if (buffalo) {
      final dark = Paint()..color = const Color(0xFF202D36);
      canvas.drawOval(const Rect.fromLTWH(49, 43, 70, 48), dark);
      canvas.drawOval(const Rect.fromLTWH(106, 43, 51, 47), dark);
    } else {
      final patch = Paint()..color = const Color(0xFF263747);
      final a = Path()..moveTo(60, 48)..cubicTo(68, 37, 91, 39, 96, 52)..lineTo(87, 73)..cubicTo(76, 82, 58, 70, 60, 48)..close();
      final b = Path()..moveTo(119, 42)..cubicTo(132, 36, 151, 45, 153, 57)..lineTo(137, 77)..lineTo(119, 68)..close();
      canvas.drawPath(a, patch);
      canvas.drawPath(b, patch);
    }
    final tail = Path()..moveTo(48, 57)..quadraticBezierTo(25, 42, 25, 19 + math.sin(phase) * 5);
    canvas.drawPath(tail, Paint()..color = const Color(0xFF26343E)..strokeWidth = 5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
    canvas.drawCircle(Offset(25, 19 + math.sin(phase) * 5), 4, Paint()..color = const Color(0xFF27343D));
    canvas.drawOval(const Rect.fromLTWH(150, 39, 51, 53), Paint()..color = buffalo ? const Color(0xFF34414A) : const Color(0xFFF5F4EC));
    final ears = Paint()..color = buffalo ? const Color(0xFF303D46) : const Color(0xFFF4F2E8);
    canvas.drawOval(const Rect.fromLTWH(143, 43, 28, 14), ears);
    canvas.drawOval(const Rect.fromLTWH(185, 43, 27, 14), ears);
    if (buffalo) {
      final horns = Paint()..color = const Color(0xFFF1E8D0)..strokeWidth = 8..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
      final left = Path()..moveTo(157, 46)..quadraticBezierTo(132, 17, 119, 35);
      final right = Path()..moveTo(190, 46)..quadraticBezierTo(214, 13, 226, 34);
      canvas.drawPath(left, horns);
      canvas.drawPath(right, horns);
    } else {
      final horns = Paint()..color = const Color(0xFFE7D9B5)..strokeWidth = 5..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(164, 43), const Offset(157, 31), horns);
      canvas.drawLine(const Offset(190, 43), const Offset(198, 31), horns);
    }
    canvas.drawOval(const Rect.fromLTWH(184, 68, 28, 17), Paint()..color = buffalo ? const Color(0xFF817D78) : const Color(0xFFE7A8A0));
    final eye = Paint()..color = const Color(0xFF152431);
    canvas.drawCircle(const Offset(174, 58), 2.6, eye);
    canvas.drawCircle(const Offset(194, 58), 2.6, eye);
    if (!buffalo) {
      canvas.drawOval(const Rect.fromLTWH(92, 90, 31, 13), Paint()..color = const Color(0xFFE7B2A7));
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _AnimalPainter oldDelegate) => oldDelegate.phase != phase || oldDelegate.buffalo != buffalo;
}

class _MilkPainter extends CustomPainter {
  const _MilkPainter({required this.progress});
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 220, size.height / 220);
    canvas.save();
    canvas.translate(62, 57);
    canvas.rotate(.42);
    final can = Path()
      ..moveTo(-43, -37)..lineTo(24, -37)..lineTo(31, -18)..lineTo(27, 37)
      ..quadraticBezierTo(25, 47, 13, 47)..lineTo(-32, 47)
      ..quadraticBezierTo(-43, 45, -43, 34)..close();
    canvas.drawPath(can, Paint()..shader = const LinearGradient(colors: [Color(0xFF718B9C), Color(0xFFF9FFFF), Color(0xFF8BA7B6), Color(0xFFEAF7FB)]).createShader(const Rect.fromLTWH(-45, -40, 80, 90)));
    canvas.drawPath(can, Paint()..color = const Color(0xFF648194)..style = PaintingStyle.stroke..strokeWidth = 3);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-40, -44, 65, 11), const Radius.circular(5)), Paint()..color = const Color(0xFFEAF7FB));
    canvas.drawLine(const Offset(-34, 5), const Offset(21, 5), Paint()..color = const Color(0xFF6D899B)..strokeWidth = 3);
    canvas.restore();
    final stream = Path()..moveTo(100, 82)..cubicTo(116, 93, 124, 99, 142, 118);
    canvas.drawPath(stream, Paint()..color = const Color(0xFFEAFBFF)..strokeWidth = 13..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
    canvas.drawPath(stream, Paint()..color = Colors.white..strokeWidth = 8..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
    final glass = Path()..moveTo(119, 100)..lineTo(207, 100)..lineTo(195, 207)..quadraticBezierTo(163, 220, 132, 207)..close();
    canvas.drawPath(glass, Paint()..color = const Color(0x55FFFFFF));
    canvas.save();
    canvas.clipPath(glass);
    final milkTop = 204.0 - progress.clamp(0.0, 1.0).toDouble() * 88.0;
    canvas.drawRect(
      Rect.fromLTWH(115, milkTop, 100, 110),
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFFEF5), Color(0xFFEAF5F6)]).createShader(Rect.fromLTWH(115, milkTop, 100, 110)),
    );
    final wave = Path()..moveTo(119, milkTop + 2)..quadraticBezierTo(137, milkTop - 5, 155, milkTop + 1)..quadraticBezierTo(178, milkTop + 7, 207, milkTop)..lineTo(207, milkTop + 9)..lineTo(119, milkTop + 9)..close();
    canvas.drawPath(wave, Paint()..color = Colors.white);
    canvas.restore();
    canvas.drawPath(glass, Paint()..color = const Color(0xFF6AADC8)..style = PaintingStyle.stroke..strokeWidth = 4);
    canvas.drawLine(const Offset(125, 105), const Offset(201, 105), Paint()..color = Colors.white..strokeWidth = 5..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(132, 122), const Offset(135, 187), Paint()..color = const Color(0xBFFFFFFF)..strokeWidth = 4..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(145 + math.sin(progress * math.pi * 5) * 3, 118), 3, Paint()..color = Colors.white);
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _MilkPainter oldDelegate) => oldDelegate.progress != progress;
}
