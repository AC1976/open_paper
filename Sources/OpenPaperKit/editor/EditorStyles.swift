import Foundation

/// Plain styles for the editor pages. Loaded after `BroadsheetStyles`, so the
/// preview looks exactly like the paper while the form stays simple.
package enum EditorStyles {
    package static let css: String = """
    body {
        background: #f3f3f1;
        font-family: var(--font-sans);
    }

    /* Top bar */
    .editor-bar {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 0.75rem 1.5rem;
        background: var(--ink-primary);
        color: #fff;
    }
    .editor-brand { font-weight: 700; letter-spacing: 0.02em; }
    /* Contribute pages */
    .contribute-intro { grid-column: 1 / -1; }
    .contribute-intro p { font-size: 0.95rem; color: var(--ink-secondary); max-width: 60ch; }
    .kind-tabs { display: flex; gap: 0.5rem; flex-wrap: wrap; margin-top: 1rem; }
    .kind-tabs a { text-decoration: none; }
    .kind-tabs a[aria-current] { background: var(--ink-primary); border-color: var(--ink-primary); color: #fff; }
    .trap { position: absolute; left: -10000px; width: 1px; height: 1px; overflow: hidden; }
    .privacy { font-size: 0.8rem; color: var(--ink-secondary); margin: 0 0 1rem; max-width: 60ch; }
    .thumbnail { display: block; width: auto; height: auto; max-width: 160px; max-height: 120px; margin-top: 0.5rem; border-radius: 4px; }
    .editor-logout { margin: 0; }
    .editor-logout button { background: none; border: none; padding: 0; font: inherit; font-size: 0.9rem; cursor: pointer; }
    .login { max-width: 420px; margin: 3rem auto; padding: 0 1rem; }
    .login .actions { margin-bottom: 0; }
    .editor-nav { display: flex; gap: 1.25rem; }
    .editor-link { color: #ddd; text-decoration: none; font-size: 0.9rem; }
    .editor-link:hover { color: #fff; }

    /* Two columns: form | preview */
    .review {
        display: grid;
        grid-template-columns: minmax(340px, 1fr) minmax(360px, 1.1fr);
        gap: 2rem;
        max-width: 1280px;
        margin: 0 auto;
        padding: 1.5rem;
        align-items: start;
    }
    .review > * { min-width: 0; }
    .review-title { font-size: 1.4rem; margin-bottom: 1rem; }

    /* Form */
    .review-form fieldset {
        border: 1px solid var(--border-light);
        background: #fff;
        border-radius: 6px;
        padding: 1rem 1.25rem 0.25rem;
        margin-bottom: 1.25rem;
        min-width: 0;   /* fieldsets otherwise refuse to shrink below their content */
    }
    .review-form legend {
        font-size: 0.75rem;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        color: var(--ink-secondary);
        padding: 0 0.35rem;
    }
    .field { display: flex; flex-direction: column; margin-bottom: 0.9rem; flex: 1; min-width: 0; }
    .field-row { display: flex; gap: 1rem; }
    .field label { font-size: 0.85rem; font-weight: 600; margin-bottom: 0.3rem; }
    .field input, .field select, .field textarea {
        font: inherit;
        font-size: 0.95rem;
        padding: 0.45rem 0.55rem;
        border: 1px solid #c9c9c9;
        border-radius: 4px;
        background: #fff;
        width: 100%;
    }
    .field textarea { resize: vertical; line-height: 1.4; }
    .field textarea.markdown { font-family: ui-monospace, Consolas, monospace; font-size: 0.85rem; }
    .field input:focus, .field select:focus, .field textarea:focus {
        outline: 2px solid #2b6cb0;
        outline-offset: 0;
        border-color: #2b6cb0;
    }
    .hint { font-size: 0.75rem; color: var(--ink-muted); margin-top: 0.25rem; }
    .notice {
        font-size: 0.85rem;
        background: #fff8e1;
        border-left: 3px solid #e0a800;
        padding: 0.5rem 0.75rem;
        margin-bottom: 0.9rem;
    }
    .notice code { font-size: 0.8rem; }

    /* Buttons */
    .actions { display: flex; gap: 0.75rem; align-items: center; margin-bottom: 2rem; }
    .button {
        font: inherit;
        font-size: 0.9rem;
        font-weight: 600;
        padding: 0.55rem 1.1rem;
        border-radius: 4px;
        border: 1px solid #b5b5b5;
        background: #fff;
        color: var(--ink-primary);
        cursor: pointer;
        text-decoration: none;
    }
    .button.primary { background: var(--ink-primary); border-color: var(--ink-primary); color: #fff; }
    .button.quiet { border-color: transparent; background: transparent; color: var(--ink-secondary); }

    /* Preview */
    .review-preview { position: sticky; top: 1rem; }
    .preview-label {
        font-size: 0.75rem;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        color: var(--ink-secondary);
        margin: 0 0 0.5rem;
    }
    .preview-frame {
        background: #fff;
        border: 1px solid var(--border-light);
        border-radius: 6px;
        padding: 1.25rem;
        margin: 0 0 1.5rem;
        max-width: none;
        font-family: var(--font-serif);
    }
    .preview-frame .story-card { border-bottom: none; padding-bottom: 0; }
    .preview-frame .story-card::after { display: none; }
    .article-body .headline { font-size: 1.6rem; }
    .article-body h2 { font-size: 1.15rem; margin: 1rem 0 0.4rem; }
    .article-body p, .article-body li { font-size: 1rem; margin-bottom: 0.6rem; }
    .article-body ul { padding-left: 1.25rem; margin-bottom: 0.6rem; }
    .article-body blockquote {
        border-left: 2px solid var(--border-heavy);
        padding-left: 0.85rem;
        font-style: italic;
        color: var(--ink-secondary);
        margin: 0.75rem 0;
    }

    /* Plain pages (nothing published yet) */
    .editor-main { max-width: 960px; margin: 0 auto; padding: 1.5rem; }
    .editor-main h1 { font-size: 1.4rem; margin-bottom: 1rem; }
    .empty { color: var(--ink-muted); font-size: 0.9rem; }
    .problems {
        font-size: 0.9rem; background: #fdecea; border-left: 3px solid #c0392b;
        padding: 0.6rem 0.9rem; margin-bottom: 1rem;
    }
    .problems ul { padding-left: 1.2rem; margin-top: 0.3rem; }

    /* News desk: folders and list on the left, the open item on the right.
       Each column scrolls by itself. */
    .desk-shell { display: flex; flex-direction: column; height: 100vh; height: 100dvh; }
    .desk { flex: 1; min-height: 0; display: grid; grid-template-columns: minmax(260px, 360px) minmax(0, 1fr); }
    .desk-list { overflow-y: auto; background: #fff; border-right: 1px solid var(--border-light); }
    .desk-reading { overflow-y: auto; min-width: 0; }

    .desk-folders {
        display: flex; position: sticky; top: 0; z-index: 1;
        background: #fff; border-bottom: 1px solid var(--border-light);
    }
    .desk-folders a {
        flex: 1; text-align: center; padding: 0.75rem 0.4rem; text-decoration: none;
        font-size: 0.85rem; font-weight: 600; color: var(--ink-secondary); border-bottom: 3px solid transparent;
    }
    .desk-folders a[aria-current] { color: var(--ink-primary); border-bottom-color: #2b6cb0; }
    .desk-count { margin-left: 0.35rem; font-weight: 400; color: var(--ink-muted); }

    .desk-upload { padding: 0.65rem 1rem; border-bottom: 1px solid var(--border-light); }
    .desk-upload summary { cursor: pointer; font-size: 0.85rem; color: #1d4f91; }
    .desk-upload form, .desk-upload .problems { margin-top: 0.75rem; }

    .desk-empty { padding: 1rem; }
    .desk-rows { list-style: none; margin: 0; padding: 0; }
    .desk-row {
        display: flex; flex-direction: column; gap: 0.2rem; padding: 0.7rem 1rem;
        text-decoration: none; color: var(--ink-primary);
        border-bottom: 1px solid var(--border-light); border-left: 3px solid transparent;
    }
    .desk-row:hover { background: #f5f8fb; }
    .desk-row[aria-current] { background: #e8f1fa; border-left-color: #2b6cb0; }
    .desk-row-top { display: flex; justify-content: space-between; gap: 0.75rem; font-size: 0.78rem; color: var(--ink-secondary); }
    .desk-row-from { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .desk-row-date { flex: none; }
    .desk-row-title { font-size: 0.95rem; font-weight: 600; line-height: 1.3; overflow-wrap: anywhere; }
    .desk-row-tags { display: flex; gap: 0.4rem; }
    .desk-tag {
        font-size: 0.65rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em;
        color: var(--ink-secondary); background: #efefec; border-radius: 3px; padding: 0.1rem 0.35rem;
    }
    .desk-tag.state { background: #fff1c2; color: #6b4e00; }

    .desk-toolbar {
        display: flex; flex-wrap: wrap; justify-content: space-between; gap: 0.75rem; align-items: end;
        position: sticky; top: 0; z-index: 1; padding: 0.65rem 1.5rem;
        background: #fff; border-bottom: 1px solid var(--border-light);
    }
    .desk-publish, .desk-edit { display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: end; }
    .desk-date { display: flex; flex-direction: column; font-size: 0.72rem; font-weight: 600; color: var(--ink-secondary); }
    .desk-date input {
        font: inherit; font-size: 0.9rem; font-weight: 400; padding: 0.42rem 0.5rem;
        border: 1px solid #c9c9c9; border-radius: 4px;
    }
    .default-submit { position: absolute; left: -10000px; width: 1px; height: 1px; }
    .desk-content { max-width: 800px; margin: 0 auto; padding: 1.25rem 1.5rem 3rem; }
    .desk-heading { margin-bottom: 1rem; }
    .desk-heading h1 { font-family: var(--font-serif); font-size: 1.6rem; line-height: 1.25; margin-bottom: 0.4rem; overflow-wrap: anywhere; }
    .desk-heading .status { margin-bottom: 0.2rem; }
    .desk-picture { display: block; width: auto; height: auto; max-width: 100%; max-height: 22rem; margin: 0 auto 0.9rem; }
    .desk-notice {
        margin: 0; padding: 0.6rem 1.5rem; font-size: 0.9rem;
        background: #e7f4e8; border-bottom: 1px solid #bfdfc2;
    }
    .desk-placeholder { padding: 3rem 1.5rem; text-align: center; }
    .desk-back { display: none; }

    /* The preview, over the news desk */
    .preview-dialog {
        width: min(960px, 94vw); height: 90vh; max-width: none; max-height: none; margin: auto; padding: 0;
        border: none; border-radius: 8px; box-shadow: 0 20px 60px rgba(0, 0, 0, 0.35);
    }
    .preview-dialog[open] { display: flex; flex-direction: column; }
    .preview-dialog::backdrop { background: rgba(0, 0, 0, 0.45); }
    .preview-dialog-bar {
        display: flex; justify-content: space-between; align-items: center;
        padding: 0.6rem 1rem; border-bottom: 1px solid var(--border-light);
    }
    #preview-holder { flex: 1; min-height: 0; }
    #preview-holder iframe { width: 100%; height: 100%; border: 0; display: block; }
    .preview-page { max-width: 760px; margin: 0 auto; padding: 1.25rem; }
    .preview-ad { max-width: 320px; }

    /* Compose-an-issue page */
    .review-heading { grid-column: 1 / -1; margin-bottom: 0; }
    .pick-list { list-style: none; padding: 0; margin: 0 0 0.5rem; }
    .pick-list li { display: flex; gap: 0.6rem; align-items: baseline; padding: 0.15rem 0; border-bottom: 1px solid var(--border-light); }
    .pick-list li:last-child { border-bottom: none; }
    .pick-box { flex: none; padding: 0.4rem 0.25rem; cursor: pointer; }
    .pick-text { flex: 1; min-width: 0; }
    .pick-run { display: block; font-size: 0.75rem; color: var(--ink-secondary); padding-bottom: 0.4rem; }
    .pick-title {
        display: block; font-size: 0.9rem; padding: 0.4rem 0;
        color: #1d4f91; text-decoration: underline; text-decoration-color: #b9c9de; text-underline-offset: 3px;
    }
    .pick-title:hover { text-decoration-color: currentColor; }
    .pick-kind {
        flex: none; font-size: 0.7rem; font-weight: 700;
        text-transform: uppercase; letter-spacing: 0.05em; color: var(--ink-secondary);
    }
    .list-hint { margin: 0 0 0.5rem; }
    .issue-picker { display: flex; gap: 0.75rem; align-items: end; }
    .issue-picker .field { flex: 1; margin-bottom: 0; }
    .mode-options { display: grid; gap: 0.5rem; }
    .mode-option {
        display: flex; gap: 0.7rem; align-items: flex-start; cursor: pointer;
        border: 1px solid var(--border-light); border-radius: 4px; padding: 0.6rem 0.75rem;
    }
    .mode-option:has(input:checked) { border-color: #2b6cb0; background: #f2f7fc; }
    .mode-option input { margin-top: 0.2rem; }
    .mode-option span { display: flex; flex-direction: column; gap: 0.1rem; }
    .mode-option small { color: var(--ink-muted); font-size: 0.78rem; }
    .status { font-size: 0.85rem; color: var(--ink-secondary); margin: 0 0 0.9rem; }
    [hidden] { display: none !important; }

    @media (max-width: 900px) {
        .review { grid-template-columns: 1fr; }
        .review-preview { position: static; }
    }

    /* Narrow screens show the list or the open item, one at a time. */
    @media (max-width: 760px) {
        .desk { grid-template-columns: minmax(0, 1fr); }
        .desk-shell.show-list .desk-reading { display: none; }
        .desk-shell.show-item .desk-list { display: none; }
        .desk-shell.show-item .desk-back { display: block; padding: 0.6rem 1rem; font-size: 0.9rem; }
        .desk-toolbar { position: static; padding: 0.65rem 1rem; }
        .desk-content { padding: 1rem 1rem 3rem; }
        .desk-content .field-row { flex-direction: column; gap: 0; }
    }
    """
}
