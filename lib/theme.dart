import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFF12100E);
  static const panel = Color(0xF21C1916);
  static const panelSolid = Color(0xFF1A1612);
  static const amber = Color(0xFFE0A14A);
  static const amberSoft = Color(0xFFF2C56B);
  static const cream = Color(0xFFF2E6D0);
  static const muted = Color(0xFFCBB79A);
  static const dim = Color(0xFF8A7B68);
  static const danger = Color(0xFFC45C3E);
  static const ok = Color(0xFF7D9A6A);
  static const border = Color(0xFF3A3228);
  static const chip = Color(0xFF221C18);
  static const water = Color(0xFF5BA3B5);
  static const surface = Color(0xFF3A2A22);
}

class Fonts {
  static const barlow = 'Barlow';
  static const condensed = 'BarlowCondensed';
}

ThemeData bunkerTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: C.bg,
    colorScheme: const ColorScheme.dark(
      primary: C.amber,
      secondary: C.muted,
      surface: C.panelSolid,
      error: C.danger,
    ),
    fontFamily: Fonts.barlow,
    useMaterial3: true,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: C.cream,
      displayColor: C.amber,
      fontFamily: Fonts.barlow,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: C.cream,
    ),
  );
}

class BunkerButton extends StatelessWidget {
  const BunkerButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 56,
    this.selected = false,
    this.danger = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onTap;
  final double height;
  final bool selected;
  final bool danger;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final border = danger
        ? C.danger
        : selected
            ? C.amberSoft
            : C.amber;
    final child = Semantics(
      button: true,
      label: label,
      child: Material(
        color: selected ? const Color(0xFF3A3228) : const Color(0xFF2A241E),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: 2),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: Fonts.barlow,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                height: 1.15,
                color: onTap == null ? C.dim : C.cream,
              ),
            ),
          ),
        ),
      ),
    );
    if (expand) return SizedBox(width: double.infinity, child: child);
    return child;
  }
}

class TitleText extends StatelessWidget {
  const TitleText(
    this.text, {
    super.key,
    this.size = 28,
    this.color = C.amber,
    this.center = false,
    this.condensed = true,
  });

  final String text;
  final double size;
  final Color color;
  final bool center;
  final bool condensed;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        fontFamily: condensed ? Fonts.condensed : Fonts.barlow,
        fontWeight: FontWeight.w700,
        fontSize: size,
        color: color,
        height: 1.1,
      ),
    );
  }
}

class BodyText extends StatelessWidget {
  const BodyText(
    this.text, {
    super.key,
    this.size = 15,
    this.color = C.cream,
    this.center = false,
    this.maxLines,
  });

  final String text;
  final double size;
  final Color color;
  final bool center;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.visible : TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: Fonts.barlow,
        fontSize: size,
        color: color,
        height: 1.35,
      ),
    );
  }
}

class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: BodyText(label, size: 13, color: C.muted, maxLines: 1),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (value / 100).clamp(0, 1),
              minHeight: 10,
              backgroundColor: const Color(0xFF1A1612),
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        BodyText('${value.round()}', size: 12, color: C.dim, maxLines: 1),
      ],
    );
  }
}
