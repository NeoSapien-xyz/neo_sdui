import 'package:flutter/material.dart';
import 'package:neo_sdui/neo_sdui.dart';
import 'package:neo_sdui_media/neo_sdui_media.dart';

/// Minimal app composing the media add-on over a two-block guide — one video,
/// one image. Without `neoSduiMediaAddon`, the video block degrades to the core
/// placeholder box and the image loses disk caching.
void main() {
  final composition = NeoSdui.compose([neoSduiMediaAddon]);
  runApp(MediaExampleApp(composition: composition));
}

class MediaExampleApp extends StatelessWidget {
  const MediaExampleApp({super.key, required this.composition});

  final NeoSduiComposition composition;

  static const _doc = NeoDocument(
    version: 1,
    blocks: [
      BlockNode(type: 'media', fields: {
        'url':
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      }),
      BlockNode(type: 'media', fields: {
        'url':
            'https://flutter.github.io/assets-for-api-docs/assets/widgets/owl.jpg',
      }),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: NeoSduiView(
              document: _doc,
              theme: NeoSduiTheme.fallback(),
              onAction: (_, _) {},
              registry: composition.registry,
              capabilities: composition.capabilities,
            ),
          ),
        ),
      ),
    );
  }
}
