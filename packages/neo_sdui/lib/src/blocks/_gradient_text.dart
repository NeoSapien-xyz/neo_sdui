import 'package:flutter/widgets.dart';

import '../theme/neo_sdui_theme.dart';

/// Renders a wire text value as themed text, painting accent-tagged text with
/// the theme's [NeoSduiTheme.accentGradient] when one is set.
///
/// [value] may be a plain `String`, or a list of runs mixing plain strings and
/// `{"text": "...", "tone": "accent"}` maps — e.g.
/// `["Sign in with your ", {"text": "NeoSapien", "tone": "accent"}, " account"]`.
/// A run tagged `accent` (or the whole line, when the block passes [accentAll])
/// takes the gradient. The wire names only the intent (`tone:"accent"`); the
/// gradient stops live in the theme, client-owned, never on the wire (KTD9).
///
/// With no gradient set, accent text falls back to the flat `accent` role and a
/// single run collapses to a plain [Text] — byte-identical to the pre-gradient
/// render, so a theme that leaves `accentGradient` null regenerates no goldens.
///
/// A whole-accent line paints with one [ShaderMask] over the `Text` (so it wraps
/// across lines normally); a gradient run *inside* a mixed line rides in a
/// baseline-aligned [WidgetSpan] so the gradient is scoped to that run's bounds.
Widget neoText(
  NeoSduiTheme theme,
  Object? value,
  TextStyle style, {
  bool accentAll = false,
}) {
  final runs = _parseRuns(value);
  final grad = theme.accentGradient;
  final accentStyle = style.copyWith(color: theme.accent);

  bool isAccent(_Run r) => accentAll || r.accent;

  // No gradient available (or no accent text) -> flat. A single run collapses to
  // a plain Text so the common case stays golden-stable.
  if (grad == null || !runs.any(isAccent)) {
    if (runs.length <= 1) {
      final r = runs.isEmpty ? const _Run('', false) : runs.first;
      return Text(r.text, style: isAccent(r) ? accentStyle : style);
    }
    return Text.rich(TextSpan(children: [
      for (final r in runs)
        TextSpan(text: r.text, style: isAccent(r) ? accentStyle : style),
    ]));
  }

  // Whole line is accent -> one ShaderMask over the joined text (wraps normally).
  if (runs.every(isAccent)) {
    return _shaded(grad, runs.map((r) => r.text).join(), style);
  }

  // Mixed: only the accent runs get a gradient WidgetSpan; plain runs stay text.
  return Text.rich(TextSpan(children: [
    for (final r in runs)
      if (isAccent(r))
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          // ponytail: an inline gradient run is an atomic box — it won't
          // line-wrap internally. Fine for brand words ("NeoSapien"); split a
          // long accent phrase into separate runs if it must wrap.
          child: _shaded(grad, r.text, style),
        )
      else
        TextSpan(text: r.text, style: style),
  ]));
}

/// A `Text` painted through [gradient]: the gradient fills the glyph shapes
/// (`srcIn` over opaque white text — the canonical gradient-text idiom; the
/// child's own color is irrelevant, only its coverage).
Widget _shaded(Gradient gradient, String text, TextStyle style) => ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: Text(text, style: style.copyWith(color: const Color(0xFFFFFFFF))),
    );

class _Run {
  const _Run(this.text, this.accent);
  final String text;
  final bool accent;
}

/// A wire text value -> runs. `String` -> one plain run; a `List` -> each entry
/// is a plain string or a `{text, tone}` map (tone `accent` flags the gradient
/// run). Anything else -> no runs. Uses guarded reads, never a raw cast, so a
/// malformed value degrades rather than throwing at mount (see the guarded-reads
/// resilience pattern in docs/solutions/architecture-patterns/).
List<_Run> _parseRuns(Object? value) {
  if (value is String) return [_Run(value, false)];
  if (value is List) {
    return [
      for (final e in value)
        if (e is String)
          _Run(e, false)
        else if (e is Map)
          _Run(e['text'] is String ? e['text'] as String : '',
              e['tone'] == 'accent'),
    ];
  }
  return const [];
}
