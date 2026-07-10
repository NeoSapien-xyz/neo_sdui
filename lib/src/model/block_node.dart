import 'package:meta/meta.dart';

/// A single renderable node from a guide document.
///
/// Deliberately generic: the wire `type` string is interpreted by a registered
/// builder (see `BlockRegistry`), never by a per-type Dart class. A `sealed`
/// hierarchy would force every block to live in this package and slam the door
/// on add-on packages contributing their own types — so we model a block the way
/// DivKit and Adaptive Cards do: a typed bag keyed by `type`, plus the two
/// envelope fields every node may carry (`requires`, `fallback`).
@immutable
class BlockNode {
  const BlockNode({
    required this.type,
    this.fields = const {},
    this.requires,
    this.fallback,
  });

  /// Sentinel type for a structurally-invalid node (missing/non-string `type`).
  /// No builder is ever registered for it, so the render pipeline routes it to
  /// `fallback`/skip like any other unknown type.
  static const String invalidType = '_invalid';

  /// The wire `type` discriminant, e.g. `header`, `card`, `cta`.
  final String type;

  /// Block payload with the envelope keys (`type`/`requires`/`fallback`) removed.
  final Map<String, Object?> fields;

  /// Feature -> minimum version this block needs. Mirrors Adaptive Cards
  /// `requires`: when the host can't satisfy it, `fallback` is rendered.
  final Map<String, String>? requires;

  /// Subtree to render when this block is unknown or its `requires` is unmet.
  final BlockNode? fallback;

  /// Structural parse. Never throws — an invalid node becomes [invalidType] and
  /// is caught downstream by the fallback/skip pipeline. Semantic problems are
  /// reported separately by `validateDocument`.
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

  /// Whether this node parsed to a real (non-sentinel) type.
  bool get isValidType => type != invalidType;

  // ---- Typed field accessors (R4: absent field -> caller's default) ----

  String? stringOr(String key, [String? or]) =>
      fields[key] is String ? fields[key] as String : or;

  int? intOr(String key, [int? or]) =>
      fields[key] is int ? fields[key] as int : or;

  bool boolOr(String key, {bool or = false}) =>
      fields[key] is bool ? fields[key] as bool : or;

  /// A child-block list field (e.g. a tab's `blocks`, a faq's `items`).
  List<BlockNode> nodeList(String key) {
    final raw = fields[key];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) BlockNode.fromJson(Map<String, Object?>.from(e)),
    ];
  }

  /// A list of maps field (e.g. `steps.items`, `tabs`), returned untyped for the
  /// builder to interpret.
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
