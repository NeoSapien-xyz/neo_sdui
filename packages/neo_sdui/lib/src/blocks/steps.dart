import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '../theme/neo_sdui_theme.dart';
import '_gradient_text.dart';
import 'code.dart';

/// how_to's default thumbnail ratio when a step image omits one (matches media).
const double _defaultImageRatio = 358 / 221;

/// steps: numbered captions, each with an optional full-width `image` above the
/// row. Each item builds in its own try/catch so one bad item can't take out
/// the rest (R8).
Widget buildSteps(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  final items = node.mapList('items');
  // The number badges' accent hue; default `accent`, but a screen can name a
  // second hue (e.g. `"brand"`) so step counts differ from accent headings.
  final numberTone = node.stringOr('tone') ?? 'accent';
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
          child: _item(theme, i + 1, items[i], numberTone),
        ),
    ],
  );
}

Widget _item(NeoSduiTheme theme, int n, Map<String, Object?> item, String numberTone) {
  final index = theme.body.copyWith(fontWeight: FontWeight.w600);
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
  final row = Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      neoText(theme, '$n', index, tone: numberTone),
      const SizedBox(width: 12),
      Expanded(child: body),
    ],
  );
  // Optional full-width step image (the how-to screenshot / gradient card) above
  // the numbered row. Its gradient/look is baked into the asset, never the wire.
  final image = _stepImage(theme, item);
  if (image == null) return row;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [image, SizedBox(height: theme.spaceSm), row],
  );
}

/// A step's optional `image`: a network image at its `ratio` (else the how_to
/// default), rounded to the theme radius. Missing/broken -> nothing, so a step
/// with an as-yet-unpublished asset still renders its caption. The wire carries
/// only the url + ratio role; all look is the theme's.
Widget? _stepImage(NeoSduiTheme theme, Map<String, Object?> item) {
  final url = item['image'];
  if (url is! String || url.isEmpty) return null;
  final r = item['ratio'];
  final ratio = (r is num && r > 0 && r.isFinite) ? r.toDouble() : _defaultImageRatio;
  return ClipRRect(
    borderRadius: theme.radiusMd,
    child: Image.network(
      url,
      fit: BoxFit.cover,
      // Collapse — not an empty ratio box — while the asset is pending or failed,
      // so a not-yet-published image leaves no gap; reserve the ratio box only
      // once a frame arrives. AspectRatio lives on the child, never wrapping the
      // Image, so an error shrinks the whole thing away.
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
      frameBuilder: (_, child, frame, wasSync) =>
          (frame == null && !wasSync)
              ? const SizedBox.shrink()
              : AspectRatio(aspectRatio: ratio, child: child),
    ),
  );
}
