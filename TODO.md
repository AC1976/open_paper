# To do: editor workflow

Each step should work end to end before the next one starts. The aim is to see
one upload go from file to database as early as possible.

## Open questions

- [x] **One piece at a time, or a whole edition at once?** One piece at a
      time. Each upload is saved to an **inbox**; a separate view places inbox
      items into an issue (step 5).
- [ ] **Who are the editors?** One person → a single account in config is
      enough. Several people → a users table.

## 0. Check the foundation

- [ ] Run a bare Hummingbird 2 server on Windows. SwiftNIO's Windows support is
      the biggest unknown; if it doesn't work well, move development to WSL.
- [x] Split the package: `OpenPaperKit` library (models, layout planner, HTML
      components, database) shared by the `open_paper` generator and the
      `server` target.

## 1. File → model (no web page yet)

- [x] `loadUpload(_:from:)` in `models/Upload.swift`: split front matter from
      the body, decode the YAML straight into the model, body → HTML.
- [x] Check the drafts: `swift run open_paper ingest`.

## 2. Save to the database (the inbox)

Saving an upload puts it in the inbox. Placing it in an issue is step 5.

- [x] GRDB, with `DatabaseQueue`. The models are GRDB records.
- [x] Migrations (`PaperDatabase`, migration `v1`):
  - `items`: one row per uploaded item (id, kind, upload time);
  - one table per model (`stories`, `agenda_points`, `quoted_items`,
    `advertisements`), the model `id` is the row key;
  - `stories.body` holds the **markdown**;
  - `Story.image` / `Advertisement.imageSource` stored as JSON text;
  - `edition_items`: issue date + item id + position, so one item can appear
    in more than one edition.
- [x] Each save is **one transaction** (`items` row + model row + body).
- [x] Re-upload of a story with the same `id` or `slug` updates it.
- [x] Inbox = items not in any `edition_items` row (`inbox()`); `place(_:inIssue:)`.
- [x] `swift run open_paper ingest --save` puts the drafts in `open_paper.sqlite`;
      tests in `Tests/OpenPaperKitTests`.
- [ ] Agenda points, quotes and ads have no natural key, so re-uploading them
      creates duplicates. Decide a key (or rely on the `id` in the front matter).
- [ ] `staged_uploads` and `images` tables for steps 3–4. Saving the image
      *file* (and pointing `source` at it) joins the save transaction then.

## 3. Upload and staging

- [ ] `POST /editor/uploads`: accept one or more `.md` files plus any images,
      run step 1, save the result to staging under an upload ID.
- [ ] If an image block names a `file` that wasn't sent, mark the item
      "waiting for image" and request the image upload for that ID.
- [ ] Remove staged uploads that are cancelled or older than 24 hours.

## 4. Review card

- [ ] `GET /editor/uploads/{id}`: editable fields, warnings, and a
      live preview using `StoryCard` / agenda / ad components.
- [ ] Save: run the checks again, then store the item in the inbox (`save`).
      The issue date is **not** chosen here any more.
- [ ] Cancel: discard the staged upload.
- [ ] Re-upload with an existing `slug`/`id`: show "update existing" with the
      changed fields highlighted.
- [ ] Plain HTML forms first; htmx later.

## 4b. Image processing (after step 4)

- [ ] Resize and crop (21:9, 16:10, 1:1) around `focalPoint`; convert to WebP.
- [ ] Remove EXIF / GPS location data.
- [ ] Switch `embed` to `store` above ~200 KB.

## 5. Arrange and publish an edition

- [ ] Inbox view: list unplaced items (`inbox()`), pick an issue date, place them.
- [ ] A page per date: list placed items, set order and lead, preview the full
      front page, publish.
- [ ] Public `/` serves the latest published edition.

## 6. Editor login

- [ ] Login and sessions for `/editor/*`.
- [ ] CSRF protection and upload size limits.
- [ ] Must be in place before the server runs anywhere others can reach it.
