# Concepts

Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as ce-compound and ce-compound-refresh process learnings; direct edits are fine. Glossary only, not a spec or catch-all.

## Server-driven UI

### Wire
The flat data document the server (Remote Config) delivers and the client renders — a version, a list of blocks, and named views. Its defining invariant — authoring tools call it the **Iron Rule** — is that the wire carries only *semantics* (what a thing is and its content), never *look* (no hex colors, pixel sizes, or font sizes). Anything visual is resolved on the client.

### Block
One semantic unit on the wire (a header, a media, a card, a cta), identified by a `type` string and a bag of fields. A block never describes its own appearance; it names intent and lets the client's theme decide how it looks. Rendering is resilient — a block that fails to build degrades to a placeholder or is skipped, never crashing the view.

### Fallback
The alternate a block names for the client to render in its place when the block cannot be shown as authored — its `type` is unknown to the registry, its `requires` gate is unmet, or its builder fails. A fallback is itself a block, resolved the same resilient way (it may declare its own fallback); a block that names none is skipped rather than rendered blank. This per-block substitution is what keeps a bad block's blast radius to that one block.

### Block registry
The `type` → builder map that turns each block on the wire into a widget. It is the extension point: an add-on composes into the registry to add new block types or override existing ones. Registration is last-wins — an add-on's later `register` for an existing `type` replaces the earlier builder while keeping the same `type` on the wire.

### Block vocabulary
The closed roster of block `type` strings the core registry recognizes — a small, fixed set (header, text, cta, callout, card, …). It is closed by design: a `type` outside the roster has no builder and renders nothing, so the roster is a stable authoring contract, not an open extension point. Add-ons extend behavior by re-registering existing types (last-wins), never by minting new ones. Because the vocabulary is small and fixed, authoring or generating wire reduces to classification — mapping each source element onto one of the known types; anything off-roster silently drops rather than erroring, so authoring is gated against the roster.

### Core floor
The zero-dependency baseline builder core provides for every semantic it puts on the wire — `code` renders monospace + copy, `media` renders a plain network image. It is what a block resolves to when no add-on has upgraded that `type`, so a build without a given add-on degrades to the floor instead of crashing or showing a blank. An add-on upgrades a semantic by re-registering the same `type` (last-wins) with a dependency-bearing builder; the floor is the guaranteed fallback beneath it. New wire types are reserved for genuinely new semantics — a nicer render of an existing one is a floor upgrade, not a new type.

### Add-on
An optional package that composes into the base via `NeoSdui.compose`, contributing new block types or upgrading existing ones. Add-ons exist so the core stays dependency-light (`flutter` + `meta` only): anything needing heavy plugins or fonts (video playback, disk caching, syntax highlighting) lives in an add-on with its own dependencies. An add-on upgrades an existing block by re-registering its `type` (last-wins) with a heavier builder — this carries no new capability by itself, and when the add-on is absent the block degrades to its core floor.

### NeoSduiTheme
The client-owned role palette every block derives its look from — accent/surface/danger roles, type/radius/spacing scales, motion tokens (duration, curve, a `reduceMotion` flag), and surface treatments (elevation, gradient fills) — reached through the surrounding scope. Because the wire carries no look, two guides that must look different do so by being handed different themes, not by shipping different block code or different wire pixels. The host app fills the theme from its own bare styles.

### Role
A semantic name the wire carries for a look decision — an emphasis, a tone, an icon, a shape, a named variant — that the client theme resolves into concrete pixels. The wire names the role; the theme owns the pixels behind it, so the same role renders differently under two themes and a role the theme does not map falls back to a plain, undecorated default. The role is the unit of the look vocabulary: it grows by adding a role the theme resolves, never a pixel on the wire.

### Render idiom
A fixed look or motion treatment baked into a block's build code — the neumorphic inset-shadow emboss, the gradient-text draw recipe, the entrance stagger — as opposed to a Role the theme resolves or a wire semantic. It is the third home for appearance: the wire carries semantics, a Role carries a client-tunable value, and an idiom carries a treatment intrinsic to the block that no client needs to vary. Motion divides the same way look does — its *values* (durations, curves) are theme tokens like any Role, while *which* widget animates and *how* is an idiom in block code; the wire carries neither. An idiom is a deliberate keep: choreography the design does not strictly mandate is defensible only when it is theme-gated and collapses under the `reduceMotion` kill switch.

### View
A named sub-screen carried in the wire alongside the top-level blocks, rendered on demand rather than inline. A block's action targets a view by name and presents it as a modal sheet or a pushed screen; the wire names the destination and the presentation kind, while the client owns the transition. A view holds its own block list, resolved the same resilient way as the main screen.

### Role ledger
The persistent cross-screen accumulator the `figwire` skill fills with the look it reads from each Figma page but is forbidden to put on the wire — role→value observations (color roles, type scale, radius/space scales, surfaces, gradients, named accents, icons), tagged by source page. It is the authoring-time counterpart of the wire: a single Figma read forks into the wire (semantics) and the ledger (look). Pages are fed part by part across runs, so the ledger accumulates and reconciles (auto-merging near-duplicate values), and a terminal compile step resolves it into one base NeoSduiTheme plus a `copyWith` override per divergent page. It exists so the theme is derived from the same read as the wire, never a second one, and so the two stay reconciled on a shared Role vocabulary.

Reconciliation is a batch pass over the whole accumulated set, run at compile rather than incrementally at ingest, so the resolved theme is independent of the order pages were fed. The base is the look most pages share; a genuine cross-page difference either becomes a per-page override or, when the majority misranks intent, is overridden by explicitly designating one page's look as the base.

### Role drift
A mismatch between the look roles the wire names and the slots the compiled theme provides — a wire tone, icon, or named accent with no theme slot behind it (it would render as a plain, undecorated fallback), or a theme slot no wire ever references (dead look). The authoring-time role-drift check asserts the coupling in both directions: an unmatched wire role is a blocking issue, an unused theme slot an advisory. It exists because a theme fails by rendering *wrong*, not by vanishing, so the wire's own vocabulary gate cannot catch a role that silently resolves to nothing — the Role ledger records which roles each page's wire used precisely so this check has both sides to compare.

### Deploy gate
The channel a change must cross to reach a running device, fixed by *what kind* of change it is — and the reason a correct fix can stay invisible until the right channel opens. There are three, and they are independent: a change to client code (a block, the theme, a Render idiom) reaches the device only on an app **rebuild**; a change to the wire reaches it only when Remote Config is **republished** (and not before the client's fetch cache expires); a change to a bundled image or other asset reaches it only on a **CDN upload**. Most wasted verification on a server-driven screen is checking a change against the wrong gate — rebuilding to see a wire edit, or editing the renderer to fix an artifact baked into an asset. Naming the gate up front turns "why didn't my fix show up?" into "which gate does this cross, and did I open it?"
