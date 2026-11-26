# To do

## Plan: crowd-written paper with a news desk

Anyone can submit a story, agenda point or quote. Editors file submissions from
the news desk and give them a publish date. Each day's paper is generated from
the items with that date.

### Decided

- Contributors fill in a form, or download a YAML template, complete it and
  upload it. **Author name and email are mandatory.**
- Every submission lands on the **news desk**. No email confirmation: the editor
  sees the address and judges whether the submission is legitimate.
- Filing an article gives it a **publish date**.
- A date's front page shows **only the items with that date**.
- Items filed with a future date appear by themselves when that date arrives
  (paper's time zone, Europe/Amsterdam). There is no Publish button.
- Advertisements stay editor-only.

### Steps (in order)

- [x] **A. Editor login.** Accounts are made on the command line
      (`swift run server add-editor you@example.com`; also `set-password`,
      `remove-editor`, `list-editors`). Bcrypt passwords, 12-hour sessions
      stored hashed, HttpOnly SameSite cookie, own-site check on every
      `/editor` POST, lockout after 5 failed attempts in 15 minutes. Set
      `OPEN_PAPER_HTTPS=1` when served over HTTPS.
  - [ ] Before putting it online: HTTPS in front, and rate limiting by address
        (the lockout is per email, so someone could lock an editor out).
- [x] **B. Publish dates replace issue placement.** Items are submitted, filed
      (with one publish date) or rejected. Migration `v5` files items from
      published issues under their first published date; the old
      `edition_items` table is kept but unused. Front page, section pages,
      article pages and issue number follow the publish date, and nothing dated
      after today (Europe/Amsterdam) is visible. `/` shows the latest date that
      has items. `/editor/issues/{date}` shows a date's items, sets the layout
      and previews. The compose page and Publish button are gone.
- [x] **C. News desk** (`/editor`). Submitted items with type, author and time
      received; filed and rejected below. On an item: save, "Save and file" with
      a date, reject, or send back to the desk. Category and priority are set
      on the same page.
  - [x] Contributor name and email are shown on the desk and the item page.
  - [ ] No manual order or lead choice within a date (priority, then time received).
  - [ ] Advertisements take a single publish date, like articles. Confirm, or
        give them a date range.
  - [ ] Edits to an item that is already visible go live at once.
- [x] **D. Safe to accept strangers.** (`Sources/OpenPaperKit/safety/`)
  - Every upload creates a new item (`submit`); only an edit page changes one.
    A taken slug gets a number.
  - Contributors' `id`, `slug`, priority, dates and story image address are
    ignored; slugs come from titles.
  - Article HTML is rebuilt from an allowlist; raw HTML shows as text; links
    must be http(s)/mailto; images in article text are dropped.
  - Links are checked on upload as well as in forms; fields have length
    limits; YAML aliases are refused.
  - Uploaded photos are recognised by their bytes; location and other metadata
    are removed (JPEG orientation kept).
  - Rate limit and hidden spam-trap field are written and tested
    (`SubmissionGuard`), connected in step E.
  - [x] `SubmissionGuard` is connected to the public form (step E).
  - [ ] Limit picture dimensions as well as file size.
  - [ ] Add a Content-Security-Policy header as a second line of defence.
  - [ ] Pictures stored before this step still carry their metadata.
  - [ ] Login lockout by network address as well as by email.
- [x] **E. Contribute pages** (`/contribute`, linked from the masthead). Forms
      for stories, agenda points and quotes with a live preview; downloadable
      templates that load into the form for checking before sending. Name and
      email required; stored with the item and shown on the news desk only (the
      email never reaches a reader page). A story's byline is the contributor's
      name. Privacy notice on the form. No "I wrote this myself" tick box (your
      decision). Spam trap, 5 submissions an hour per address and 100 overall,
      own-site posts only. Set `OPEN_PAPER_TRUST_PROXY=1` behind your own proxy.
  - [ ] The preview does not show the picture (a thumbnail shows under the field).
  - [ ] Editors cannot delete items; rejected submissions keep names and email
        addresses. Decide how long to keep them and add deletion.
  - [ ] No terms or permission to publish are asked for. Consider a line above
        the Send button saying that sending allows publication.
  - [ ] The rate limit is held in memory and resets when the server restarts;
        100 pictures an hour can still grow the database quickly.
  - [ ] Agenda points and quotes show no contributor name to readers.

### Open questions

- [ ] A day with nothing filed: `/` currently shows the last day that had items,
      under its own date. Confirm, or show an empty paper.
- [ ] Do advertisements get a publish date like articles, or a date range?
- [ ] Do contributors hear back (accepted / rejected)?

---

# Earlier work: editor workflow

(The inbox, compose page and publishing described below were replaced in step B.)

Each step should work end to end before the next one starts. The aim is to see
one upload go from file to database as early as possible. Where this conflicts
with the plan above, the plan above wins.

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
      components, database) used by the `server`, and the
      `server` target.

## 1. File → model (no web page yet)

- [x] `parseUpload(_:text:name:)` in `models/Upload.swift`: split front matter from
      the body, decode the YAML straight into the model, body → HTML. (The
      command-line `ingest` tool and the static-page generator are gone; the
      web editor is the way in.)

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
- [x] Tests in `Tests/OpenPaperKitTests`.
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
- [x] Section pages: the masthead links (`/sections/news`, `background`, `opinion`,
      `agenda`, `quoted`) are served from the database, in the front page's style.
      They list everything that appeared in a **published** issue, newest first:
      stories by `publishedAt`, agenda points by `eventDate`, quotes by the date of
      their issue (an item without a date follows its issue). Drafts and the inbox
      never show up. The masthead shows the date and number of the current front page.
- [x] Article pages `/articles/{slug}` (the headline links already point there), for
      stories in a **published** issue only. Three characters in the front page's
      style: **news** (red kicker, live dot when breaking, bold headline, standfirst,
      wide photo), **background** (analysis label, side column with an "In brief" box
      and an "In this article" list made from the headings) and **opinion** (centred,
      italic headline, framed author name, drop cap, closing note). Each ends with
      "More in {section}". Shows byline, dates and reading time.
- [ ] Article images are embedded as base64 (like the front page); serve them from
      an address so a large photo does not make the page heavy.
- [ ] Article pages have no share links, social preview tags or related-by-topic;
      "More in {section}" is simply the newest stories of the same category.
- [ ] The body markdown may contain raw HTML (it is passed through to the page).
      Fine for trusted editors; sanitise before opening uploads to anyone else.
- [ ] Section pages list everything on one page; add paging or a date filter once
      the archive grows.

## 6. Editor login

- [x] Login and sessions for `/editor/*` (see step A above).
- [x] CSRF protection and upload size limits.
- [x] Must be in place before the server runs anywhere others can reach it.
