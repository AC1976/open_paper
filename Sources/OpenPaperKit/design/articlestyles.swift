import Foundation

/// Styles for the article page. Loaded after `BroadsheetStyles`, so it uses the
/// same fonts, colours and rules. Each category has its own character:
///
/// - news: a red kicker, a bold headline and a plain, wide reading column;
/// - background: a black label and a side column with an "in brief" box and contents;
/// - opinion: a centred, quieter layout with an italic headline and a drop cap.
package enum ArticleStyles {
    package static let css: String = """
    /* =========================================
    Article page: shared
    ========================================= */
    .article { margin: 2.25rem auto 3rem; }

    .article-kicker {
        display: inline-flex; align-items: center; gap: 0.4rem;
        font-family: var(--font-sans); font-size: 0.72rem; font-weight: 800;
        letter-spacing: 0.08em; text-transform: uppercase;
    }
    .article-kicker a { color: inherit; text-decoration: none; }
    .article-kicker a:hover { text-decoration: underline; text-underline-offset: 3px; }

    .article-headline {
        font-family: var(--font-serif); font-weight: 700;
        line-height: 1.1; letter-spacing: -0.012em;
        margin: 0.6rem 0 1rem; color: var(--ink-primary);
    }
    .article-standfirst { font-size: 1.3rem; line-height: 1.4; color: #333; margin-bottom: 0.9rem; }
    .article-standfirst-extra { font-size: 1.05rem; line-height: 1.55; color: var(--ink-secondary); margin-bottom: 0.9rem; }

    .article-meta {
        font-family: var(--font-sans); font-size: 0.78rem; color: var(--ink-secondary);
        line-height: 1.6; margin-top: 1rem; padding-top: 0.85rem; border-top: 1px solid var(--border-light);
    }
    .article-author { display: block; font-size: 0.82rem; font-weight: 700; letter-spacing: 0.04em; text-transform: uppercase; color: var(--ink-primary); }
    .article-dates span + span::before { content: "\\00b7"; margin: 0 0.45rem; }

    .article-figure { margin: 1.75rem 0; }
    .article-figure img { display: block; width: 100%; height: auto; max-height: 38rem; object-fit: cover; background: #f0f0f0; }
    .article-figure figcaption {
        font-family: var(--font-sans); font-size: 0.78rem; color: var(--ink-secondary);
        margin-top: 0.55rem; line-height: 1.45;
    }
    .article-figure .image-credit { color: var(--ink-muted); margin-left: 0.25rem; }

    .article-text { font-size: 1.14rem; line-height: 1.72; color: #1b1b1b; }
    .article-text p { margin-bottom: 1.2rem; }
    .article-text h2 { font-size: 1.5rem; line-height: 1.2; margin: 2.2rem 0 0.7rem; scroll-margin-top: 1rem; }
    .article-text h3 { font-size: 1.2rem; margin: 1.7rem 0 0.5rem; }
    .article-text ul, .article-text ol { padding-left: 1.4rem; margin-bottom: 1.2rem; }
    .article-text li { margin-bottom: 0.45rem; }
    .article-text a { color: inherit; text-decoration: underline; text-decoration-thickness: 1px; text-underline-offset: 3px; }
    .article-text blockquote {
        margin: 1.8rem 0; padding-left: 1.1rem; border-left: 3px solid var(--border-heavy);
        font-size: 1.25rem; line-height: 1.5; font-style: italic; color: #2b2b2b;
    }
    .article-text blockquote p { margin-bottom: 0; }
    .article-text img { max-width: 100%; height: auto; }

    /* =========================================
    News: wire-story clarity
    ========================================= */
    .article-news { max-width: 1000px; }
    .article-news .article-kicker { color: #d0021b; }
    .article-news .live-dot { flex: none; }
    .article-news.article-breaking .article-head { border-top: 3px solid #d0021b; padding-top: 1.1rem; }
    .article-news .article-head,
    .article-news .article-text { max-width: 690px; margin-left: auto; margin-right: auto; }
    .article-news .article-headline { font-size: 2.8rem; }
    .article-news .article-headline { font-weight: 800; }

    /* =========================================
    Background: analysis with a side column
    ========================================= */
    .article-background { max-width: 1040px; }
    .article-background .article-head { border-top: 1px solid var(--border-heavy); padding-top: 1.1rem; max-width: 820px; }
    .article-background .article-kicker {
        color: var(--ink-primary); background: #f2f2f2; border-left: 3px solid var(--border-heavy); padding: 0.2rem 0.55rem;
    }
    .article-background .article-headline { font-size: 2.45rem; font-weight: 700; }
    .article-background .article-body-wrap {
        display: grid; grid-template-columns: 250px minmax(0, 680px); gap: 3rem; align-items: start;
    }
    .article-aside { position: sticky; top: 1.25rem; font-family: var(--font-sans); }
    .aside-block { border-top: 3px solid var(--border-heavy); padding-top: 0.7rem; margin-bottom: 1.75rem; }
    .aside-label { font-size: 0.7rem; font-weight: 800; letter-spacing: 0.08em; text-transform: uppercase; margin-bottom: 0.6rem; }
    .aside-text { font-family: var(--font-serif); font-size: 0.98rem; line-height: 1.5; color: #2b2b2b; }
    .article-contents { list-style: none; padding: 0; margin: 0; }
    .article-contents li { padding: 0.45rem 0; border-bottom: 1px solid var(--border-light); font-size: 0.85rem; line-height: 1.35; }
    .article-contents a { color: var(--ink-secondary); text-decoration: none; }
    .article-contents a:hover { color: var(--ink-primary); text-decoration: underline; }

    /* =========================================
    Opinion: a single, quieter voice
    ========================================= */
    .article-opinion { max-width: 720px; }
    .article-opinion .article-head { text-align: center; }
    .article-opinion .article-kicker {
        display: flex; justify-content: center; align-items: center; gap: 1rem;
        color: var(--ink-secondary); font-weight: 700;
    }
    .article-opinion .article-kicker::before,
    .article-opinion .article-kicker::after { content: ""; flex: 1; height: 1px; background: var(--border-light); }
    .article-opinion .article-headline { font-size: 2.7rem; font-style: italic; font-weight: 700; margin-top: 1.1rem; }
    .article-opinion .article-standfirst { font-style: italic; color: #444; }
    .article-opinion .article-meta { border-top: none; padding-top: 0; margin-top: 1.2rem; margin-bottom: 1.8rem; }
    .article-opinion .article-author {
        font-family: var(--font-serif); font-size: 1.1rem; font-weight: 700; letter-spacing: 0; text-transform: none;
        display: inline-block; padding: 0.35rem 1.4rem; border-top: 1px solid var(--border-heavy); border-bottom: 1px solid var(--border-heavy);
        margin-bottom: 0.7rem;
    }
    .article-opinion .article-text { font-size: 1.2rem; line-height: 1.78; }
    .article-opinion .article-text > p:first-of-type::first-letter {
        float: left; font-size: 4rem; line-height: 0.82; font-weight: 700; padding: 0.3rem 0.55rem 0 0;
    }
    .article-opinion .article-text blockquote { border-left: none; text-align: center; padding: 0 1rem; font-size: 1.4rem; }
    .opinion-note {
        font-family: var(--font-sans); font-size: 0.78rem; font-style: italic; color: var(--ink-muted);
        text-align: center; border-top: 1px solid var(--border-light); padding-top: 1rem; margin-top: 2.5rem;
    }

    /* =========================================
    More in this section
    ========================================= */
    .article-related { max-width: 1000px; margin: 3rem auto 0; border-top: 2px solid var(--border-heavy); padding-top: 0.9rem; }
    .article-opinion + .article-related { max-width: 720px; }
    .related-heading {
        font-family: var(--font-sans); font-size: 0.75rem; font-weight: 800;
        letter-spacing: 0.08em; text-transform: uppercase; margin-bottom: 1rem;
    }
    .related-heading a { color: inherit; text-decoration: none; }
    .related-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 1.75rem; }
    .related-card .headline { font-size: 1.15rem; }
    .related-card .summary { font-size: 0.9rem; }

    @media (max-width: 860px) {
        .article-background .article-body-wrap { grid-template-columns: minmax(0, 1fr); gap: 1.25rem; }
        .article-aside { position: static; }
        .article-news .article-headline, .article-opinion .article-headline { font-size: 2.1rem; }
        .article-background .article-headline { font-size: 1.9rem; }
    }

    @media print {
        .section-nav, .article-related { display: none; }
        .article-aside { position: static; }
    }
    """
}
