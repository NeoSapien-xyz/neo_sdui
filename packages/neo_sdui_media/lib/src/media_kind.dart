/// Whether a media URL points at an image or a video.
enum MediaKind { image, video }

/// Extensions that mean "video". Kept small and explicit (KTD2).
const Set<String> _videoExtensions = {'mp4', 'mov', 'webm', 'm4v'};

/// Extensions we recognize as images — only used to answer "is this a known
/// extension at all?" for the ambiguity guard, not for inference (image is the
/// default, so this list need not be exhaustive).
const Set<String> _imageExtensions = {
  'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'heic', 'heif',
};

/// Infers image vs video for [url]. An explicit [kind] of `video`/`image`
/// (case-insensitive) wins; otherwise a recognized video extension means video
/// and anything else is treated as an image (R2, R3).
MediaKind inferMediaKind(String url, {String? kind}) {
  switch (kind?.trim().toLowerCase()) {
    case 'video':
      return MediaKind.video;
    case 'image':
      return MediaKind.image;
  }
  return _videoExtensions.contains(_extensionOf(url))
      ? MediaKind.video
      : MediaKind.image;
}

/// Whether [url] ends in an extension this add-on recognizes (image or video).
/// The media builder uses this to spot the ambiguous "no extension, no kind"
/// case, where a video authored without a `kind` would silently infer as image.
bool hasRecognizedExtension(String url) {
  final ext = _extensionOf(url);
  return _videoExtensions.contains(ext) || _imageExtensions.contains(ext);
}

/// Lowercased trailing extension (no dot) of [url]'s last path segment, or ''
/// when there is none. Strips `?query`/`#fragment` first so a tokenized URL
/// like `clip.mp4?token=…` still resolves.
String _extensionOf(String url) {
  var path = url;
  final cut = path.indexOf(RegExp('[?#]'));
  if (cut != -1) path = path.substring(0, cut);
  final slash = path.lastIndexOf('/');
  final segment = slash == -1 ? path : path.substring(slash + 1);
  final dot = segment.lastIndexOf('.');
  if (dot <= 0 || dot == segment.length - 1) return '';
  return segment.substring(dot + 1).toLowerCase();
}
