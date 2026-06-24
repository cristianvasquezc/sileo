import 'package:flutter/widgets.dart';

import 'options.dart';

/// State tone colours
const Map<SileoState, Color> kSileoStateColors = <SileoState, Color>{
  SileoState.success: Color(0xFF3AC530),
  SileoState.loading: Color(0xFF737373),
  SileoState.error: Color(0xFFFB2C36),
  SileoState.warning: Color(0xFFF0B100),
  SileoState.info: Color(0xFF00A6F4),
  SileoState.action: Color(0xFF2B7FFF),
};

/// The tone colour for a state (badge/title/button), honouring an override.
Color sileoToneColor(SileoState state, [Color? override]) =>
    override ?? kSileoStateColors[state]!;

/// Default fill colours when a [SileoTheme] is active. The pill deliberately
/// inverts against the page: dark pill in light mode, light pill in dark mode.
const Color kSileoLightThemeFill = Color(0xFF1A1A1A);
const Color kSileoDarkThemeFill = Color(0xFFF2F2F2);

/// The default fill when no theme and no explicit fill are set.
const Color kSileoDefaultFill = Color(0xFFFFFFFF);

/// Description text colour derived from the fill's luminance, so text always
/// contrasts with the pill for any fill (50% black on light fills, 50% white on
/// dark ones).
Color sileoDescriptionColor(Color fill) => fill.computeLuminance() > 0.5
    ? const Color(0x80000000) // black @ 50%
    : const Color(0x80FFFFFF); // white @ 50%

/// Badge background = tone at 20% opacity.
Color sileoBadgeBackground(Color tone) => tone.withValues(alpha: 0.20);

/// Action button background = tone @ 15%.
Color sileoButtonBackground(Color tone) => tone.withValues(alpha: 0.15);

/// Action button hover background = tone @ 25%.
Color sileoButtonHoverBackground(Color tone) => tone.withValues(alpha: 0.25);
