import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

/// The wire `shape` role: omitted keeps today's rounded look; `squircle` opts a
/// block into the superellipse path. Geometry (radius) stays in the theme.
void main() {
  final registry = NeoSdui.compose(const []).registry;
  final media = registry.builderFor('media')!;
  final cta = registry.builderFor('cta')!;

  Future<void> pump(WidgetTester tester, BlockBuilder b, BlockNode node) {
    return tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: NeoSduiScope(
            theme: NeoSduiTheme.fallback(),
            dispatch: (_, _) {},
            buildBlocks: (_) => const [],
            child: Builder(builder: (ctx) => b(ctx, node)),
          ),
        ),
      ),
    );
  }

  testWidgets('media without shape -> ClipRRect (unchanged)', (tester) async {
    await pump(tester, media, BlockNode(type: 'media', fields: {'url': 'x'}));
    expect(find.byType(ClipRRect), findsOneWidget);
    expect(find.byType(ClipRSuperellipse), findsNothing);
    tester.takeException();
  });

  testWidgets('media shape:squircle -> ClipRSuperellipse', (tester) async {
    await pump(tester, media,
        BlockNode(type: 'media', fields: {'url': 'x', 'shape': 'squircle'}));
    expect(find.byType(ClipRSuperellipse), findsOneWidget);
    expect(find.byType(ClipRRect), findsNothing);
    tester.takeException();
  });

  testWidgets('cta shape:squircle -> superellipse ShapeDecoration', (tester) async {
    await pump(tester, cta, BlockNode(type: 'cta',
        fields: {'label': 'Go', 'action': 'x', 'shape': 'squircle'}));
    final deco = tester
        .widget<DecoratedBox>(find.byType(DecoratedBox).first)
        .decoration;
    expect(deco, isA<ShapeDecoration>());
    expect((deco as ShapeDecoration).shape, isA<RoundedSuperellipseBorder>());
  });

  testWidgets('cta without shape -> plain BoxDecoration (unchanged)', (tester) async {
    await pump(tester, cta,
        BlockNode(type: 'cta', fields: {'label': 'Go', 'action': 'x'}));
    expect(
      tester.widget<DecoratedBox>(find.byType(DecoratedBox).first).decoration,
      isA<BoxDecoration>(),
    );
  });

  testWidgets('non-positive ratio falls back — no AspectRatio assert', (tester) async {
    await pump(tester, media,
        BlockNode(type: 'media', fields: {'url': 'x', 'ratio': -5}));
    expect(tester.takeException(), isNull);
    expect(tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        greaterThan(0));
  });
}
