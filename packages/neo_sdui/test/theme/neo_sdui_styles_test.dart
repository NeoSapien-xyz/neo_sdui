import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

/// The style groups default to today's block literals; nullable fields resolve
/// through the palette in the block, not here. These spot-check the literals.
void main() {
  final t = NeoSduiTheme.fallback();

  test('tabs defaults mirror the strip literals', () {
    expect(t.tabs.trackPadding, const EdgeInsets.all(2));
    expect(t.tabs.labelPadding,
        const EdgeInsets.symmetric(vertical: 12, horizontal: 8));
    expect(t.tabs.unselectedWeight, FontWeight.w400);
    expect(t.tabs.neumorphic, isTrue);
    expect(t.tabs.trackColor, isNull);
    expect(t.tabs.gap, 0);
  });

  test('card, group and steps defaults mirror the block literals', () {
    expect(t.card.titleGap, 8);
    expect(t.card.actionGap, 8);
    expect(t.card.listIconGap, 12);
    expect(t.card.listCaretGap, 8);
    expect(t.group.rowInset, isNull);
    expect(t.steps.cardGap, 12);
    expect(t.steps.labelGap, 4);
    expect(t.steps.labelNumberOffset, -1);
    expect(t.steps.labelSuffix, ':');
    expect(t.steps.autoLinkUrls, isTrue);
  });

  test('callout, faq, header, accordion defaults mirror the block literals',
      () {
    expect(t.callout.emphasizeFirstBullet, isTrue);
    expect(t.faq.questionPadding, const EdgeInsets.symmetric(vertical: 20));
    expect(t.faq.openTurns, 0.25);
    expect(t.faq.itemGap, 0);
    expect(t.header.subtitleGap, 4);
    expect(t.header.subheadingTopInset, 0);
    expect(t.accordion.headGap, 12);
    expect(t.accordion.headPadding,
        const EdgeInsets.symmetric(horizontal: 20, vertical: 18));
    expect(t.accordion.bodyPadding, const EdgeInsets.fromLTRB(16, 4, 16, 20));
    expect(t.linkRow.copySize, 28);
  });

  test('new roles resolve to what the blocks derive today', () {
    expect(t.resolvedSectionSpacing, t.blockSpacing);
    expect(t.resolvedViewPadding,
        EdgeInsets.symmetric(vertical: t.blockSpacing));
    expect(t.resolvedRowTitle,
        t.body.copyWith(color: t.onSurface, fontWeight: FontWeight.w500));
    expect(t.resolvedPanelTitle, t.body.copyWith(fontWeight: FontWeight.w500));
    expect(t.resolvedParagraph, t.body);
    expect(t.resolvedFootnote, t.caption.copyWith(color: t.textMuted));
    expect(t.resolvedSubheading, t.title);
    expect(t.backgroundOverlay, isNull);
  });

  test('copyWith carries the new params', () {
    const tabs = NeoTabsStyle(gap: 4);
    final c = t.copyWith(tabs: tabs, sectionSpacing: 30);
    expect(c.tabs.gap, 4);
    expect(c.resolvedSectionSpacing, 30);
    expect(c.card, t.card);
  });
}
