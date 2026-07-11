# Concepts

Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as ce-compound and ce-compound-refresh process learnings; direct edits are fine. Glossary only, not a spec or catch-all.

## Server-driven UI

### Wire
The flat data document the server (Remote Config) delivers and the client renders — a version, a list of blocks, and named views. Its defining invariant: the wire carries only *semantics* (what a thing is and its content), never *look* (no hex colors, pixel sizes, or font sizes). Anything visual is resolved on the client.

### Block
One semantic unit on the wire (a header, a media, a card, a cta), identified by a `type` string and a bag of fields. A block never describes its own appearance; it names intent and lets the client's theme decide how it looks. Rendering is resilient — a block that fails to build degrades to a placeholder or is skipped, never crashing the view.

### Block registry
The `type` → builder map that turns each block on the wire into a widget. It is the extension point: an add-on composes into the registry to add new block types or override existing ones. Overriding a core block's entry replaces its builder while keeping the same `type` on the wire.

### Add-on
An optional package that composes into the base via `NeoSdui.compose`, contributing or overriding block builders in the registry. Add-ons exist so the core stays dependency-light (`flutter` + `meta` only): anything that needs heavy plugins or fonts (video playback, disk caching) lives in an add-on with its own dependencies. Overriding a core block carries no new capability by itself — it swaps how one block renders.

### NeoSduiTheme
The client-owned role palette every block derives its look from — accent/surface/danger roles, type/radius/spacing scales, and motion tokens (duration, curve, a `reduceMotion` flag) — reached through the surrounding scope. Because the wire carries no look, two guides that must look different do so by being handed different themes, not by shipping different block code or different wire pixels. The host app fills the theme from its own bare styles.
