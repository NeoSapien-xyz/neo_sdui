import 'package:flutter/widgets.dart';

import '../theme/neo_sdui_theme.dart';

/// Renders a wire text value as themed text, painting accent-tagged text with
/// the accent *role* the theme resolves — the primary accent, or a named hue
/// (e.g. `"brand"`) for a second gradient on the same screen.
///
/// [value] may be a plain `String`, or a list of runs mixing plain strings and
/// `{"text": "...", "tone": "accent"}` maps — e.g.
/// `["Sign in with your ", {"text": "NeoSapien", "tone": "accent"}, " account"]`.
/// Each run's effective tone is its own `tone`, else the block-level [tone]. The
/// theme turns a tone into its [NeoAccent] (a gradient when set, else a flat
/// color). The wire names only the role; the stops live in the theme (KTD9).
///
/// With no gradient for that role, accent text falls back to the flat role color
/// and a single run collapses to a plain [Text] — byte-identical to the flat
/// render, so a theme that sets no gradient regenerates no goldens.
///
/// A whole line sharing one gradient paints with a single [ShaderMask] (so it
/// wraps across lines normally); gradient runs *inside* a mixed line each ride in
/// a baseline-aligned [WidgetSpan], so two hues can coexist on one line.
/// [stretch] lays a whole-line gradient over the full available width (the text
/// left-aligned inside it) instead of the tight glyph box — so a short line
/// samples only the left of the gradient and ends brighter, matching figma's
/// full-width `flex-1` gradient element (the use-case row titles). Inline
/// (mixed-run) gradients ignore it; they stay atomic per run.
Widget neoText(
  NeoSduiTheme theme,
  Object? value,
  TextStyle style, {
  String? tone,
  bool stretch = false,
}) {
  final runs = _parseRuns(value);
  NeoAccent? accentOf(_Run r) => theme.accentFor(r.tone ?? tone);

  // No accent anywhere -> plain. A single run collapses to a plain Text so the
  // common case stays golden-stable.
  if (!runs.any((r) => accentOf(r) != null)) {
    if (runs.length <= 1) {
      return Text(runs.isEmpty ? '' : runs.first.text, style: style);
    }
    return Text.rich(TextSpan(
        children: [for (final r in runs) TextSpan(text: r.text, style: style)]));
  }

  // Single run: shade with its gradient, else color it (no ShaderMask), so the
  // flat-accent case stays a plain Text.
  if (runs.length == 1) {
    final a = accentOf(runs.first)!;
    return a.gradient != null
        ? _shaded(a.gradient!, runs.first.text, style, stretch: stretch)
        : Text(runs.first.text, style: style.copyWith(color: a.color));
  }

  // Whole multi-run line sharing one gradient -> a single ShaderMask (wraps).
  final accents = [for (final r in runs) accentOf(r)];
  if (accents.every((a) => a?.gradient != null) &&
      {for (final a in accents) a!.gradient}.length == 1) {
    return _shaded(accents.first!.gradient!, runs.map((r) => r.text).join(), style,
        stretch: stretch);
  }

  // Mixed: each run by its own role — gradient run -> a shaded WidgetSpan; a
  // flat-accent run -> a colored span; a plain run -> the default span.
  return Text.rich(TextSpan(children: [
    for (var i = 0; i < runs.length; i++)
      if (accents[i]?.gradient != null)
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          // ponytail: an inline gradient run is an atomic box — it won't
          // line-wrap internally. Fine for brand words ("NeoSapien"); split a
          // long accent phrase into separate runs if it must wrap.
          child: _shaded(accents[i]!.gradient!, runs[i].text, style),
        )
      else if (accents[i] != null)
        TextSpan(text: runs[i].text, style: style.copyWith(color: accents[i]!.color))
      else
        TextSpan(text: runs[i].text, style: style),
  ]));
}

/// A `Text` painted through [gradient]: the gradient fills the glyph shapes
/// (`srcIn` over opaque white text — the canonical gradient-text idiom; the
/// child's own color is irrelevant, only its coverage). With [stretch] the text
/// is left-aligned in a full-width box so the ShaderMask bounds span the whole
/// row (figma's `flex-1` gradient element), not the tight glyph box.
Widget _shaded(Gradient gradient, String text, TextStyle style,
    {bool stretch = false}) {
  Widget child = Text(text,
      style: style.copyWith(color: const Color(0xFFFFFFFF)),
      textAlign: stretch ? TextAlign.start : null);
  if (stretch) child = SizedBox(width: double.infinity, child: child);
  return ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (bounds) => gradient.createShader(bounds),
    child: child,
  );
}

class _Run {
  const _Run(this.text, this.tone);
  final String text;

  /// The run's own tone name (e.g. `"accent"`, `"brand"`), or null to inherit
  /// the block-level tone. The theme resolves the name to a [NeoAccent].
  final String? tone;
}

/// A wire text value -> runs. `String` -> one plain run; a `List` -> each entry
/// is a plain string or a `{text, tone}` map (any `tone` name flags an accent
/// run). Anything else -> no runs. Uses guarded reads, never a raw cast, so a
/// malformed value degrades rather than throwing at mount (see the guarded-reads
/// resilience pattern in docs/solutions/architecture-patterns/).
List<_Run> _parseRuns(Object? value) {
  if (value is String) return [_Run(value, null)];
  if (value is List) {
    return [
      for (final e in value)
        if (e is String)
          _Run(e, null)
        else if (e is Map)
          _Run(e['text'] is String ? e['text'] as String : '',
              e['tone'] is String ? e['tone'] as String : null),
    ];
  }
  return const [];
}
