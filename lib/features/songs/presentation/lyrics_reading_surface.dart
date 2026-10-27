import 'package:flutter/material.dart';

/// Gives the complete lyrics a single, quiet reading surface.
///
/// Emphasis belongs to the song as a whole; individual lines have no active,
/// dimmed, or playback-synchronized state.
class LyricsReadingSurface extends StatelessWidget {
  const LyricsReadingSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF102B23);
    const foreground = Color(0xFFF5F7F2);
    const supporting = Color(0xFFCADDD2);
    const accent = Color(0xFFB5D8C2);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme.apply(
      bodyColor: foreground,
      displayColor: foreground,
    );
    final bodyStyle = textTheme.bodyLarge!.copyWith(
      color: foreground,
      fontWeight: FontWeight.w600,
      height: 1.6,
    );
    final readingTheme = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        brightness: Brightness.dark,
        surface: background,
        onSurface: foreground,
        onSurfaceVariant: supporting,
        primary: accent,
        secondary: accent,
        outlineVariant: const Color(0xFF385347),
      ),
      textTheme: textTheme.copyWith(bodyLarge: bodyStyle),
      textSelectionTheme: const TextSelectionThemeData(
        selectionColor: Color(0xFF3C6552),
        selectionHandleColor: accent,
        cursorColor: accent,
      ),
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
            child: SizedBox(
              width: double.infinity,
              child: Theme(
                data: readingTheme,
                child: DefaultTextStyle(style: bodyStyle, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
