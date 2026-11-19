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

Done as one item at a time. Run `swift run server`, open http://127.0.0.1:8080/editor
(database: `open_paper.sqlite`, or the path in `OPEN_PAPER_DB`).

- [x] `POST /editor/uploads`: one `.md` file plus its type (story, agenda point,
      quote, advertisement). It is parsed, kept in `staged_uploads`, and the
      editor is sent to the review page. A bad file shows its error on `/editor`.
- [x] Staged uploads older than 24 hours are removed whenever a new one is staged.
- [x] Cancel discards the staged upload.
- [ ] Upload a story together with its image (the image is chosen on the review
      page for now). If the front matter names a local image that was not sent,
      mark the item "waiting for image".
- [ ] Several files in one request (only needed if editors ask for it).

## 4. Review card

- [x] `GET /editor/uploads/{id}`: editable story fields, warnings and a live
      preview using `StoryCard`. Other kinds get a read-only page.
- [x] Save (`POST /editor/uploads/{id}`): validates the submitted fields, then
      stores the item in the inbox and removes the staged upload in one
      transaction. The issue date is **not** chosen here.
- [x] "Update preview" re-renders with the edited fields without saving.
- [x] Cancel: discard the staged upload.
- [x] Image chosen on the review page is stored with the story (JPEG/PNG/WebP,
      up to 5 MB, embedded until step 4b).
- [x] `/editor` lists the inbox (items not in any issue).
- [ ] When a save fails validation the page shows the *original* upload again
      with the messages; the editor's edits are lost. Re-render with the
      submitted values instead.
- [ ] Edited items are not versioned: saving overwrites. Consider keeping the
      previous version.
- [ ] Re-upload with an existing `slug`/`id`: show "update existing" with the
      changed fields highlighted (the save already updates in place).
- [x] Agenda points, quotes and ads are editable on the review page too, with
      the same checks (links must be http/https).
- [ ] Plain HTML forms first; htmx later.

## 4b. Image processing (after step 4)

- [ ] Resize and crop (21:9, 16:10, 1:1) around `focalPoint`; convert to WebP.
- [ ] Remove EXIF / GPS location data.
- [ ] Switch `embed` to `store` above ~200 KB.

## 5. Arrange and publish an edition

- [x] Compose page `/editor/issues/{date}` (`/editor/issues` opens today). Left:
      the issue date and the inbox. Right: "In this issue", the edition switch
      and Publish. Tick an inbox item and its title moves to the right (untick
      to send it back); the change is saved at once by a small script, so the
      page needs JavaScript.
- [x] Click an item's title (inbox or issue) to edit it:
      `/editor/issues/{date}/items/{id}`. Save and Cancel return to that issue.
      A story's uploaded image is kept unless you choose a new file or tick
      "Remove the image". Changing a slug to one another story uses is refused.
- [x] Edition switch per issue: **breaking** (lead across 4 columns),
      **prominent** (2) or **regular** (1). Saved when chosen, and used for the
      front page.
- [x] Publish: the issue becomes the front page (`/`) and the editor is taken
      there. `/` shows the issue **published most recently** (publishing an
      older issue again brings it back to the front). An issue with nothing
      in it cannot be published.
- [x] Drafts are private: `/issues/{date}` only serves published issues; editors
      preview any issue at `/editor/issues/{date}/preview`.
- [x] `PaperDatabase.issue(on:)` loads an issue (items, mode, published time)
      and `IssueContents` turns it into the metadata and layout plan.
- [ ] Changes to a published issue (adding, removing, editing items) go live
      immediately. Consider "publish" taking a snapshot instead.
- [ ] Unpublish / withdraw an issue.
- [ ] Set the order by hand (move up / down) and choose the lead story; items
      appear in the order they were placed, and the layout sorts by priority.
- [ ] Without JavaScript the compose page cannot move items.
- [ ] Masthead details (paper title, subtitle, edition label) are fixed in
      `IssueContents.metadata`; move them to a settings file.
- [ ] Stored images are embedded in the page as base64. Serve them from an
      address instead so the front page stays small.
- [ ] Section pages (`/news`, ...) from the database; the masthead links to
      them but the server does not serve them yet.

## 6. Editor login

- [ ] Login and sessions for `/editor/*`.
- [ ] CSRF protection and upload size limits.
- [ ] Must be in place before the server runs anywhere others can reach it.
