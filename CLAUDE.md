# GeoFleetic — Spatial Intelligence Layer

Geo-distributed fleet intelligence collaboration. The `&space` primitive provider for the [&] Protocol ecosystem.

## Source-of-truth spec

- `docs/spec/README.md` — GeoFleetic technical specification

## [&] Capabilities provided

| Capability | Contract | Operations |
|---|---|---|
| `&space.fleet` | `AmpersandBoxDesign/contracts/v0.1.0/space.fleet.contract.json` | locate, enrich, capacity, route |
| `&space.route` | `AmpersandBoxDesign/contracts/v0.1.0/space.route.contract.json` | route, optimize, explain |
| `&space.geofence` | `AmpersandBoxDesign/contracts/v0.1.0/space.geofence.contract.json` | contains, enter_exit, enrich |

## Key technologies

- Epoch-aware delta-CRDTs for convergent fleet state
- Federated continual learning (LoRA adapters, no raw data sharing)
- Spatial digital twins (IEEE COMST 2025 research)
- GNN route optimization with continual spatial learning
- MCP + A2A agent protocols

## Paired with

- **TickTickClock** — temporal intelligence (when + where = complete situational awareness)
- **Graphonomous** — continual learning substrate
- **Delegatic** — governance enforcement for fleet operations

## Status

This is a spec site. **No implementation code — none, anywhere.** `build-site.mjs`
recounts that on every run (`.ex`/`.exs` lines outside `old_scrap/`) and the page
publishes the number. Implementation will be Elixir/OTP when it starts; the
nearest honest first step is the spec's own **FV-1**, the delta-CRDT convergence
prototype, and it has not been started.

## The landing page is GENERATED. Do not hand-edit `index.html`.

`/index.html`, `/fences.js` and `/say.js` are emitted by `build-site.mjs` from
`records/surface.json`, `docs/spec/README.md`, `records/contracts/*.contract.json`,
`src/landing.html`, `src/shell.css`, `src/fences.js` and `src/say.js`.
**An edit to the served HTML is reverted by the next build — and refused before
that**, because `records/build.json` fingerprints every input and hashes every
emitted artifact. Change the record or the template.

```
npm run test:launch   # re-derive the facts, emit the site, run the gate
```

`launch-gate.mjs` reads the emitted artifact and refuses to publish when it and
the records disagree: a retracted claim reinstated anywhere outside the
retraction, a rung invented, a CTA the `spec` rung has not earned, a `§N` that
resolves to no heading, an unrendered token, a `mailto:`, a text token below
4.5:1, a same-origin link that resolves to nothing, a stale or hand-edited
artifact, or an identifying-animation constant leaking into the copy. **It has
been made to refuse 22 times deliberately, against a throwaway copy, with an
unmodified control run first** — the control matters: the first run of that
harness reported 20 refusals that were all refusing for an unrelated reason.

Do not hand-type the check count anywhere; the gate prints its own total.

Two checks are newer than the rest and are the ones to understand first:

- **The cascade resolver** (SHELL.md r7/r8). Every contrast check reads a
  *declared* token, and r7's header-CTA defect — `.top nav a` (0,2,1) beating
  `.btn` (0,1,0), so the button painted `--fg2` on the accent — passed all of
  them for as long as it shipped on nine surfaces. The gate now parses the
  emitted markup into elements with their ancestor chains, parses the emitted
  stylesheet with specificity, source order, `!important` and `@media`, and
  resolves `color` for every button at 390px and 1280px, hovered and not.
  Cross-checked against the browser's own computed styles for all four buttons:
  they agreed. It also resolves `min-height` on the animation panel, because
  §8 placement is a computed height and not a string in a stylesheet.
- **Comment stripping is its own pass** (SHELL.md r8). `<[^>]+>` stops at the
  first `>`, so a comment containing one leaks its remainder into "page text".
  The gate proves its own extractor on every run: `SHELL.md` appears in this
  page's source comments and in none of its text nodes.

**The band says "a specification in the ComputeDriven world", not "the spatial
layer of ComputeDriven", and that is deliberate.** `ampersand-nav` records
geofleetic as `place: 3`, and its own `renderPlacement()` gives the layer
sentence to `place: 2` only; place 3 gets the specification sentence plus a spec
link, place 4 gets attribution alone. Three variants, not two.
