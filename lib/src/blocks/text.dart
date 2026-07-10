import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';

/// text: body copy. `variant: subtitle` reads the muted slot; else body.
Widget buildText(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  final style =
      node.stringOr('variant') == 'subtitle' ? theme.subtitle : theme.body;
  return Text(node.stringOr('body', '')!, style: style);
}
