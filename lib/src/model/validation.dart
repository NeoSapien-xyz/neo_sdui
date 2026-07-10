/// A collected schema problem. Validation never throws — it returns every issue
/// at once (R15) so a bad Remote Config paste can be logged in full, the way a
/// protobuf or JSON-schema validator reports all errors instead of dying on the
/// first one.
class SchemaIssue {
  const SchemaIssue(this.path, this.message);

  /// Dotted/indexed location, e.g. `blocks[2].type`.
  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

/// Document/view-structural keys a block payload may not reuse as a field name.
/// (`type`/`requires`/`fallback` are envelope keys, extracted before fields, so
/// they can't collide.)
const _reservedFieldNames = {'version', 'blocks', 'views', 'present'};

/// Validate a decoded document map, collecting all issues. An empty list means
/// the document is structurally sound; issues never stop parsing (the resilient
/// pipeline still renders whatever is valid).
List<SchemaIssue> validateDocument(Map<String, Object?> json) {
  final issues = <SchemaIssue>[];

  if (json['version'] is! int) {
    issues.add(const SchemaIssue('version', 'missing or non-integer `version`'));
  }

  final blocks = json['blocks'];
  if (blocks is! List) {
    issues.add(const SchemaIssue('blocks', 'missing or non-list `blocks`'));
  } else {
    for (var i = 0; i < blocks.length; i++) {
      issues.addAll(_validateBlock(blocks[i], 'blocks[$i]'));
    }
  }

  final views = json['views'];
  if (views != null) {
    if (views is! Map) {
      issues.add(const SchemaIssue('views', '`views` must be a map'));
    } else {
      views.forEach((id, view) {
        final path = 'views.$id';
        if (view is! Map) {
          issues.add(SchemaIssue(path, 'view must be a map'));
          return;
        }
        final present = view['present'];
        if (present != null && present != 'sheet' && present != 'screen') {
          issues.add(SchemaIssue('$path.present',
              "`present` must be 'sheet' or 'screen', got '$present'"));
        }
        final vBlocks = view['blocks'];
        if (vBlocks is! List) {
          issues.add(SchemaIssue('$path.blocks', 'missing or non-list `blocks`'));
        } else {
          for (var i = 0; i < vBlocks.length; i++) {
            issues.addAll(_validateBlock(vBlocks[i], '$path.blocks[$i]'));
          }
        }
      });
    }
  }

  return issues;
}

List<SchemaIssue> _validateBlock(Object? block, String path) {
  if (block is! Map) {
    return [SchemaIssue(path, 'block must be a map')];
  }
  final issues = <SchemaIssue>[];
  final type = block['type'];
  if (type is! String || type.isEmpty) {
    issues.add(SchemaIssue('$path.type', 'missing or empty `type`'));
  }
  for (final key in block.keys) {
    if (_reservedFieldNames.contains(key)) {
      issues.add(SchemaIssue('$path.$key', 'reserved keyword used as a field'));
    }
  }
  // Recurse into a fallback subtree so its problems are reported too.
  final fallback = block['fallback'];
  if (fallback is Map) {
    issues.addAll(_validateBlock(fallback, '$path.fallback'));
  }
  return issues;
}
