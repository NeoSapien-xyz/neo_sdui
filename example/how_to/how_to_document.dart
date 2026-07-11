/// The how_to guide as one neo_sdui wire document — a faithful port of neo's
/// `remote_config_defaults.dart` `howToGuideDefaultJson` (today: remote HTML)
/// into semantic blocks. It is stored exactly as Remote Config delivers it: one
/// JSON string the app `jsonDecode`s and hands to `NeoDocument.fromJson`.
///
/// Video is deferred (KTD8): each sheet renders the clip's POSTER image via
/// `media` (the sibling `.png` of the `.mp4`) until the `neo_sdui_video` add-on
/// lands. When it does, a sheet's media becomes a `video` block carrying
/// `requires: {video: …}` + this `media` as its `fallback`.
const howToDocumentJson = r'''
{
  "version": 1,
  "blocks": [
    {
      "type": "header",
      "title": "How to use your Neo 1",
      "subtitle": "Here you can find how to efficiently use Neo 1 with video tutorials"
    },
    {
      "type": "card",
      "variant": "tile",
      "ratio": 1.3333,
      "thumb": "https://cdn.neosapien.xyz/neo/controls_new.png",
      "title": "How can I control Neo 1?",
      "action": "sheet:control"
    },
    {
      "type": "card",
      "variant": "tile",
      "ratio": 1.3333,
      "thumb": "https://cdn.neosapien.xyz/neo/light_indicators.png",
      "title": "What do the lights indicators on Neo 1 mean?",
      "action": "sheet:lights"
    },
    {
      "type": "card",
      "variant": "tile",
      "ratio": 1.3333,
      "thumb": "https://cdn.neosapien.xyz/neo/always_listening.png",
      "title": "Is my Neo 1 always listening?",
      "action": "sheet:memory"
    }
  ],
  "views": {
    "control": {
      "present": "sheet",
      "blocks": [
        { "type": "header", "title": "How can I control Neo 1?", "tone": "accent" },
        { "type": "media", "url": "https://cdn.neosapien.xyz/neo/controls_new.png", "ratio": 1 },
        { "type": "text", "body": "Neo 1 responds to touch gestures and voice commands. Single tap to start listening, double tap to pause." },
        { "type": "cta", "label": "Got it →", "action": "closeSheet", "emphasis": "high" }
      ]
    },
    "lights": {
      "present": "sheet",
      "blocks": [
        { "type": "header", "title": "What do the lights indicators on Neo 1 mean?", "tone": "accent" },
        { "type": "media", "url": "https://cdn.neosapien.xyz/neo/light_indicators.png", "ratio": 1 },
        { "type": "text", "body": "The LED ring indicates device state: solid white means connected, pulsing means listening, red means low battery." },
        { "type": "cta", "label": "Got it →", "action": "closeSheet", "emphasis": "high" }
      ]
    },
    "memory": {
      "present": "sheet",
      "blocks": [
        { "type": "header", "title": "Is my Neo 1 always listening?", "tone": "accent" },
        { "type": "media", "url": "https://cdn.neosapien.xyz/neo/always_listening.png", "ratio": 1 },
        { "type": "text", "body": "Neo 1 continuously listens and creates memories from your conversations. Memories are processed and saved." },
        { "type": "cta", "label": "Got it →", "action": "closeSheet", "emphasis": "high" }
      ]
    }
  }
}
''';
