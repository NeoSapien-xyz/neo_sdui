import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:neo_sdui/neo_sdui.dart';

import 'how_to_document.dart';
import 'how_to_theme.dart';

/// Renders the how_to guide through `neo_sdui`. This is the app's integration
/// point: it decodes the Remote Config string, hands the renderer the guide's
/// [howToTheme], and owns the Navigator — the package touches neither the router
/// nor a `Navigator` (R14). A `sheet:<id>` tap surfaces as [onPresentSheet]; the
/// sheet's own `closeSheet` cta surfaces as a [CloseView] action.
class HowToScreen extends StatelessWidget {
  const HowToScreen({super.key});

  static NeoDocument document() =>
      NeoDocument.fromJson(jsonDecode(howToDocumentJson) as Map<String, Object?>);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: howToTheme.background,
      body: SafeArea(
        child: NeoSduiView(
          document: document(),
          theme: howToTheme,
          onAction: _onAction,
          onPresentSheet: (ctx, view) => showModalBottomSheet<void>(
            context: ctx,
            backgroundColor: howToTheme.background,
            isScrollControlled: true,
            builder: (_) => FractionallySizedBox(
              heightFactor: 0.85,
              child: SafeArea(child: view),
            ),
          ),
        ),
      ),
    );
  }

  void _onAction(BuildContext context, NeoAction action) {
    switch (action) {
      case CloseView():
        Navigator.of(context).maybePop();
      case CloseAll():
        Navigator.of(context).popUntil((r) => r.isFirst);
      case ExternalUrl():
      case RouteAction():
      case OpenView():
      case InvalidAction():
        // how_to has no external/route actions; OpenView is handled by
        // onPresentSheet before it ever reaches here.
        break;
    }
  }
}
