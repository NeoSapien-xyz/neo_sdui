import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../action/neo_action.dart';
import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '../theme/neo_sdui_theme.dart';
import '_gradient_text.dart';
import '_grid.dart';
import '_media_frame.dart';
import '_motion.dart';
import '_neumorphic.dart';
import 'code.dart';

/// how_to's default thumbnail ratio when a step image omits one (matches media).
const double _defaultImageRatio = 358 / 221;

/// steps: numbered captions, each with an optional full-width `image` above the
/// row and/or a nested `blocks` list below it (composed content — a grid `group`
/// + `row` + `code` — where a baked image won't do). `layout:"row"` lays the
/// steps side by side (the compact 1·2·3 setup strip) instead of the default
/// vertical checklist. Each item builds in its own try/catch so one bad item
/// can't take out the rest (R8).
Widget buildSteps(BuildContext context, BlockNode node) {
  final scope = NeoSduiScope.of(context);
  final theme = scope.theme;
  final items = node.mapList('items');
  // The number badges' accent hue; default `accent`, but a screen can name a
  // second hue (e.g. `"brand"`) so step counts differ from accent headings.
  final numberTone = node.stringOr('tone') ?? 'accent';
  // Horizontal strip: equal-width cells (numbered badge over caption) in a Row.
  if (node.stringOr('layout') == 'row') {
    final carded = theme.stepCardColor != null;
    final row = Row(
      // Carded cells stretch to the tallest so the boxes align — a step whose
      // caption wraps to two lines doesn't leave its neighbours short. Bare
      // cells keep top-alignment (the how_to look), unchanged.
      crossAxisAlignment:
          carded ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: theme.spaceMd),
          Expanded(child: _cell(theme, i + 1, items[i], numberTone)),
        ],
      ],
    );
    return carded ? IntrinsicHeight(child: row) : row;
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
          child: _item(scope, i + 1, items[i], numberTone),
        ),
    ],
  );
}

/// One horizontal-strip cell: a circular number badge over the caption (and an
/// optional muted detail). Guards a malformed caption like the vertical `_item`
/// — a bad item keeps its badge and shows a placeholder, so numbering survives.
Widget _cell(NeoSduiTheme theme, int n, Map<String, Object?> item, String tone) {
  final cap = item['caption'];
  final caption = (cap is String || cap is List)
      ? neoText(theme, cap, theme.body)
      : Text('—', key: const Key('step-error'), style: theme.body);
  final detail = item['detail'];
  final content = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _badge(theme, n, tone),
      SizedBox(height: theme.spaceSm),
      caption,
      if (detail is String) ...[
        const SizedBox(height: 4),
        Text(detail, style: theme.caption),
      ],
    ],
  );
  // Boxed cell when the theme sets a step-card fill; otherwise bare (the how_to
  // checklist), byte-identical to before.
  final bg = theme.stepCardColor;
  if (bg == null) return content;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: bg,
      border: theme.stepCardBorderColor == null
          ? null
          : Border.all(color: theme.stepCardBorderColor!),
      borderRadius: theme.radiusMd,
    ),
    child: content,
  );
}

/// The number badge for a horizontal step: the tone-colored digit on a filled
/// 20px disc (the tone at 10% alpha — the figma step circle). Fill + digit color
/// are theme roles (via `toneColor`), never the wire.
Widget _badge(NeoSduiTheme theme, int n, String tone) {
  final c = theme.toneColor(tone);
  return Container(
    width: 20,
    height: 20,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: c.withValues(alpha: 0.1),
    ),
    // Flat tone color (not the accent gradient) — the figma digit is a solid
    // hue, so this reads the role color directly rather than routing through
    // neoText's gradient path.
    // geometry: fits the digit to the 20px badge above — glyph metrics, not the
    // type scale. Not the theme's to set.
    child: Text('$n', style: theme.caption.copyWith(color: c, fontSize: 11)),
  );
}

/// A numbered bare-step row: the tone-colored index, a gap, then the item
/// [body]. Shared by the bare checklist path and its (and the carded path's) R8
/// error fallback, so the number + placeholder layout can't drift between them.
Widget _numberedRow(
        NeoSduiTheme theme, int n, String numberTone, TextStyle index, Widget body) =>
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        neoText(theme, '$n', index, tone: numberTone),
        const SizedBox(width: 12),
        Expanded(child: body),
      ],
    );

Widget _item(NeoSduiScope scope, int n, Map<String, Object?> item, String numberTone) {
  final theme = scope.theme;
  // The how_to "List Item": an image-topped card whose details panel carries a
  // muted "Step n:" label + caption (and any detail/code/nested blocks). Gated
  // on the same `stepCardColor` role the row strip uses, so a theme that opts
  // into step cards gets them in both layouts; a theme without it keeps the bare
  // checklist below, byte-identical.
  final index = theme.body.copyWith(fontWeight: FontWeight.w600);
  if (theme.stepCardColor != null) {
    // R8 for the carded path too: its helpers each degrade on their own, but a
    // wrapping catch keeps one malformed carded item from taking out the whole
    // steps block — symmetric with the bare path's try/catch below.
    try {
      return _cardedItem(scope, n, item, numberTone);
    } catch (_) {
      return _numberedRow(theme, n, numberTone, index,
          Text('—', key: const Key('step-error'), style: theme.body));
    }
  }
  Widget body;
  try {
    final cap = item['caption'];
    if (cap is! String && cap is! List) {
      throw StateError('step caption must be a string or a run list');
    }
    final caption = neoText(theme, cap, theme.body);
    // Optional muted sub-line and optional copyable command under the caption;
    // both absent -> caption only (R4).
    final detail = item['detail'];
    final code = item['code'];
    final extras = <Widget>[
      if (detail is String) Text(detail, style: theme.caption),
      if (code is String) ...[
        SizedBox(height: theme.spaceSm),
        codeChip(code),
      ],
    ];
    body = extras.isEmpty
        ? caption
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [caption, ...extras],
          );
  } catch (_) {
    // Bad item -> keep the number, show a placeholder, keep numbering intact.
    body = Text('—', key: const Key('step-error'), style: theme.body);
  }
  final row = _numberedRow(theme, n, numberTone, index, body);
  // A step's rich content: an optional full-width baked `image` above the row
  // (the how-to screenshot), and/or a nested `blocks` list below it — composed
  // content a baked image can't be, e.g. a grid `group` wrapping a `row` + a
  // `code` command (the Claude-guide step-1 card). Both absent -> the row alone.
  final image = _stepImage(theme, item);
  final blocks = scope.buildBlocks(_stepBlocks(item));
  if (image == null && blocks.isEmpty) return row;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (image != null) ...[image, SizedBox(height: theme.spaceSm)],
      row,
      if (blocks.isNotEmpty) ...[
        SizedBox(height: theme.spaceSm),
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: theme.blockSpacing),
          blocks[i],
        ],
      ],
    ],
  );
}

/// The carded vertical step — the figma "List Item": a hero (a full-bleed
/// screenshot flush to the card top, OR a prominent copyable command card when a
/// command has no screenshot), then a details panel with a muted "Step n:" label
/// over the caption. A step's `code` command is NEVER a boxed copy-chip here: it
/// either rides *inline* in the caption (accent + underline — the figma
/// inline-command look, when the step also has a screenshot) or becomes the hero
/// [_CommandCard] (the Claude `claude mcp add` step, when it has no screenshot).
/// Labels are 0-indexed ("Step 0:") to match the figma numbering. All look is
/// theme roles: `surface` fill, `radiusLg`, `stepCardBorderColor` hairline,
/// `cardShadow`. Guards a malformed caption like the bare `_item`.
Widget _cardedItem(NeoSduiScope scope, int n, Map<String, Object?> item, String numberTone) {
  final theme = scope.theme;
  final cap = item['caption'];
  // Caption is white (not the muted body color), medium weight; a bare-string
  // caption also gets its URLs underlined (the figma link look).
  final capStyle =
      theme.body.copyWith(color: theme.textPrimary, fontWeight: FontWeight.w500);
  final detail = item['detail'];
  final code = item['code'];
  final image = _stepImage(theme, item, clip: false);
  final hasCode = code is String && code.isNotEmpty;
  final imageUrl = item['image'];
  // The guide's key command (Claude's `claude mcp add`) is flagged
  // `emphasis:"high"`: it becomes the hero command card — a grid-textured green
  // panel with an optional terminal screenshot, the centered command, and a Copy
  // button. Its own screenshot rides *inside* the card, not as the step thumbnail.
  final promo = hasCode && item['emphasis'] == 'high';
  // Echo the command inline after the caption unless the caption already spells
  // it out (e.g. "...run /mcp → ..."). Applies to the promo step too — the figma
  // shows the command both in the hero card and in the step sentence.
  final inlineCommand =
      (hasCode && !(cap is String && cap.contains(code))) ? code : null;
  // The hero (promo) step echoes its command as a *muted mono* clause (the figma
  // grey inline-command look — steps 1-3), since the command already stands out
  // in the hero card. A plain step with a command (step 0's `npm install …`)
  // keeps the accent-underline echo (`_LinkedText`'s default).
  final caption = cap is String
      ? _LinkedText(cap, capStyle,
          trailing: inlineCommand, trailingStyle: promo ? theme.mono : null)
      : (cap is List
          ? neoText(theme, cap, capStyle)
          : Text('—', key: const Key('step-error'), style: capStyle));
  final blocks = scope.buildBlocks(_stepBlocks(item));
  final body = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _stepLabel(theme, n - 1),
      const SizedBox(height: 4),
      caption,
      // The carded detail is the caption's muted sibling — same body size (the
      // figma "(This can be different…)" is 16px grey, NOT the 12px caption the
      // bare/row steps use), just the muted color.
      if (detail is String) ...[
        const SizedBox(height: 4),
        Text(detail, style: capStyle.copyWith(color: theme.textMuted)),
      ],
      if (blocks.isNotEmpty) ...[
        SizedBox(height: theme.spaceSm),
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: theme.blockSpacing),
          blocks[i],
        ],
      ],
    ],
  );
  final hero = promo
      ? _CommandCard(
          command: code,
          imageUrl: imageUrl is String && imageUrl.isNotEmpty ? imageUrl : null,
          ratio: item['ratio'],
        )
      : (image == null
          // The thumbnail hugs the card's top + sides (the figma full-bleed
          // "Thumbnail Image"); only the *top* corners round, so its bottom edge
          // sits flush against the details panel. Explicit here so the image
          // can't inset from the card's own clip/border interaction.
          ? null
          : ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: theme.radiusLg.topLeft,
                topRight: theme.radiusLg.topRight,
              ),
              child: image,
            ));
  return Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: theme.surface,
      borderRadius: theme.radiusLg,
      border: theme.stepCardBorderColor == null
          ? null
          : Border.all(color: theme.stepCardBorderColor!),
      boxShadow: theme.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?hero,
        Padding(padding: const EdgeInsets.all(18), child: body),
      ],
    ),
  );
}

/// The "Step n:" label: a white->grey vertical gradient (the figma detail head),
/// painted with a ShaderMask over the bold body slot. The stops ride the theme's
/// [NeoSduiTheme.titleGradient] role (shared with the section-header emboss);
/// null theme -> the baked white->grey fallback, so the render is unchanged.
Widget _stepLabel(NeoSduiTheme theme, int n) {
  final style = theme.body
      .copyWith(fontWeight: FontWeight.w500, color: const Color(0xFFFFFFFF));
  final gradient = theme.titleGradient ??
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFF999999)],
      );
  return ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: gradient.createShader,
    child: Text('Step $n:', style: style),
  );
}

/// A step caption's URLs / bare domains drawn underlined (the figma link look) on
/// top of the caption's own [style]; caption with no url passes through as plain
/// text. Scheme URLs (`https://…`) and bare domains (`chatgpt.com`, `claude.ai`,
/// `api.neosapien.xyz/mcp`) both match.
final RegExp _urlRe = RegExp(
  r'(https?://\S+|(?:[a-z0-9-]+\.)+(?:com|ai|xyz|io|org|net|dev)(?:/\S*)?)',
  caseSensitive: false,
);
/// A caption's URLs / bare domains as tappable accent links: accent-colored +
/// underlined, launching their https target through the scope's dispatch (an
/// [ExternalUrl], which the app opens in the browser). Non-link text passes
/// through in [style]; a caption with no url collapses to a plain [Text]. Holds
/// one [TapGestureRecognizer] per link and disposes them, so the rich text leaks
/// nothing.
class _LinkedText extends StatefulWidget {
  const _LinkedText(this.text, this.style, {this.trailing, this.trailingStyle});
  final String text;
  final TextStyle style;

  /// An optional command echoed inline after the caption. Not tappable: it's a
  /// shell command, not a URL. Rendered in [trailingStyle] when set (the promo
  /// step's muted mono clause), else the accent color + underline (the default
  /// figma inline-command look — step 0's `npm install …`).
  final String? trailing;

  /// Style for the [trailing] echo; null → the accent-underline link style.
  final TextStyle? trailingStyle;

  @override
  State<_LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<_LinkedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilt recognizers each build (theme/text can change) — dispose the old
    // set first so none dangles.
    _clearRecognizers();
    final matches = _urlRe.allMatches(widget.text).toList();
    // No links and no trailing command -> a plain Text (golden-stable).
    if (matches.isEmpty && widget.trailing == null) {
      return Text(widget.text, style: widget.style);
    }
    final scope = NeoSduiScope.of(context);
    final accent = scope.theme.accent;
    final linkStyle = widget.style.copyWith(
      color: accent,
      decoration: TextDecoration.underline,
      decorationColor: accent,
    );
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in matches) {
      if (m.start > last) {
        spans.add(TextSpan(text: widget.text.substring(last, m.start)));
      }
      final raw = m.group(0)!;
      final uri = _linkUri(raw);
      TapGestureRecognizer? rec;
      if (uri != null) {
        rec = TapGestureRecognizer()
          ..onTap = () => scope.dispatch(context, ExternalUrl(uri));
        _recognizers.add(rec);
      }
      spans.add(TextSpan(text: raw, style: linkStyle, recognizer: rec));
      last = m.end;
    }
    if (last < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(last)));
    }
    // Inline command echoed after the caption: muted mono (promo step) or the
    // accent-underline link style; not tappable.
    if (widget.trailing != null) {
      spans.add(const TextSpan(text: ' '));
      spans.add(TextSpan(text: widget.trailing, style: widget.trailingStyle ?? linkStyle));
    }
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}

/// A matched url / bare domain -> the https [Uri] to launch (a bare domain gets
/// the scheme prefixed), or null when it can't be a valid https host. Trailing
/// sentence punctuation is trimmed so "claude.ai." launches claude.ai.
Uri? _linkUri(String raw) {
  var s = raw.replaceAll(RegExp(r'[.,)]+$'), '');
  if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'https://$s';
  final uri = Uri.tryParse(s);
  return (uri != null && uri.host.isNotEmpty) ? uri : null;
}

/// A step item's optional nested `blocks` -> `BlockNode`s for the resilient
/// renderer (mirrors `BlockNode.nodeList`, but reads a raw item map since step
/// items aren't `BlockNode`s). Absent/malformed -> empty, so a plain step is
/// unaffected. This is what lifts a step from a leaf caption to a composed one.
List<BlockNode> _stepBlocks(Map<String, Object?> item) {
  final raw = item['blocks'];
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is Map) BlockNode.fromJson(Map<String, Object?>.from(e)),
  ];
}

/// A step's optional `image`: a network image at its `ratio` (else the how_to
/// default), rounded to the theme radius. Missing/broken -> nothing, so a step
/// with an as-yet-unpublished asset still renders its caption. The wire carries
/// only the url + ratio role; all look is the theme's.
Widget? _stepImage(NeoSduiTheme theme, Map<String, Object?> item, {bool clip = true}) {
  final url = item['image'];
  if (url is! String || url.isEmpty) return null;
  final r = item['ratio'];
  final ratio = (r is num && r > 0 && r.isFinite) ? r.toDouble() : _defaultImageRatio;
  // Reserve the ratio box + shimmer + fade in (no expand-on-arrival). Crop from
  // the top: a screenshot's meaningful content sits up top, so a taller-than-
  // declared asset keeps its head (e.g. the "connected" card's dead space below)
  // instead of centering on it. Bare step rounds the image itself; a carded step
  // lets the card clip the flush image to its own radius (no double-rounding). A
  // failed/unpublished asset collapses, so the caption still stands alone.
  return neoNetworkImage(
    theme,
    url,
    ratio: ratio,
    alignment: Alignment.topCenter,
    radius: clip ? theme.radiusMd : null,
  );
}

/// The hero command card — the figma "Promo Card" for the guide's key step
/// (Claude's `claude mcp add …`): a prominent, centered mono command over the
/// theme's subtle card gradient, with a full-width "Copy Command" button that
/// flips to "Copied" for a beat. This is the ONE place a step command is
/// copyable; every other command rides inline in its caption. Stateful only for
/// the transient acknowledgement (a short bounded timer). Look is theme roles —
/// the wire carries only the command string.
class _CommandCard extends StatefulWidget {
  const _CommandCard({required this.command, this.imageUrl, this.ratio});

  final String command;

  /// Optional terminal screenshot shown at the top of the card (the figma
  /// "Claude Code welcome" panel). Collapses to nothing until the asset loads,
  /// so the card still renders its command before the image is published.
  final String? imageUrl;

  /// Aspect ratio for [imageUrl]; defaults to the how_to thumbnail ratio.
  final Object? ratio;

  @override
  State<_CommandCard> createState() => _CommandCardState();
}

class _CommandCardState extends State<_CommandCard> {
  static const _confirmFor = Duration(seconds: 2);
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.command));
    await HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(_confirmFor, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = NeoSduiScope.of(context).theme;
    // A branded green panel: an accent-tinted gradient under the sdui grid
    // texture (the same GridPainter a featured group paints) — the figma promo
    // card. Both greens derive from the accent role, so a re-skin moves them and
    // no hex rides the wire.
    final top =
        Color.alphaBlend(theme.accent.withValues(alpha: 0.16), theme.surface);
    final bottom =
        Color.alphaBlend(theme.accent.withValues(alpha: 0.10), theme.surface);
    final r = widget.ratio;
    final ratio =
        (r is num && r > 0 && r.isFinite) ? r.toDouble() : _defaultImageRatio;
    final grain = theme.grainOverlay;
    return ClipRRect(
      borderRadius: theme.radiusLg,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [top, bottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(
                // Accent-tinted grid on purpose — NOT `theme.gridLine`. The promo
                // card's texture is the brand green; a featured group's grid uses
                // the neutral `gridLine` role (layout.dart). Two deliberately
                // different textures sharing one painter — do not "unify" them.
                line: theme.accent.withValues(alpha: 0.12),
                step: theme.gridSpacing,
              ),
            ),
          ),
          // Film grain over the grid (the figma "Noise 1" layer) — the app's own
          // per-pixel grain, injected through the theme so the package ships no
          // shader/bitmap. Null theme grain -> just the grid, as before.
          if (grain != null)
            Positioned.fill(child: IgnorePointer(child: grain(context))),
          Padding(
            padding: EdgeInsets.all(theme.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Terminal screenshot on top (the figma "Claude Code welcome"
                // panel): reserved box + shimmer + fade like every guide image;
                // collapses cleanly until the asset is published.
                if (widget.imageUrl != null) ...[
                  neoNetworkImage(theme, widget.imageUrl!,
                      ratio: ratio, radius: theme.radiusMd),
                  SizedBox(height: theme.spaceMd),
                ],
                Text(
                  widget.command,
                  key: const Key('command-card'),
                  textAlign: TextAlign.center,
                  // The hero command rides the theme's `commandStyle` role (a
                  // notch larger than the inline `mono` — the figma promo wraps
                  // to ~3 centred lines); the block only recolors it to the
                  // primary text role, it never sizes it. NEVER hard-break the
                  // string here: the button copies it verbatim, so the wrap must
                  // stay natural (a baked "\n" would corrupt the shell command).
                  style: theme.resolvedCommandStyle.copyWith(color: theme.textPrimary),
                ),
                SizedBox(height: theme.spaceMd),
                _copyButton(theme),
              ],
            ),
          ),
          // The card's own neumorphic inset edge (the figma promo-card emboss:
          // dark from the bottom-right, faint light from the top-left), painted
          // on top so it rides the content without obscuring it.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: InsetShadowPainter(theme.radiusLg, [
                  const Inset(kInsetDark, Offset(-3.5, -3.5), 10),
                  Inset(theme.onSurface.withValues(alpha: 0.06),
                      const Offset(1, 1), 4),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The "Copy Command" button — a FLAT raised-dark gradient pill with a
  /// hairline border, NOT a neumorphic control: the figma emboss lives on the
  /// promo *card* (painted above), and the button itself carries no inset
  /// shadow. Fill lightens at the top (`tabTrack`) down to the card's dark foot
  /// (the `cardGradient` dark stop, ~#171A19) — both derived from theme roles,
  /// no hex on the wire. The wire names nothing here.
  Widget _copyButton(NeoSduiTheme theme) {
    final grad = theme.cardGradient;
    final foot =
        grad is LinearGradient ? grad.colors.last : theme.surface;
    return PressScale(
      onTap: _copy,
      scale: 0.9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: theme.radiusSm,
          gradient: LinearGradient(
            colors: [theme.tabTrack, foot],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: theme.stepCardBorderColor == null
              ? null
              : Border.all(color: theme.stepCardBorderColor!),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(child: _copyLabel(theme)),
        ),
      ),
    );
  }

  /// The "Copy Command" label — the accent gradient reoriented *vertical* (the
  /// figma 180° top-down gradient, distinct from the horizontal accent gradient
  /// the use-case titles paint with). No theme gradient -> flat accent.
  Widget _copyLabel(NeoSduiTheme theme) {
    final text = _copied ? 'Copied' : 'Copy Command';
    final style = theme.caption.copyWith(fontWeight: FontWeight.w500);
    final ag = theme.accentGradient;
    if (ag is! LinearGradient) return neoText(theme, text, style, tone: 'accent');
    final vertical = LinearGradient(
      colors: ag.colors,
      stops: ag.stops,
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (b) => vertical.createShader(b),
      child: Text(text, style: style.copyWith(color: const Color(0xFFFFFFFF))),
    );
  }
}
