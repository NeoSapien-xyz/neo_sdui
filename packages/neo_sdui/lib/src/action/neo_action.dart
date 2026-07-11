import 'package:meta/meta.dart';

import '../model/view.dart';

/// A parsed block action. The engine classifies; the app resolves route/view
/// through its own allowlist and owns the Navigator (R14). Closed set -> sealed.
@immutable
sealed class NeoAction {
  const NeoAction();

  /// Parse a wire action. `https` only for external links (R13); anything else
  /// is [InvalidAction] and never launches.
  factory NeoAction.parse(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return const InvalidAction('');
    if (s == 'closeSheet') return const CloseView();
    if (s == 'closeAll') return const CloseAll();

    final routeName = _after(s, 'route:');
    if (routeName != null) {
      return routeName.isEmpty ? InvalidAction(s) : RouteAction(routeName);
    }
    final sheetId = _after(s, 'sheet:');
    if (sheetId != null) {
      return sheetId.isEmpty
          ? InvalidAction(s)
          : OpenView(sheetId, NeoViewPresent.sheet);
    }
    final screenId = _after(s, 'screen:');
    if (screenId != null) {
      return screenId.isEmpty
          ? InvalidAction(s)
          : OpenView(screenId, NeoViewPresent.screen);
    }

    final uri = Uri.tryParse(s);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      return ExternalUrl(uri);
    }
    return InvalidAction(s);
  }

  static String? _after(String s, String prefix) =>
      s.startsWith(prefix) ? s.substring(prefix.length) : null;
}

/// External `https` link.
class ExternalUrl extends NeoAction {
  const ExternalUrl(this.url);
  final Uri url;
}

/// Named app route (resolved by the app's allowlist).
class RouteAction extends NeoAction {
  const RouteAction(this.name);
  final String name;
}

/// Open a named view, presented per [present].
class OpenView extends NeoAction {
  const OpenView(this.id, this.present);
  final String id;
  final NeoViewPresent present;
}

/// Pop the current sheet/screen.
class CloseView extends NeoAction {
  const CloseView();
}

/// Pop past all guide sheets/screens.
class CloseAll extends NeoAction {
  const CloseAll();
}

/// Rejected input (non-https or unrecognized). Nothing runs.
class InvalidAction extends NeoAction {
  const InvalidAction(this.raw);
  final String raw;
}
