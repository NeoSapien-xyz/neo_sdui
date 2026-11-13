import 'package:flutter/widgets.dart';

import '../theme/neo_sdui_scope.dart';
import '../theme/neo_sdui_theme.dart';

/// Entrance delay per block index, in ms. The gap decays as it descends
/// (50, 45, 40, 35, 30, 30) so a full view reads as one wave settling rather
/// than a queue of blocks dealt out one by one.
const _delays = [0, 50, 95, 135, 170, 200, 230];

/// How far a block rises into place.
const _rise = 12.0;

/// Wraps [child] in its entrance animation, or returns it untouched when motion
/// is off, zeroed, or [index] sits past the delay table.
///
/// Nothing past the table animates. Those blocks start below the fold and a view
/// builds its blocks lazily, so animating them on build would fade each one in
/// *as the user scrolled to it* — a reveal the design doesn't have. Every block
/// past the table shares the last delay anyway and would have settled long
/// before a scroll could reach it, so leaving them static looks the same.
Widget entrance({
  required int index,
  required NeoSduiTheme theme,
  required Widget child,
}) =>
    index >= _delays.length ||
            theme.reduceMotion ||
            theme.entranceDuration <= Duration.zero
        ? child
        : _Entrance(index: index, theme: theme, child: child);

/// A block arriving on a freshly built view: a rise into place under a fade in.
///
/// Every block runs one controller over the same total window and takes its turn
/// through an [Interval], so a stagger costs no timers and cannot drift.
class _Entrance extends StatefulWidget {
  const _Entrance({
    required this.index,
    required this.theme,
    required this.child,
  });

  final int index;
  final NeoSduiTheme theme;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    final enter = widget.theme.entranceDuration.inMilliseconds;
    final delay = _delays[widget.index];
    final total = _delays.last + enter;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay / total,
        (delay + enter) / total,
        curve: widget.theme.entranceCurve,
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _animation,
        // The child builds once and rides every frame — the block subtree is
        // arbitrarily deep, and none of it depends on the animation.
        child: widget.child,
        builder: (context, child) {
          final t = _animation.value;
          // Transform *outside* Opacity, never the reverse. Opacity hit tests
          // through the plain RenderBox path, which rejects any position outside
          // its own (unshifted) box; RenderTransform deliberately skips that
          // check. Nested the other way, a risen block's pixels sit outside the
          // Opacity's box and the tap is dropped before it ever reaches the
          // child.
          return Transform.translate(
            offset: Offset(0, _rise * (1 - t)),
            child: Opacity(opacity: t, child: child),
          );
        },
      );
}

/// Scales toward the finger while held — the press feedback every tappable
/// shares. [scale] is the depth: a card dips further than a row.
class PressScale extends StatefulWidget {
  const PressScale({
    required this.onTap,
    required this.child,
    this.scale = 0.985,
    this.behavior = HitTestBehavior.opaque,
    super.key,
  });

  final VoidCallback onTap;
  final Widget child;
  final double scale;
  final HitTestBehavior behavior;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _setDown(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NeoSduiScope.of(context).theme;
    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onTapDown: (_) => _setDown(true),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: theme.reduceMotion ? Duration.zero : theme.motionDuration,
        curve: theme.motionCurve,
        child: widget.child,
      ),
    );
  }
}

/// Fades and rises [child] in whenever its key changes — a tab's content
/// swapping under a strip that stays put. The outgoing child leaves instantly
/// (zero reverse duration): two blocks cross-fading in place smear, where a
/// clean cut to the incoming rise reads as a swap.
class SwapFade extends StatelessWidget {
  const SwapFade({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = NeoSduiScope.of(context).theme;
    if (theme.reduceMotion) return child;
    return AnimatedSwitcher(
      duration: theme.swapDuration,
      reverseDuration: Duration.zero,
      switchInCurve: theme.entranceCurve,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: [...previous, ?current],
      ),
      // Transform outside the fade — see the note in _Entrance.build: a fade
      // wrapped around a shifted child rejects the tap on its own bounds.
      transitionBuilder: (child, animation) => AnimatedBuilder(
        animation: animation,
        child: FadeTransition(opacity: animation, child: child),
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _rise * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// A 24px affordance that turns [openTurns] and tints from [closedColor] to
/// [openColor] over the same beat as the expand it accompanies, so the caret
/// and the content arrive together. [glyph] draws the mark in the animated
/// colour. A RotatedBox would snap (a fixed quarter turn re-lays-out); this
/// animates through the turn.
class TurningCaret extends StatelessWidget {
  const TurningCaret({
    required this.open,
    required this.openTurns,
    this.box = 24,
    required this.closedColor,
    required this.openColor,
    required this.glyph,
    super.key,
  });

  final bool open;
  final double openTurns;
  final double box;
  final Color closedColor;
  final Color openColor;
  final Widget Function(Color color) glyph;

  @override
  Widget build(BuildContext context) {
    final theme = NeoSduiScope.of(context).theme;
    final duration = theme.reduceMotion ? Duration.zero : theme.swapDuration;
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: AnimatedRotation(
          turns: open ? openTurns : 0,
          duration: duration,
          curve: theme.motionCurve,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: open ? openColor : closedColor),
            duration: duration,
            curve: theme.motionCurve,
            builder: (context, color, child) => glyph(color!),
          ),
        ),
      ),
    );
  }
}
