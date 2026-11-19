---
type: advertisement
schemaVersion: 1
status: ready
# id:

# ── Advertisement model ──────────────────────────────────────────────
sponsorName: Vacheron & Co.
targetURL: https://example.com/chronometer-heritage
priority: 2                 # 2 = high, 1 = normal — higher sorts first in the ad column

# Same image block as stories. `altText` here becomes Advertisement.altText;
# the model has no caption/credit, so those are ignored for ads.
image:
  file: images/vacheron-chronometer.webp
  storage: embed            # small artwork: embed as base64 so the ad never breaks
  altText: The Chronometer Heritage Series — Vacheron & Co.
  license: own              # supplied by the advertiser
  rightsHolder: Vacheron & Co.

# proposed — not in model yet
campaignStart: 2026-11-15
campaignEnd: 2026-12-31
---

<!-- Body is not used for advertisements. -->
