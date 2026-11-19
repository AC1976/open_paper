# drafts — upload format (draft v1)

Every item the editor uploads is one markdown file with YAML front matter.
The YAML mirrors the Swift models in `Sources/open_paper/models/`; the markdown
body is only used for stories (it becomes the article text).

```
drafts/
  stories/          type: story          → Story
  agenda/           type: agenda         → AgendaPoint
  quoted/           type: quoted         → QuotedItem
  advertisements/   type: advertisement  → Advertisement
  images/           image files referenced by `image.file`
```

Placement in an edition (which date, which order, lead or not) is **not** part of
these files. That is done in the editor menu, so one story can appear in more
than one edition.

## Conventions

- Keys are camelCase, exactly as in the Swift models.
- Dates are ISO 8601 with an offset: `2026-11-20T06:00:00+01:00`. Plain dates
  (`2026-12-31`) are used where only the day matters.
- `id` is optional. Leave it out on the first upload; the server assigns a UUID.
  Re-uploading a file with the same `slug` (stories) or `id` updates the item.
- Long text uses `>` (folded block) so it can wrap over several lines.
- Fields marked *proposed* in the examples are not in the models yet.
- `priority` is `2` (high) or `1` (normal), the raw values of `StoryPriority`,
  so it decodes straight into the model. Any other value is rejected.

## Envelope (all types)

| Key             | Required | Values                                         |
|-----------------|----------|------------------------------------------------|
| `type`          | yes      | `story`, `agenda`, `quoted`, `advertisement`   |
| `schemaVersion` | yes      | `1`                                            |
| `status`        | no       | `draft` (default), `ready` — *proposed*        |
| `id`            | no       | UUID                                           |

## Fields per type

**story** — `category` (`news`/`background`/`opinion`), `priority` (`2` = high, `1` = normal),
`title`, `slug`, `summary`; optional `extendedSummary`, `author`, `publishedAt`,
`updatedAt`, `image`. Body → article text (*proposed* new `body` field on `Story`).

**agenda** — `subject`, `place`, `link`, `summary`; optional `eventDate`.

**quoted** — `quote` (without quotation marks), `speaker`, `context`, `sourceLink`.

**advertisement** — `sponsorName`, `targetURL`, `image` (required; its `altText`
becomes `Advertisement.altText`), optional `priority` (`2` = high, `1` = normal, default `1`); *proposed* `campaignStart`,
`campaignEnd`.

## Image block

```yaml
image:
  # where the picture comes from — exactly one of:
  file: images/power-lines-sunset.jpg   # uploaded along with the .md
  url: https://images.example.com/x.jpg # remote

  storage: store        # what ingestion does with it (see below)
  altText: ...          # required
  caption: ...          # optional, stories only
  credit: ...           # optional, stories only

  # proposed ingestion metadata
  license: agency       # own | agency | cc-by | cc-by-sa | public-domain | unknown
  rightsHolder: ...
  usageExpires: 2027-11-20
  displayHint: auto     # auto | fullBanner | standardLead | thumbnail | hidden
  focalPoint: { x: 0.5, y: 0.4 }
  sensitive: false
```

`storage` decides how the image ends up in `ImageSource`:

| `storage` | Source needed    | Ingestion action                                   | Result                     |
|-----------|------------------|----------------------------------------------------|----------------------------|
| `embed`   | `file` or `url`  | read/download, resize, base64 into the database    | `.blob(data:mimeType:)`    |
| `store`   | `file` or `url`  | read/download, resize, save under `/media/…`       | `.endpoint(url: "/media/…")` |
| `link`    | `url`            | check the URL answers with an image, keep it as is | `.endpoint(url:)`          |

### Suggested ingestion rules

These are what "filter and action" could look like; all are open for discussion.

1. **Reject** when `altText` is missing, both or neither of `file`/`url` are given,
   or `link` is used with a `file`.
2. **Reject** files over a size limit (say 10 MB) or that are not JPEG/PNG/WebP
   (check the bytes, not the file extension).
3. **Hold as draft** when `license` is `unknown` or missing, or `usageExpires`
   is in the past. The editor sees a warning and must fix it before publishing.
4. **Strip metadata** (EXIF, including GPS location) from every stored or
   embedded image.
5. **Resize and convert**: make the crops the layout needs (21:9, 16:10, 1:1)
   around `focalPoint`, and convert to WebP.
6. **Only embed small images**: if `embed` would produce more than ~200 KB,
   switch to `store` and tell the editor.
7. **Expire**: a nightly job hides images whose `usageExpires` has passed and
   lets the layout fall back to text-only.
8. **`displayHint`** is advice to the layout planner, never an override: the
   planner may still hide an image to keep the page dense.
9. **`sensitive: true`** images are never used as the full-width breaking banner.

## Differences from the current Swift models

Ingestion should decode these files into separate *upload* types and then map
them onto the models, because a few things don't decode directly:

- `ImageSource`'s synthesized `Codable` form is `{ endpoint: { url: … } }`,
  which is awkward to write by hand; the `file`/`url` + `storage` block above
  replaces it.
- New fields: `Story.body`, `status`, and the proposed image metadata, so
  `StoryImage` would need `license`, `rightsHolder`, `usageExpires`,
  `displayHint`, `focalPoint` and `sensitive`.
- `Advertisement` has a top-level `altText`; in the upload it lives in the image block.
