import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../action/neo_action.dart';
import '../theme/neo_sdui_scope.dart';
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
///
/// A run may carry `"link": "https://…"` (the PWA's inline `<a>`): it renders
/// underlined in its own color and opens the URL through the scope's dispatch.
/// Only http/https links with a host are tappable; anything else stays plain.
Widget neoText(
  NeoSduiTheme theme,
  Object? value,
  TextStyle style, {
  String? tone,
  bool stretch = false,
}) {
  final runs = _parseRuns(value);
  if (runs.any((r) => r.link != null)) {
    return _LinkedRuns(runs: runs, style: style, tone: tone);
  }
  // A mono run rides the theme's `mono` slot, never accent/gradient text, so it's
  // excluded from accent resolution.
  NeoAccent? accentOf(_Run r) => r.mono ? null : theme.accentFor(r.tone ?? tone);
  final anyMono = runs.any((r) => r.mono);

  // No accent and no mono -> plain. A single run collapses to a plain Text so the
  // common case stays golden-stable.
  if (!anyMono && !runs.any((r) => accentOf(r) != null)) {
    if (runs.length <= 1) {
      return Text(runs.isEmpty ? '' : runs.first.text, style: style);
    }
    return Text.rich(TextSpan(
        children: [for (final r in runs) TextSpan(text: r.text, style: style)]));
  }

  // Any mono run -> a per-run styled line: a mono run rides the `mono` slot (flat,
  // recolored only by an explicit tone — the figma grey inline `claude mcp list`);
  // the rest keep their accent/plain role. Mono is never gradient-shaded.
  if (anyMono) {
    return Text.rich(TextSpan(children: [
      for (final r in runs)
        if (r.mono)
          TextSpan(text: r.text, style: _monoStyle(theme, r.tone ?? tone))
        else if (accentOf(r)?.gradient != null)
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _shaded(accentOf(r)!.gradient!, r.text, style),
          )
        else if (accentOf(r) != null)
          TextSpan(text: r.text, style: _flat(theme, style, r.tone ?? tone, accentOf(r)!))
        else
          TextSpan(text: r.text, style: style),
    ]));
  }

  // Single run: shade with its gradient, else color it (no ShaderMask), so the
  // flat-accent case stays a plain Text.
  if (runs.length == 1) {
    final a = accentOf(runs.first)!;
    return a.gradient != null
        ? _shaded(a.gradient!, runs.first.text, style, stretch: stretch)
        : Text(runs.first.text,
            style: _flat(theme, style, runs.first.tone ?? tone, a));
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
        TextSpan(
            text: runs[i].text,
            style: _flat(theme, style, runs[i].tone ?? tone, accents[i]!))
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

/// The style for an inline `mono` run: the theme's `mono` slot, recolored only
/// when the run names an explicit tone (else the mono role's own color — the
/// figma grey inline command).
TextStyle _monoStyle(NeoSduiTheme theme, String? tone) {
  final a = theme.accentFor(tone);
  return a == null
      ? theme.mono
      : theme.mono.copyWith(
          color: a.color, fontWeight: tone == 'strong' ? FontWeight.w500 : null);
}

/// [style] recolored to [accent]; a `strong` tone also takes the emphasis weight
/// (w500), the `<strong>` analog — the wire names emphasis, the client owns weight.
TextStyle _flat(NeoSduiTheme theme, TextStyle style, String? tone, NeoAccent accent) =>
    (tone == 'strong' ? theme.emphasize(style) : style).copyWith(color: accent.color);

/// A run line with at least one inline link. Stateful only to own (and dispose)
/// one [TapGestureRecognizer] per link. Non-link runs keep their mono / flat
/// accent styling; a gradient run here renders flat (its role color), since a
/// shaded WidgetSpan can't share the line's tap targets.
class _LinkedRuns extends StatefulWidget {
  const _LinkedRuns({required this.runs, required this.style, this.tone});
  final List<_Run> runs;
  final TextStyle style;
  final String? tone;

  @override
  State<_LinkedRuns> createState() => _LinkedRunsState();
}

class _LinkedRunsState extends State<_LinkedRuns> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _clear() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final scope = NeoSduiScope.of(context);
    final theme = scope.theme;
    final style = widget.style;
    TextStyle runStyle(_Run r) {
      if (r.mono) return _monoStyle(theme, r.tone ?? widget.tone);
      final a = theme.accentFor(r.tone ?? widget.tone);
      return a == null ? style : _flat(theme, style, r.tone ?? widget.tone, a);
    }

    final spans = <InlineSpan>[];
    for (final r in widget.runs) {
      final rs = runStyle(r);
      if (r.link == null) {
        spans.add(TextSpan(text: r.text, style: rs));
        continue;
      }
      final rec = TapGestureRecognizer()
        ..onTap = () => scope.dispatch(context, ExternalUrl(r.link!));
      _recognizers.add(rec);
      spans.add(TextSpan(
        text: r.text,
        style: rs.copyWith(
            decoration: TextDecoration.underline, decorationColor: rs.color),
        recognizer: rec,
      ));
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

/// [raw] as a tappable web link: http/https with a host, else null.
Uri? _webLink(Object? raw) {
  if (raw is! String) return null;
  final uri = Uri.tryParse(raw);
  return uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty
      ? uri
      : null;
}

class _Run {
  const _Run(this.text, this.tone, {this.mono = false, this.link});
  final String text;

  /// Inline link target (http/https only; validated at parse).
  final Uri? link;

  /// The run's own tone name (e.g. `"accent"`, `"brand"`), or null to inherit
  /// the block-level tone. The theme resolves the name to a [NeoAccent].
  final String? tone;

  /// The run renders in the theme's `mono` slot — an inline command inside a
  /// caption (the figma grey IBM Plex Mono `/mcp` / `claude mcp list`). Never
  /// gradient-shaded; the wire flags it with `"mono": true` on the run.
  final bool mono;
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
              e['tone'] is String ? e['tone'] as String : null,
              mono: e['mono'] == true,
              link: _webLink(e['link'])),
    ];
  }
  return const [];
}
