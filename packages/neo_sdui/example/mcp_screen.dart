import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:neo_sdui/neo_sdui.dart';

import 'mcp/mcp_document.dart';
import 'mcp_theme.dart';

/// Renders the MCP guide through `neo_sdui`. Like the how_to screen it decodes the
/// Remote Config string, hands the renderer [mcpTheme], and owns the Navigator
/// (R14) — the package only emits actions. MCP's client-picker and footer cards
/// use `screen:<id>`, which surfaces as [onPresentScreen] = a `Navigator.push`;
/// a sub-view's own `closeSheet`/back surfaces as [CloseView]. `onPresentSheet`
/// is wired too so a future `sheet:` view Just Works.
class McpScreen extends StatelessWidget {
  const McpScreen({super.key});

  static NeoDocument document() =>
      NeoDocument.fromJson(jsonDecode(mcpDocumentJson) as Map<String, Object?>);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mcpTheme.background,
      body: SafeArea(child: _view(context)),
    );
  }

  NeoSduiView _view(BuildContext context) => NeoSduiView(
        document: document(),
        theme: mcpTheme,
        onAction: _onAction,
        onPresentSheet: (ctx, _, child) => showModalBottomSheet<void>(
          context: ctx,
          backgroundColor: mcpTheme.background,
          isScrollControlled: true,
          builder: (_) => FractionallySizedBox(
            heightFactor: 0.85,
            child: SafeArea(child: child),
          ),
        ),
        onPresentScreen: (ctx, _, child) => Navigator.of(ctx).push(
          MaterialPageRoute<void>(builder: (_) => _McpSubScreen(view: child)),
        ),
      );

  void _onAction(BuildContext context, NeoAction action) {
    switch (action) {
      case CloseView():
        Navigator.of(context).maybePop();
      case CloseAll():
        Navigator.of(context).popUntil((r) => r.isFirst);
      case ExternalUrl():
        // e.g. Contact Support — the host app launches the url (url_launcher).
        break;
      case RouteAction():
      case OpenView():
      case InvalidAction():
        // OpenView is handled by onPresentSheet/onPresentScreen before it
        // reaches here; MCP declares no route actions.
        break;
    }
  }
}

/// A pushed sub-view: the guide's screen chrome (a back chevron) wrapping the
/// rendered [NeoSduiView]. The view carries its own title header block, so the
/// bar stays a bare back affordance tinted the guide's back-link accent.
class _McpSubScreen extends StatelessWidget {
  const _McpSubScreen({required this.view});

  final Widget view;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mcpTheme.background,
      appBar: AppBar(
        backgroundColor: mcpTheme.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2DF790)),
      ),
      body: SafeArea(child: view),
    );
  }
}
