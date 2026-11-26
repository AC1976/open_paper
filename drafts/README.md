# drafts — upload format

Example files for the editor. Upload them at http://127.0.0.1:8080/editor (run
`swift run server`), choosing the type that matches the folder.

One markdown file per item:

```
---
<YAML: the fields of the Swift model>
---
<markdown body, turned into HTML>
```

The header uses the same field names as the models in
`Sources/OpenPaperKit/models/`:

| Folder            | Model           |
|-------------------|-----------------|
| `stories/`        | `Story`         |
| `agenda/`         | `AgendaPoint`   |
| `quoted/`         | `QuotedItem`    |
| `advertisements/` | `Advertisement` |

## Notes

- Every upload becomes a **new** item; it never replaces an existing one.
- `id`, `slug`, `priority`, `publishedAt` and `updatedAt` are **ignored**:
  editors set them on the review page.
- Stories have no image fields. A picture is uploaded separately, on the
  contribute form or the review page.
- Links must start with `http://` or `https://`. HTML in the text is shown as
  text, and pictures in the text are removed.
- YAML anchors and aliases (`&`, `*`) are not allowed in the header.
- `category` (stories): `news`, `background` or `opinion`.
- Dates: `2026-11-20T06:00:00+01:00`.
- Advertisements (editors only) name their image like this:

  ```yaml
  imageSource:
    endpoint:
      url: images/photo.jpg
  ```

- Fields that aren't in the model are ignored.
- The body is only used for stories (the article text).
