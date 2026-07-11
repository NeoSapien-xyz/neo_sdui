import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

/// The wire `shape` role: omitted (or an unrecognized token) keeps each block's
/// current look; `squircle` opts a block into the superellipse path; `rounded`
/// forces a plain rounded rect. Geometry (radius) stays in the theme.
void main() {
  final registry = NeoSdui.compose(const []).registry;
  final media = registry.builderFor('media')!;
  final cta = registry.builderFor('cta')!;
  final card = registry.builderFor('card')!;
  final callout = registry.builderFor('callout')!;
  final groupBlock = registry.builderFor('group')!;
  final theme = NeoSduiTheme.fallback();

  Future<void> pump(WidgetTester tester, BlockBuilder b, BlockNode node) {
    return tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: NeoSduiScope(
            theme: theme,
            dispatch: (_, _) {},
            buildBlocks: (_) => const [],
            child: Builder(builder: (ctx) => b(ctx, node)),
          ),
        ),
      ),
    );
  }

  ShapeBorder surfaceShape(WidgetTester tester) =>
      (tester.widget<DecoratedBox>(find.byType(DecoratedBox).first).decoration
              as ShapeDecoration)
          .shape;

  group('media', () {
    testWidgets('no shape -> ClipRRect (unchanged)', (tester) async {
      await pump(tester, media, BlockNode(type: 'media', fields: {'url': 'x'}));
      expect(find.byType(ClipRRect), findsOneWidget);
      expect(find.byType(ClipRSuperellipse), findsNothing);
      tester.takeException();
    });

    testWidgets('shape:squircle -> ClipRSuperellipse', (tester) async {
      await pump(tester, media,
          BlockNode(type: 'media', fields: {'url': 'x', 'shape': 'squircle'}));
      expect(find.byType(ClipRSuperellipse), findsOneWidget);
      expect(find.byType(ClipRRect), findsNothing);
      tester.takeException();
    });

    testWidgets('unrecognized shape token -> falls back to rounded', (tester) async {
      await pump(tester, media,
          BlockNode(type: 'media', fields: {'url': 'x', 'shape': 'circle'}));
      expect(find.byType(ClipRRect), findsOneWidget);
      expect(find.byType(ClipRSuperellipse), findsNothing);
      tester.takeException();
    });
  });

  group('cta / callout / group decorations', () {
    testWidgets('cta shape:squircle -> superellipse ShapeDecoration', (tester) async {
      await pump(tester, cta, BlockNode(type: 'cta',
          fields: {'label': 'Go', 'action': 'x', 'shape': 'squircle'}));
      expect(surfaceShape(tester), isA<RoundedSuperellipseBorder>());
    });

    testWidgets('cta without shape -> plain BoxDecoration (unchanged)', (tester) async {
      await pump(tester, cta,
          BlockNode(type: 'cta', fields: {'label': 'Go', 'action': 'x'}));
      expect(
        tester.widget<DecoratedBox>(find.byType(DecoratedBox).first).decoration,
        isA<BoxDecoration>(),
      );
    });

    testWidgets('callout shape:squircle -> superellipse ShapeDecoration', (tester) async {
      await pump(tester, callout,
          BlockNode(type: 'callout', fields: {'title': 'Hi', 'shape': 'squircle'}));
      expect(surfaceShape(tester), isA<RoundedSuperellipseBorder>());
    });

    testWidgets('group shape:squircle -> superellipse ShapeDecoration', (tester) async {
      await pump(tester, groupBlock,
          BlockNode(type: 'group', fields: {'shape': 'squircle'}));
      expect(surfaceShape(tester), isA<RoundedSuperellipseBorder>());
    });
  });

  group('card', () {
    testWidgets('tile thumbnail clips TOP corners only (the notch fix)', (tester) async {
      await pump(tester, card, BlockNode(type: 'card',
          fields: {'variant': 'tile', 'thumb': 'x', 'title': 'T'}));
      // Default card shape is squircle -> the tile clip is a top-only superellipse.
      final clip = tester.widget<ClipRSuperellipse>(find.byType(ClipRSuperellipse));
      final r = clip.borderRadius.resolve(TextDirection.ltr);
      expect(r.topLeft, theme.radiusLg.topLeft);
      expect(r.topRight, theme.radiusLg.topLeft);
      expect(r.bottomLeft, Radius.zero);
      expect(r.bottomRight, Radius.zero);
      tester.takeException();
    });

    testWidgets('shape:rounded turns OFF the card default squircle', (tester) async {
      await pump(tester, card, BlockNode(type: 'card',
          fields: {'variant': 'tile', 'thumb': 'x', 'title': 'T', 'shape': 'rounded'}));
      expect(surfaceShape(tester), isA<RoundedRectangleBorder>());
      tester.takeException();
    });

    testWidgets('unrecognized shape keeps the card default squircle (not rounded)',
        (tester) async {
      await pump(tester, card, BlockNode(type: 'card',
          fields: {'variant': 'tile', 'thumb': 'x', 'title': 'T', 'shape': 'squrcle'}));
      expect(surfaceShape(tester), isA<RoundedSuperellipseBorder>());
      tester.takeException();
    });

    testWidgets('compact row thumb shape:squircle -> ClipRSuperellipse', (tester) async {
      await pump(tester, card, BlockNode(type: 'card',
          fields: {'thumb': 'x', 'title': 'T', 'subtitle': 'S', 'shape': 'squircle'}));
      expect(find.byType(ClipRSuperellipse), findsOneWidget);
      tester.takeException();
    });
  });

  group('ratioOr guards', () {
    double mediaRatio(WidgetTester tester) =>
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio;

    testWidgets('negative ratio falls back — no AspectRatio assert', (tester) async {
      await pump(tester, media,
          BlockNode(type: 'media', fields: {'url': 'x', 'ratio': -5}));
      expect(tester.takeException(), isNull);
      expect(mediaRatio(tester), greaterThan(0));
    });

    testWidgets('infinite ratio falls back (would trip isFinite assert)', (tester) async {
      await pump(tester, media,
          BlockNode(type: 'media', fields: {'url': 'x', 'ratio': double.infinity}));
      expect(tester.takeException(), isNull);
      final ar = mediaRatio(tester);
      expect(ar, isNot(double.infinity));
      expect(ar.isFinite, isTrue);
    });

    testWidgets('width<=0 falls back (old guard only checked height)', (tester) async {
      await pump(tester, media, BlockNode(type: 'media',
          fields: {'url': 'x', 'width': 0, 'height': 100}));
      expect(tester.takeException(), isNull);
      expect(mediaRatio(tester), greaterThan(0));
    });

    testWidgets('height<=0 falls back', (tester) async {
      await pump(tester, media, BlockNode(type: 'media',
          fields: {'url': 'x', 'width': 100, 'height': 0}));
      expect(tester.takeException(), isNull);
      expect(mediaRatio(tester), greaterThan(0));
    });
  });
}
