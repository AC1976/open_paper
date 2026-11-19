---
# ── Envelope (every upload) ──────────────────────────────────────────
type: story                 # story | agenda | quoted | advertisement
schemaVersion: 1
status: ready               # draft | ready   (proposed — not in model yet)
# id:                       # optional UUID; omit on first upload, server assigns one

# ── Story model ──────────────────────────────────────────────────────
category: news              # news | background | opinion
priority: 2                 # 2 = high, 1 = normal
title: Global Summit Reaches Historic Accord on Clean Energy Grid
slug: global-summit-historic-accord-clean-energy-grid
author: Elena Vance and Marcus Sterling
publishedAt: 2026-11-20T06:00:00+01:00
updatedAt: 2026-11-20T06:30:00+01:00

summary: >
  Negotiators from 140 nations finalized a binding framework early Wednesday
  morning to modernize cross-border power transmission and phase out coal
  subsidies by 2035.

extendedSummary: >
  Under the terms of the agreement, wealthier industrial economies committed
  $120 billion annually in grid-interconnection financing, while coastal nations
  agreed to fast-track subsea cable permitting across shared maritime zones.

# ── Image (see README → "Image block") ───────────────────────────────
image:
  file: images/power-lines-sunset.jpg   # uploaded together with this .md
  storage: store                        # embed | store | link
  altText: High-voltage power lines at sunset
  caption: Delegates worked through the night to finalize transmission targets.
  credit: Photo by Studio Archive

  # proposed ingestion metadata — not in StoryImage yet
  license: agency                       # own | agency | cc-by | cc-by-sa | public-domain | unknown
  rightsHolder: Studio Archive
  usageExpires: 2027-11-20
  displayHint: auto                     # auto | fullBanner | standardLead | thumbnail | hidden
  focalPoint: { x: 0.5, y: 0.4 }        # 0–1, used when cropping to 21:9 / 16:10 / 1:1
  sensitive: false
---

The article body goes here, in plain markdown. It becomes the full text on
`/articles/global-summit-historic-accord-clean-energy-grid`.

## Key commitments

- A shared transmission planning office, staffed by all signatories.
- Coal subsidies phased out by 2035, with a review in 2030.
- Annual grid-interconnection financing of $120 billion.

> "This is the first agreement that treats the grid as shared infrastructure,"
> one delegate said after the closing session.
