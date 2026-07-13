# Accent detection — the one visual signal that maps to a wire name

The wire carries no color. The single exception is `tone:"accent"`: when a text is
**visually the brand accent green**, tag it `accent` and the theme paints the gradient.
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

- **Only the green maps to `accent`.** Other colors (white, grey, the danger red) are the theme's
  default roles — emit no `tone`, or `tone:"critical"` for the danger/error red only.
- **Never emit the hex.** `{"text": "NeoSapien", "tone": "accent"}` — not `#00F1A0`, not a gradient,
  not `color`. If you catch yourself writing a hex, a font, or a gradient stop, stop: that violates
  the wire invariant (see `wire-contract.md`).
- **When unsure** whether a text is truly the accent green vs. plain white, leave it untagged and
  note it in the coverage report — a missed accent is a cosmetic miss the theme survives; an
  invented one is wrong intent.

## Where the accent green typically appears in neo guides

Headline/emphasis words ("Here's what it does for you"), the "neosapien" brand word, step-count
text, selected states. Treat these as accent candidates and confirm against the screenshot.
