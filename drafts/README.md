# drafts — upload format

One markdown file per item:

```
---
<YAML: the fields of the Swift model>
---
<markdown body, turned into HTML>
```

The YAML is decoded straight into the model, using the same field names as in
`Sources/open_paper/models/`:

| Folder            | Model           |
|-------------------|-----------------|
| `stories/`        | `Story`         |
| `agenda/`         | `AgendaPoint`   |
| `quoted/`         | `QuotedItem`    |
| `advertisements/` | `Advertisement` |

## Notes

- `id` can be left out; a new one is created.
- `priority`: `2` = high, `1` = normal.
- `category` (stories): `news`, `background` or `opinion`.
- Dates: `2026-11-20T06:00:00+01:00`.
- Images follow `ImageSource`:

  ```yaml
  source:          # `imageSource:` for advertisements
    endpoint:
      url: images/photo.jpg
  ```

- Fields that aren't in the model are ignored.
- The body is only used for stories (the article text).

## Check the drafts

```
swift run open_paper ingest
```
