import 'package:meta/meta.dart';

import '../model/view.dart';

/// A parsed action from a block's `action` string.
///
/// The engine only parses and classifies; the app resolves `Route`/`OpenView`
/// through its own allowlist and owns the Navigator (R14). Closed set — actions
/// are core-owned, unlike blocks — so `sealed` is the right model here.
@immutable
sealed class NeoAction {
  const NeoAction();

  /// Parse a wire action string. Enforces `https`-only for external links
  /// (R13): any other scheme becomes [InvalidAction] and nothing launches.
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
    // http, javascript, file, intent, custom deep links, garbage -> rejected.
    return InvalidAction(s);
  }

  static String? _after(String s, String prefix) =>
      s.startsWith(prefix) ? s.substring(prefix.length) : null;
}

/// An external `https` link. The app opens it (e.g. `url_launcher`).
class ExternalUrl extends NeoAction {
  const ExternalUrl(this.url);
  final Uri url;
}

/// A named app route. The app resolves it through its own allowlist.
class RouteAction extends NeoAction {
  const RouteAction(this.name);
  final String name;
}

/// Open a named view in the current document, presented per [present].
class OpenView extends NeoAction {
  const OpenView(this.id, this.present);
  final String id;
  final NeoViewPresent present;
}

/// Pop the current sheet/screen.
class CloseView extends NeoAction {
  const CloseView();
}

/// Pop back past all guide sheets/screens.
class CloseAll extends NeoAction {
  const CloseAll();
}

/// Rejected input — a non-https scheme or an unrecognized string. Nothing runs.
class InvalidAction extends NeoAction {
  const InvalidAction(this.raw);
  final String raw;
}
