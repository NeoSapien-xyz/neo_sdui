import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '../theme/neo_sdui_theme.dart';

/// faq: accordion of question/answer pairs. Open state is client-owned (KTD9).
Widget buildFaq(BuildContext context, BlockNode node) =>
    _Faq(items: node.mapList('items'));

class _Faq extends StatefulWidget {
  const _Faq({required this.items});
  final List<Map<String, Object?>> items;

  @override
  State<_Faq> createState() => _FaqState();
}

class _FaqState extends State<_Faq> {
  final _open = <int>{};

  @override
  Widget build(BuildContext context) {
    final theme = NeoSduiScope.of(context).theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < widget.items.length; i++)
          _row(theme, i, widget.items[i]),
      ],
    );
  }

  Widget _row(NeoSduiTheme theme, int i, Map<String, Object?> item) {
    final isOpen = _open.contains(i);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => isOpen ? _open.remove(i) : _open.add(i)),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['question'] as String? ?? '',
              style: theme.body.copyWith(fontWeight: FontWeight.w500),
            ),
            AnimatedSize(
              duration: theme.reduceMotion ? Duration.zero : theme.motionDuration,
              curve: theme.motionCurve,
              alignment: Alignment.topLeft,
              child: isOpen
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(item['answer'] as String? ?? '',
                          style: theme.subtitle),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
