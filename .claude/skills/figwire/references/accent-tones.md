# Accent detection — reading a color to choose a role *name*

The wire carries no color — it carries the *name* of an accent role the theme declares
(`tone:"<name>"` → `theme.accents['<name>']`; `accent`/`critical`/`warning` are built in). When a
text is **visually the brand accent green**, tag it `accent` and the theme paints the gradient.
You decide the *tag* from the color; you never emit the color.

## The accent signal

neo's accent green (from the neo app's `AppColors`, mirrored in `neofig`'s `tokens.md`):

| hex | role | meaning |
|---|---|---|
| `#00F1A0` | `primary500` / `tempGreen` | the accent green |
| `#2DF790` | gradient start | the accent gradient runs `#2DF790 → #00F1A0` |

If a heading, a step number, a selected tab label, or an inline word in a sentence is rendered
in that green (or the green gradient), it is `accent`:

- Whole element green → put `"tone": "accent"` on the block (`header`/`text`).
- One word/phrase green inside otherwise-normal text → use a run:
  `["Here's what ", {"text": "NeoSapien", "tone": "accent"}, " does"]`.

Step numbers and the selected tab label are already accent-gradiented by the renderer — do **not**
tag them.

## Rules

- **Only the green maps to `accent`.** Plain white/grey text is the theme's default role — emit no
  `tone`. A *deliberate* other hue names its own role: the danger red is `tone:"critical"`, the
  caution yellow is `tone:"warning"`, a second brand hue is a ledger-declared `accents.<name>` you
  then name on the wire. Choosing the role is the whole job; the hex stays off the wire either way.
- **Never emit the hex.** `{"text": "NeoSapien", "tone": "accent"}` — not `#00F1A0`, not a gradient,
  not `color`. If you catch yourself writing a hex, a font, or a gradient stop, stop: that violates
  the wire invariant (see `wire-contract.md`).
- **When unsure** whether a text is truly the accent green vs. plain white, leave it untagged and
  note it in the coverage report — a missed accent is a cosmetic miss the theme survives; an
  invented one is wrong intent.

## Where the accent green typically appears in neo guides

Headline/emphasis words ("Here's what it does for you"), the "neosapien" brand word, step-count
text, selected states. Treat these as accent candidates and confirm against the screenshot.
