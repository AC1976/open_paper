# To do: editor workflow

Each step should work end to end before the next one starts. The aim is to see
one upload go from file to database as early as possible.

## Open questions

- [ ] **One piece at a time, or a whole edition at once?** If editors usually
      upload ~15 items together, the review screen should be a list of cards
      rather than a single card.
- [ ] **Who are the editors?** One person → a single account in config is
      enough. Several people → a users table.

## 0. Check the foundation

- [ ] Run a bare Hummingbird 2 server on Windows. SwiftNIO's Windows support is
      the biggest unknown; if it doesn't work well, move development to WSL.
- [ ] Split the package: a library target (models, layout planner, HTML
      components) shared by the existing generator and a new `server` target.

## 1. File → model (no web page yet)

- [x] `loadUpload(_:from:)` in `models/Upload.swift`: split front matter from
      the body, decode the YAML straight into the model, body → HTML.
- [x] Check the drafts: `swift run open_paper ingest`.

## 2. Save to the database

Once `loadUpload` returns a model and the editor confirms the card, save it.

- [ ] Pick the SQLite library based on what worked in step 0.
- [ ] Tables, with migrations from the start:
  - one table per model (stories, agenda points, quotes, ads); the model's
    `id` is the row key;
  - stories get one extra `body` column with the **markdown** (render to HTML
    when the page is shown; optionally store the HTML too);
  - `Story.image` / `Advertisement.imageSource` saved as one JSON column;
  - `edition_items`: issue date + item id (+ position later), so one item can
    appear in more than one edition;
  - `staged_uploads` and `images` for steps 3–4.
- [ ] Save in **one transaction**, so it's all saved or nothing is:
  1. save the image file (if any) and point `source` at it;
  2. insert the model row (+ `body`);
  3. insert the (issue date, item id) row.

## 3. Upload and staging

- [ ] `POST /editor/uploads`: accept one or more `.md` files plus any images,
      run step 1, save the result to staging under an upload ID.
- [ ] If an image block names a `file` that wasn't sent, mark the item
      "waiting for image" and request the image upload for that ID.
- [ ] Remove staged uploads that are cancelled or older than 24 hours.

## 4. Review card

- [ ] `GET /editor/uploads/{id}`: editable fields, warnings, issue date, and a
      live preview using `StoryCard` / agenda / ad components.
- [ ] Save: run the checks again, then store the item and its placement in one
      transaction.
- [ ] Cancel: discard the staged upload.
- [ ] Re-upload with an existing `slug`/`id`: show "update existing" with the
      changed fields highlighted.
- [ ] Plain HTML forms first; htmx later.

## 4b. Image processing (after step 4)

- [ ] Resize and crop (21:9, 16:10, 1:1) around `focalPoint`; convert to WebP.
- [ ] Remove EXIF / GPS location data.
- [ ] Switch `embed` to `store` above ~200 KB.

## 5. Arrange and publish an edition

- [ ] A page per date: list placed items, set order and lead, preview the full
      front page, publish.
- [ ] Public `/` serves the latest published edition.

## 6. Editor login

- [ ] Login and sessions for `/editor/*`.
- [ ] CSRF protection and upload size limits.
- [ ] Must be in place before the server runs anywhere others can reach it.
