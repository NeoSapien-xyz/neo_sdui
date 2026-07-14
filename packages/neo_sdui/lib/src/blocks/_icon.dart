import 'package:flutter/widgets.dart';

import '../theme/neo_sdui_theme.dart';

/// A block's leading role-icon, or null when the wire names none / the theme
/// doesn't map it (draw nothing — graceful, like a null accentGradient). The
/// wire carries only the icon *name* (e.g. `"sparkle"`); the glyph, size and
/// tone color are the theme's (KTD9). `tone` tints it via [NeoSduiTheme.toneColor]
/// — accent → the accent green, critical → danger, else onSurface.
Widget? leadingIcon(
  NeoSduiTheme theme,
  String? name,
  String? tone, {
  double size = 16,
}) {
  final data = theme.iconFor(name);
  if (data == null) return null;
  return Icon(data, size: size, color: theme.toneColor(tone));
}
