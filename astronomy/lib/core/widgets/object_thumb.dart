import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../astro/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// Accent colour and icon per object type, shared by tiles, chips and lists.
extension SkyObjectTypeStyle on SkyObjectType {
  Color get color => switch (this) {
        SkyObjectType.star => AppColors.cyan,
        SkyObjectType.planet => AppColors.planetBlue,
        SkyObjectType.galaxy => AppColors.violetSoft,
        SkyObjectType.nebula => AppColors.pink,
        SkyObjectType.cluster => AppColors.warm,
      };

  IconData get icon => switch (this) {
        SkyObjectType.star => AppIcons.star,
        SkyObjectType.planet => AppIcons.orbit,
        SkyObjectType.galaxy => AppIcons.galaxy,
        SkyObjectType.nebula => AppIcons.cloudy,
        SkyObjectType.cluster => AppIcons.sparkles,
      };

  String get plural => switch (this) {
        SkyObjectType.star => 'Stars',
        SkyObjectType.planet => 'Planets',
        SkyObjectType.galaxy => 'Galaxies',
        SkyObjectType.nebula => 'Nebulae',
        SkyObjectType.cluster => 'Clusters',
      };
}

/// Square object thumbnail: the catalog photo when there is one, otherwise a
/// painted stand-in coloured by type (no stock photos pretending to be the object).
class ObjectThumb extends StatelessWidget {
  const ObjectThumb({super.key, required this.object, this.size = 56, this.radius = 14});

  final SkyObject object;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final image = object.image;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.surfaceBorderStrong),
        ),
        child: image != null
            ? Image.asset(image, fit: BoxFit.cover, alignment: const Alignment(0.1, -0.6))
            : CustomPaint(painter: _ThumbPainter(object.type, object.id.hashCode)),
      ),
    );
  }
}

class _ThumbPainter extends CustomPainter {
  _ThumbPainter(this.type, this.seed);

  final SkyObjectType type;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final c = rect.center;
    final color = type.color;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF0B1030));
    final rnd = math.Random(seed);
    final dot = Paint();
    for (var i = 0; i < 14; i++) {
      dot.color = AppColors.text.withValues(alpha: 0.25 + rnd.nextDouble() * 0.5);
      canvas.drawCircle(Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height), 0.5 + rnd.nextDouble() * 0.7, dot);
    }
    final glow = Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.12);
    switch (type) {
      case SkyObjectType.galaxy:
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(-0.5 + rnd.nextDouble());
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: size.width * 0.8, height: size.height * 0.28),
            glow..color = color.withValues(alpha: 0.55));
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: size.width * 0.22, height: size.height * 0.12),
            Paint()..color = AppColors.text.withValues(alpha: 0.9));
        canvas.restore();
      case SkyObjectType.nebula:
        for (var i = 0; i < 3; i++) {
          final o = Offset(c.dx + (rnd.nextDouble() - 0.5) * size.width * 0.35, c.dy + (rnd.nextDouble() - 0.5) * size.height * 0.35);
          canvas.drawCircle(o, size.width * (0.18 + rnd.nextDouble() * 0.12),
              glow..color = (i.isEven ? color : AppColors.violet).withValues(alpha: 0.5));
        }
      case SkyObjectType.cluster:
        for (var i = 0; i < 18; i++) {
          final a = rnd.nextDouble() * math.pi * 2;
          final r = rnd.nextDouble() * size.width * 0.28;
          canvas.drawCircle(c + Offset(math.cos(a) * r, math.sin(a) * r), 0.8 + rnd.nextDouble() * 1.2,
              Paint()..color = Color.lerp(color, AppColors.text, rnd.nextDouble())!);
        }
      case SkyObjectType.star:
        canvas.drawCircle(c, size.width * 0.22, glow..color = color.withValues(alpha: 0.6));
        canvas.drawCircle(c, size.width * 0.07, Paint()..color = AppColors.text);
      case SkyObjectType.planet:
        canvas.drawCircle(c, size.width * 0.2, Paint()..shader = RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: [AppColors.text, color, const Color(0xFF1A2160)],
        ).createShader(Rect.fromCircle(center: c, radius: size.width * 0.2)));
    }
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.type != type || old.seed != seed;
}
