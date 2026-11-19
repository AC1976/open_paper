import Foundation

package enum BroadsheetStyles {
    package static let css: String = """
    /* =========================================
    1. Base Variables & Reset
    ========================================= */
    :root {
        --bg-paper: #ffffff;
        --ink-primary: #121212;
        --ink-secondary: #5a5a5a;
        --ink-muted: #727272;
        --border-heavy: #121212;
        --border-light: #e2e2e2;
        --ad-bg: #f7f7f7;

        --font-serif: "Georgia", "Times New Roman", Times, serif;
        --font-sans: -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif;
    }

    * {
        box-sizing: border-box;
        margin: 0;
        padding: 0;
    }

    body {
        background-color: var(--bg-paper);
        color: var(--ink-primary);
        font-family: var(--font-serif);
        line-height: 1.45;
        -webkit-font-smoothing: antialiased;
    }

    /* =========================================
    2. Broadsheet Container & Masthead
    ========================================= */
    .broadsheet {
        max-width: 1280px;
        margin: 0 auto;
        padding: 1.5rem 2rem 4rem;
    }

    .nyt-masthead {
        text-align: center;
        padding-bottom: 1rem;
        margin-bottom: 1.5rem;
        border-bottom: 4px double var(--border-heavy);
    }

    .nyt-masthead h1 {
        font-family: var(--font-serif);
        font-size: clamp(2.25rem, 5vw, 3.75rem);
        font-weight: 700;
        font-variant: small-caps;
        letter-spacing: 0.01em;
        line-height: 1.3;
    }

    /* =========================================
    3. Four-Column Desktop Grid (External Monitor)
    ========================================= */
    .four-column-grid {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        grid-auto-flow: dense;
        gap: 1.5rem;
        align-items: start;
    }

    /* Dynamic Column Spans from Swift EditionMode */
    .span-4 {
        grid-column: span 4;
    }

    .span-2 {
        grid-column: span 2;
    }

    .span-1 {
        grid-column: span 1;
    }

    /* =========================================
    4. Story Cards & Hairline Dividers
    ========================================= */
    .story-card {
        padding-bottom: 1.25rem;
        border-bottom: 1px solid var(--border-light);
        position: relative;
    }

    .story-card::after {
        content: "";
        display: table;
        clear: both;
    }

    /* Vertical hairline divider between columns on desktop */
    @media (min-width: 961px) {
        .story-card:not(.span-4)::after,
        .opinion-rail::after {
            content: "";
            position: absolute;
            top: 0;
            right: -0.75rem;
            bottom: 0;
            width: 1px;
            background-color: var(--border-light);
        }
    }

    .kicker {
        display: block;
        font-family: var(--font-sans);
        font-size: 0.7rem;
        font-weight: 700;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: var(--ink-secondary);
        margin-bottom: 0.35rem;
    }

    .headline {
        font-family: var(--font-serif);
        font-size: 1.35rem;
        font-weight: 700;
        line-height: 1.2;
        margin-bottom: 0.45rem;
        color: var(--ink-primary);
    }

    .byline {
        font-family: var(--font-sans);
        font-size: 0.75rem;
        text-transform: uppercase;
        letter-spacing: 0.04em;
        color: var(--ink-muted);
        margin-bottom: 0.65rem;
    }

    .summary {
        font-size: 0.95rem;
        color: #2b2b2b;
    }

    .headline a {
        color: inherit;
        text-decoration: none;
    }

    .headline a:hover {
        text-decoration: underline;
        text-decoration-thickness: 1.5px;
        text-underline-offset: 3px;
    }

    /* =========================================
    5. Edition Mode Lead Story Scaling
    ========================================= */
    /* Breaking News: 4-Column Banner Lead */
    .mode-breaking .story-card.span-4 {
        border-bottom: 2px solid var(--border-heavy);
        padding-bottom: 1.75rem;
        margin-bottom: 0.5rem;
    }

    .mode-breaking .story-card.span-4 .headline {
        font-size: clamp(2rem, 3.5vw, 3rem);
        line-height: 1.1;
    }

    .mode-breaking .story-card.span-4 .summary {
        font-size: 1.1rem;
        max-width: 75ch;
    }

    /* Prominent News: 2-Column Lead */
    .mode-prominent .story-card.span-2 .headline {
        font-size: clamp(1.65rem, 2.5vw, 2.15rem);
        line-height: 1.15;
    }

    /* =========================================
    6. Opinion Rail & Advertisements
    ========================================= */
    .opinion-rail {
        position: relative;
        border-top: 2px solid var(--border-heavy);
        padding-top: 0.75rem;
    }

    .rail-header {
        font-family: var(--font-sans);
        font-size: 0.85rem;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        margin-bottom: 1rem;
    }

    .category-opinion .headline {
        font-style: italic;
        font-weight: 400;
        font-size: 1.2rem;
    }

    .category-advertisement {
        background-color: var(--ad-bg);
        border: 1px solid var(--border-light);
        padding: 1rem;
        text-align: center;
    }

    .ad-label {
        display: block;
        font-family: var(--font-sans);
        font-size: 0.65rem;
        letter-spacing: 0.1em;
        color: var(--ink-muted);
        margin-bottom: 0.5rem;
    }

    /* =========================================
    7. Tablet & Mobile Auto-Resizing
    ========================================= */
    /* Tablet: Collapse 4 columns into 2 columns */
    @media (max-width: 960px) {
        .broadsheet {
            padding: 1.25rem 1.5rem 3rem;
        }

        .four-column-grid {
            grid-template-columns: repeat(2, 1fr);
        }

        .span-4 {
            grid-column: span 2;
        }
    }

    /* Mobile: Collapse all columns into a single vertical stack */
    @media (max-width: 640px) {
        .broadsheet {
            padding: 1rem 1rem 2.5rem;
        }

        .four-column-grid {
            grid-template-columns: 1fr;
            gap: 1.25rem;
        }

        .span-4,
        .span-2,
        .span-1 {
            grid-column: span 1;
        }

        .mode-breaking .story-card.span-4 .headline,
        .mode-prominent .story-card.span-2 .headline {
            font-size: 1.65rem;
        }
    }

    /* =========================================
    8. Editorial Photography & Captions
    ========================================= */
    .story-figure {
        margin-bottom: 0.75rem;
    }

    .story-image {
        width: 100%;
        height: auto;
        display: block;
        object-fit: cover;
        aspect-ratio: 16 / 10;
        background-color: #f0f0f0;
    }

    /* Give Breaking News 4-column lead photos a dramatic wide cinema crop */
    .mode-breaking .story-card.span-4 .story-image {
        aspect-ratio: 21 / 9;
        max-height: 480px;
    }

    .image-caption {
        font-family: var(--font-sans);
        font-size: 0.78rem;
        line-height: 1.35;
        color: var(--ink-secondary);
        margin-top: 0.45rem;
    }

    .image-credit {
        font-size: 0.7rem;
        color: var(--ink-muted);
        letter-spacing: 0.02em;
    }

    /* =========================================
    9. Exact Column Reservations (1-2 News, 3 Rail, 4 Ads)
    ========================================= */

    /* Columns 1 & 2: News & Background only */
    .news-columns {
        grid-column: 1 / 3;
        display: grid;
        grid-template-columns: repeat(2, 1fr);
        grid-auto-flow: dense;
        gap: 1.5rem;
        align-items: start;
    }

    /* Column 3: Reserved full-height for Opinion, Agenda & Quoted */
    .opinion-rail {
        grid-column: 3;
        align-self: stretch;
        border-top: 2px solid var(--border-heavy);
        padding-top: 0.75rem;
    }

    /* Column 4: Reserved full-height for Advertisements */
    .ad-rail-full-height {
        grid-column: 4;
        align-self: stretch;
        border-left: 1px solid var(--border-light);
        padding-left: 1.25rem;
        display: flex;
        flex-direction: column;
        gap: 1.5rem;
    }

    .ad-rail-full-height .category-advertisement {
        flex: 1;
        display: flex;
        flex-direction: column;
        justify-content: center;
    }

    /* Image Display Styles (Keep these so thumbnails & hidden images still work) */
    .image-hidden .story-figure {
        display: none;
    }

    .image-thumbnail .story-figure {
        float: right;
        width: 88px;
        height: 88px;
        margin: 0 0 0.5rem 0.75rem;
    }

    .image-thumbnail .story-image {
        aspect-ratio: 1 / 1;
    }

    /* Tablet & Mobile Responsive Overrides */
    @media (max-width: 960px) {
        .news-columns {
            grid-column: 1 / -1;
            grid-template-columns: repeat(2, 1fr);
        }

        .opinion-rail,
        .ad-rail-full-height {
            grid-column: 1 / -1;
            border-left: none;
            padding-left: 0;
        }
    }

    @media (max-width: 640px) {
        .news-columns {
            grid-template-columns: 1fr;
        }
    }


    /* =========================================
    10. Agenda & Quoted Rail Sections
    ========================================= */
    .rail-section + .rail-section {
        margin-top: 1.5rem;
        padding-top: 1rem;
        border-top: 2px solid var(--border-heavy);
    }

    /* Agenda Items */
    .agenda-item {
        padding-bottom: 0.85rem;
        margin-bottom: 0.85rem;
        border-bottom: 1px solid var(--border-light);
    }

    .agenda-place {
        display: block;
        font-family: var(--font-sans);
        font-size: 0.68rem;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        color: var(--ink-muted);
        margin-bottom: 0.2rem;
    }

    .agenda-subject {
        font-family: var(--font-serif);
        font-size: 1rem;
        font-weight: 700;
        line-height: 1.25;
        margin-bottom: 0.3rem;
    }

    .agenda-subject a {
        color: var(--ink-primary);
        text-decoration: none;
    }

    .agenda-subject a:hover {
        text-decoration: underline;
    }

    .agenda-summary {
        font-size: 0.88rem;
        color: var(--ink-secondary);
        line-height: 1.4;
    }

    /* Show More Toggle */
    .show-more-toggle {
        font-family: var(--font-sans);
        font-size: 0.75rem;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        color: var(--ink-primary);
        cursor: pointer;
        list-style: none;
        padding: 0.35rem 0;
    }

    .show-more-toggle::-webkit-details-marker {
        display: none;
    }

    .show-more-toggle::after {
        content: " +";
    }

    details[open] .show-more-toggle::after {
        content: " −";
    }

    .agenda-overflow-list {
        margin-top: 0.75rem;
    }

    /* Quoted Section */
    .quote-card {
        padding-bottom: 0.9rem;
        margin-bottom: 0.9rem;
        border-bottom: 1px solid var(--border-light);
    }

    .quote-trigger {
        cursor: pointer;
        list-style: none;
    }

    .quote-trigger::-webkit-details-marker {
        display: none;
    }

    .quote-text {
        font-family: var(--font-serif);
        font-style: italic;
        font-size: 1.05rem;
        line-height: 1.35;
        color: var(--ink-primary);
        margin-bottom: 0.35rem;
    }

    .quote-trigger:hover .quote-text {
        color: var(--ink-secondary);
    }

    .quote-speaker {
        display: block;
        font-family: var(--font-sans);
        font-size: 0.72rem;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.04em;
        color: var(--ink-muted);
    }

    .quote-details {
        margin-top: 0.65rem;
        padding: 0.65rem 0.75rem;
        background-color: var(--ad-bg);
        border-left: 2px solid var(--border-heavy);
    }

    .quote-context {
        font-size: 0.85rem;
        color: var(--ink-secondary);
        margin-bottom: 0.45rem;
    }

    .quote-source-link {
        font-family: var(--font-sans);
        font-size: 0.72rem;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.04em;
        color: var(--ink-primary);
        text-decoration: none;
    }

    .quote-source-link:hover {
        text-decoration: underline;
    }

    /* =========================================
   11. Masthead Edition Bar & Section Navigation
   ========================================= */
    .nyt-masthead {
        text-align: center;
        padding-bottom: 0;
        margin-bottom: 1.5rem;
        border-bottom: 4px double var(--border-heavy);
    }

    .paper-subtitle {
        font-family: var(--font-serif);
        font-size: clamp(0.95rem, 1.5vw, 1.15rem);
        font-weight: 700;
        font-style: italic;
        color: var(--ink-secondary);
        margin-top: 0.35rem;
        letter-spacing: 0.01em;
    }

    .masthead-meta {
        display: flex;
        justify-content: space-between;
        align-items: center;
        font-family: var(--font-sans);
        font-size: 0.72rem;
        font-weight: 600;
        letter-spacing: 0.05em;
        text-transform: uppercase;
        color: var(--ink-secondary);
        padding-bottom: 0.65rem;
        margin-bottom: 0.85rem;
        border-bottom: 1px solid var(--border-light);
    }

    .masthead-date {
        color: var(--ink-primary);
        font-weight: 700;
    }

    .paper-title a {
        color: var(--ink-primary);
        text-decoration: none;
    }

    .section-nav {
        display: flex;
        justify-content: center;
        flex-wrap: wrap;
        gap: 1.5rem;
        margin-top: 1rem;
        padding: 0.6rem 0;
        border-top: 1px solid var(--border-light);
    }

    .nav-link {
        font-family: var(--font-sans);
        font-size: 0.78rem;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        color: var(--ink-secondary);
        text-decoration: none;
        padding-bottom: 0.2rem;
    }

    .nav-link:hover,
    .nav-link.active {
        color: var(--ink-primary);
        border-bottom: 2px solid var(--border-heavy);
    }

    /* =========================================
    12. Section Archive Page Layout
    ========================================= */
    .section-banner {
        border-bottom: 2px solid var(--border-heavy);
        padding-bottom: 0.5rem;
        margin-bottom: 1.5rem;
    }

    .section-heading {
        font-family: var(--font-serif);
        font-size: 2rem;
        font-weight: 700;
        letter-spacing: -0.01em;
    }

    .section-archive-list {
        max-width: 780px;
        margin: 0 auto;
        display: flex;
        flex-direction: column;
        gap: 1.25rem;
    }

    .archive-quote-row {
        padding-bottom: 1.25rem;
        border-bottom: 1px solid var(--border-light);
    }

    @media (max-width: 640px) {
        .masthead-meta {
            flex-direction: column;
            gap: 0.25rem;
        }

        .section-nav {
            gap: 0.85rem;
        }
    }

    /* =========================================
    13. NYT Breaking News & Must Read Badges
    ========================================= */
    .badge-breaking {
        display: inline-flex;
        align-items: center;
        gap: 0.4rem;
        font-family: var(--font-sans);
        font-size: 0.7rem;
        font-weight: 800;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: #d0021b;
        margin-bottom: 0.4rem;
    }

    .live-dot {
        width: 7px;
        height: 7px;
        border-radius: 50%;
        background-color: #d0021b;
        display: inline-block;
    }

    /* Optional subtle accent border on high-priority breaking news cards */
    .category-news.priority-high:not(.span-4) {
        border-top: 2px solid #d0021b;
        padding-top: 0.65rem;
    }

    .badge-must-read {
        display: inline-block;
        font-family: var(--font-sans);
        font-size: 0.68rem;
        font-weight: 700;
        letter-spacing: 0.07em;
        text-transform: uppercase;
        color: var(--ink-primary);
        background-color: #f2f2f2;
        border-left: 3px solid var(--border-heavy);
        padding: 0.18rem 0.5rem;
        margin-bottom: 0.45rem;
    }

    /* =========================================
    14. Double Vertical Height for High-Priority News
    ========================================= */
    @media (min-width: 641px) {
        .news-columns .story-card.category-news.priority-high:not(.span-4) .headline {
            font-size: 1.65rem;
            line-height: 1.15;
        }
    }

    .summary-extended {
        margin-top: 0.75rem;
    }

    /* Responsive Overrides for Tablet & Mobile */
    @media (max-width: 960px) {
        .editorial-zone {
            grid-column: 1 / -1;
            grid-template-columns: repeat(2, 1fr);
        }

        .opinion-rail,
        .ad-rail-full-height {
            grid-column: 1 / -1;
            border-left: none;
            padding-left: 0;
        }
    }

    @media (max-width: 640px) {
        .editorial-zone {
            grid-template-columns: 1fr;
        }
    }

    @media print {
        body {
            background: #ffffff;
        }

        .broadsheet {
            max-width: 100%;
            padding: 0;
        }

        .story-card,
        .opinion-rail,
        .ad-rail-full-height {
            break-inside: avoid;
        }
    }
"""
}

