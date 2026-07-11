import 'package:meta/meta.dart';

/// One block: a wire `type` plus its fields. Generic (not a sealed per-type
/// class) so add-on packages can register new types.
@immutable
class BlockNode {
  const BlockNode({
    required this.type,
    this.fields = const {},
    this.requires,
    this.fallback,
  });

  /// Type for a structurally-broken node. No builder -> fallback/skip.
  static const String invalidType = '_invalid';

  final String type;

  /// Payload minus the envelope keys (`type`/`requires`/`fallback`).
  final Map<String, Object?> fields;

  /// Feature -> min version this block needs (else render [fallback]).
  final Map<String, String>? requires;

  /// Rendered when this block is unknown or `requires` is unmet.
  final BlockNode? fallback;

  /// Never throws; a broken node becomes [invalidType]. Semantic checks live
  /// in `validateDocument`.
  factory BlockNode.fromJson(Map<String, Object?> json) {
    final rawType = json['type'];
    final type = (rawType is String && rawType.isNotEmpty) ? rawType : invalidType;

    final fallbackJson = json['fallback'];
    final fallback = fallbackJson is Map
        ? BlockNode.fromJson(Map<String, Object?>.from(fallbackJson))
        : null;

    final fields = Map<String, Object?>.of(json)
      ..remove('type')
      ..remove('requires')
      ..remove('fallback');

    return BlockNode(
      type: type,
      fields: fields,
      requires: _parseRequires(json['requires']),
      fallback: fallback,
    );
  }

  bool get isValidType => type != invalidType;

  // Typed field reads; absent -> caller default (R4).

  String? stringOr(String key, [String? or]) =>
      fields[key] is String ? fields[key] as String : or;

  int? intOr(String key, [int? or]) =>
      fields[key] is int ? fields[key] as int : or;

  bool boolOr(String key, {bool or = false}) =>
      fields[key] is bool ? fields[key] as bool : or;

  /// Aspect ratio from an explicit `ratio` (any positive num), else raw
  /// `width`/`height`, else [fallback]. Guards non-positive values — a `<= 0`
  /// ratio trips `AspectRatio`'s assert in debug and is undefined in release.
  double ratioOr(double fallback) {
    final r = fields['ratio'];
    if (r is num && r > 0) return r.toDouble();
    final w = intOr('width'), h = intOr('height');
    if (w != null && w > 0 && h != null && h > 0) return w / h;
    return fallback;
  }

  /// Child-block list (e.g. a tab's `blocks`).
  List<BlockNode> nodeList(String key) {
    final raw = fields[key];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) BlockNode.fromJson(Map<String, Object?>.from(e)),
    ];
  }

  /// List of raw maps (e.g. `steps.items`), left for the builder to read.
  List<Map<String, Object?>> mapList(String key) {
    final raw = fields[key];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) Map<String, Object?>.from(e),
    ];
  }

  static Map<String, String>? _parseRequires(Object? raw) {
    if (raw is! Map) return null;
    final out = <String, String>{};
    raw.forEach((k, v) {
      if (k is String && v != null) out[k] = v.toString();
    });
    return out.isEmpty ? null : out;
  }
}
