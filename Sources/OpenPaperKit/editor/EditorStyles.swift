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
    .review.single { grid-template-columns: minmax(340px, 640px); justify-content: center; }
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

    /* Inbox page */
    .editor-main { max-width: 960px; margin: 0 auto; padding: 1.5rem; }
    .editor-main h1 { font-size: 1.4rem; margin-bottom: 1rem; }
    .editor-main h2 { font-size: 1.05rem; margin: 2rem 0 0.6rem; }
    .upload-form {
        display: flex; flex-wrap: wrap; gap: 0.75rem; align-items: end;
        background: #fff; border: 1px solid var(--border-light); border-radius: 6px;
        padding: 1rem; margin-bottom: 1rem;
    }
    .upload-form .field { margin-bottom: 0; }
    .upload-form .field.grow { flex: 1 1 260px; }
    .item-table {
        width: 100%; border-collapse: collapse; background: #fff;
        border: 1px solid var(--border-light); font-size: 0.9rem;
    }
    .item-table th, .item-table td { text-align: left; padding: 0.55rem 0.75rem; border-bottom: 1px solid var(--border-light); }
    .item-table th { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; color: var(--ink-secondary); }
    .empty { color: var(--ink-muted); font-size: 0.9rem; }
    .problems {
        font-size: 0.9rem; background: #fdecea; border-left: 3px solid #c0392b;
        padding: 0.6rem 0.9rem; margin-bottom: 1rem;
    }
    .problems ul { padding-left: 1.2rem; margin-top: 0.3rem; }
    .item-fields { background: #fff; border: 1px solid var(--border-light); border-radius: 6px; padding: 1rem 1.25rem; margin-bottom: 1.25rem; }
    .item-fields dt { font-size: 0.75rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; color: var(--ink-secondary); margin-top: 0.8rem; }
    .item-fields dt:first-child { margin-top: 0; }
    .item-fields dd { margin: 0.15rem 0 0; font-size: 0.95rem; overflow-wrap: anywhere; }

    /* Compose-an-issue page */
    .review-heading { grid-column: 1 / -1; margin-bottom: 0; }
    .pick-list { list-style: none; padding: 0; margin: 0 0 0.5rem; }
    .pick-list li { display: flex; gap: 0.6rem; align-items: baseline; padding: 0.15rem 0; border-bottom: 1px solid var(--border-light); }
    .pick-list li:last-child { border-bottom: none; }
    .pick-box { flex: none; padding: 0.4rem 0.25rem; cursor: pointer; }
    .pick-title {
        flex: 1; min-width: 0; font-size: 0.9rem; padding: 0.4rem 0;
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
    """
}
