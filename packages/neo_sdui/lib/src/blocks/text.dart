import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';

/// text: body copy. `emphasis: low` renders muted; else primary.
Widget buildText(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  return Text(
    node.stringOr('body', '')!,
    style: theme.bodyEmphasis(node.stringOr('emphasis')),
  );
}
