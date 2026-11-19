import Foundation
import Elementary

func makeSampleStories() -> [Story] {
    let now = Date()

    return [
        // 1. High-Priority News (Becomes the Lead Story)
        Story(
            id: UUID(),
            category: .news,
            priority: .high,
            title: "Global Summit Reaches Historic Accord on Clean Energy Grid",
            summary: "Negotiators from 140 nations finalized a binding framework early Wednesday morning to modernize cross-border power transmission and phase out coal subsidies by 2035.",
            extendedSummary: "Under the terms of the agreement, wealthier industrial economies committed $120 billion annually in grid-interconnection financing, while coastal nations agreed to fast-track subsea cable permitting across shared maritime zones.",
            slug: "global-summit-historic-accord-clean-energy-grid",
            publishedAt: now.addingTimeInterval(-3600),
            updatedAt: now.addingTimeInterval(-1800),
            author: "Elena Vance and Marcus Sterling",
            image: StoryImage(
                source: .endpoint(url: "https://unsplash.com"),
                altText: "High-voltage power lines at sunset",
                caption: "Delegates worked through the night to finalize transmission targets.",
                credit: "Photo by Studio Archive"
            )
        ),

        // 2. High-Priority Background / Analysis (Gets a standard lead photo)
        Story(
            id: UUID(),
            category: .background,
            priority: .normal,
            title: "Why Semiconductor Supply Chains Are Shifting Toward Regional Hubs",
            summary: "After years of relying on single-source manufacturing, major chipmakers are investing billions in localized fabrication plants across Europe and North America.",
            slug: "semiconductor-supply-chains-regional-hubs",
            publishedAt: now.addingTimeInterval(-7200),
            updatedAt: nil,
            author: "David Chen",
            image: StoryImage(
                source: .endpoint(url: "https://unsplash.com"),
                altText: "Close-up of a silicon circuit board",
                caption: "Next-generation wafers require specialized cleanroom facilities.",
                credit: "Tech Desk"
            )
        ),

        // 3. Normal-Priority News (Gets a compact thumbnail)
        Story(
            id: UUID(),
            category: .news,
            priority: .normal,
            title: "Port of Rotterdam Unveils Automated Hydrogen Cargo Terminal",
            summary: "The new facility aims to cut maritime refueling turnaround times in half while serving zero-emission container vessels.",
            slug: "port-of-rotterdam-automated-hydrogen-terminal",
            publishedAt: now.addingTimeInterval(-10800),
            updatedAt: nil,
            author: "Sander de Vries",
            image: StoryImage(
                source: .endpoint(url: "https://unsplash.com"),
                altText: "Container cranes at a port",
                caption: nil,
                credit: nil
            )
        ),

        // 4. Normal-Priority News without Image (Renders cleanly as text-only)
        Story(
            id: UUID(),
            category: .news,
            priority: .normal,
            title: "Central Bank Signals Steady Interest Rates Through Spring",
            summary: "Policymakers noted that cooling service inflation gives the committee room to observe wage growth before making further adjustments.",
            slug: "central-bank-steady-interest-rates-spring",
            publishedAt: now.addingTimeInterval(-14400),
            updatedAt: nil,
            author: "Clara Lindqvist",
            image: nil
        ),

        // 5. Opinion Pieces (Pinned to Column 3 Opinion Rail)
        Story(
            id: UUID(),
            category: .opinion,
            priority: .high,
            title: "The Quiet Return of Slow Urbanism",
            summary: "Cities thrive not when we optimize every street for speed, but when we design neighborhoods worth lingering in.",
            slug: "quiet-return-of-slow-urbanism",
            publishedAt: now.addingTimeInterval(-18000),
            updatedAt: nil,
            author: "Julian Mercer",
            image: nil
        ),
        
        Story(
            id: UUID(),
            category: .opinion,
            priority: .normal,
            title: "Public Libraries Are Our Last Great Civic Living Rooms",
            summary: "In an era of subscription everything, free access to books, warmth, and quiet study remains radical.",
            slug: "public-libraries-civic-living-rooms",
            publishedAt: now.addingTimeInterval(-21600),
            updatedAt: nil,
            author: "Nadia Al-Mansoor",
            image: nil
        ),


        // Add these 8 stories inside your makeSampleStories() return array:

        // 7. High-Priority News with Photo (Tests top-row / high-priority photo placement)
        Story(
            id: UUID(),
            category: .news,
            priority: .high,
            title: "European Rail Operators Launch Overnight High-Speed Sleeper Network",
            summary: "New rolling stock connecting Amsterdam, Zurich, and Barcelona aims to replace short-haul flights along key continental corridors.",
            slug: "european-rail-overnight-high-speed-sleeper-network",
            publishedAt: now.addingTimeInterval(-5400),
            updatedAt: nil,
            author: "Anouk Vermeer",
        ),

        // 8. High-Priority Background with Photo (Tests secondary high-priority card)
        Story(
            id: UUID(),
            category: .background,
            priority: .high,
            title: "Inside the Race to Build Grid-Scale Iron-Air Batteries",
            summary: "Unlike lithium-ion cells built for rapid discharge, rust-based storage systems promise 100-hour backup power at a fraction of the cost.",
            slug: "race-to-build-grid-scale-iron-air-batteries",
            publishedAt: now.addingTimeInterval(-9000),
            updatedAt: now.addingTimeInterval(-4000),
            author: "Thomas Lindholm",
            image: StoryImage(
                source: .endpoint(url: "https://unsplash.com"),
                altText: "Industrial energy storage facility",
                caption: "Pilot installations are underway next to retired coal plants.",
                credit: "Energy Desk"
            )
        ),

        // 9. Normal-Priority News with Photo (Tests thumbnail vs hidden cutoff)
        Story(
            id: UUID(),
            category: .news,
            priority: .normal,
            title: "Municipal Museums See Record Attendance After Free-Entry Trial",
            summary: "Curators reported a 42 percent surge in first-time visitors under age 30 during the six-month cultural access program.",
            slug: "municipal-museums-record-attendance-free-entry",
            publishedAt: now.addingTimeInterval(-12600),
            updatedAt: nil,
            author: "Sofia Rossi",
            image: StoryImage(
                source: .endpoint(url: "https://unsplash.com"),
                altText: "Visitors inside a sunlit art gallery",
                caption: nil,
                credit: nil
            )
        ),

        // 10. Normal-Priority Background without Photo (Tests dense text-only newsprint flow)
        Story(
            id: UUID(),
            category: .background,
            priority: .normal,
            title: "How Medieval Water Boards Still Shape Modern Dutch Flood Defense",
            summary: "Centuries-old regional water authorities operate independently of national politics to manage dikes, polders, and rising sea levels.",
            slug: "medieval-water-boards-modern-dutch-flood-defense",
            publishedAt: now.addingTimeInterval(-16200),
            updatedAt: nil,
            author: "Willem van Dijk",
            image: nil
        ),

        // 11. Normal-Priority News without Photo (Tests lower-page stacking)
        Story(
            id: UUID(),
            category: .news,
            priority: .normal,
            title: "North Atlantic Cod Populations Show Early Signs of Recovery",
            summary: "Marine biologists attribute the rebound to stricter seasonal trawling closures and cooler sub-surface ocean currents.",
            slug: "north-atlantic-cod-populations-early-recovery",
            publishedAt: now.addingTimeInterval(-19800),
            updatedAt: nil,
            author: "Freja Lind",
            image: nil
        ),

        // 12. Normal-Priority News without Photo (Tests multi-row broadsheet balance)
        Story(
            id: UUID(),
            category: .news,
            priority: .normal,
            title: "Independent Bookshops Outpace Chain Stores in Urban Neighborhoods",
            summary: "Curated local events and community subscriptions have helped small booksellers thrive despite rising commercial rents.",
            slug: "independent-bookshops-outpace-chain-stores",
            publishedAt: now.addingTimeInterval(-23400),
            updatedAt: nil,
            author: "Hannah Abbott",
            image: nil
        ),

        // 13. High-Priority Opinion (Tests priority sorting inside the Column 3 Opinion rail)
        Story(
            id: UUID(),
            category: .opinion,
            priority: .high,
            title: "Why Europe Needs Its Own Sovereign Cloud Infrastructure",
            summary: "Digital autonomy is no longer an abstract policy debate; it is the foundation of modern industrial resilience.",
            slug: "why-europe-needs-sovereign-cloud-infrastructure",
            publishedAt: now.addingTimeInterval(-6000),
            updatedAt: nil,
            author: "Dr. Pieter Bakker",
            image: nil
        )
   
   ]
}

func makeSampleAgendaPoints() -> [AgendaPoint] {
    [
        AgendaPoint(
            subject: "European Central Bank Rate Decision",
            place: "Frankfurt, Germany",
            link: "https://example.com",
            summary: "Governing Council convenes to review Q4 inflation projections and benchmark lending rates."
        ),
        AgendaPoint(
            subject: "North Sea Offshore Wind Summit",
            place: "Rotterdam, Netherlands",
            link: "https://example.com",
            summary: "Energy ministers sign cross-border grid interconnection agreements for 2030 capacity targets."
        ),
        AgendaPoint(
            subject: "Annual Architecture Biennale Opening",
            place: "Venice, Italy",
            link: "https://example.com",
            summary: "National pavilions showcase adaptive reuse and low-carbon timber construction."
        ),
        AgendaPoint(
            subject: "Global Maritime Decarbonization Forum",
            place: "Singapore",
            link: "https://example.com",
            summary: "Shipping lines and port authorities announce green methanol bunkering corridors."
        )
    ]
}

func makeSampleQuotedItems() -> [QuotedItem] {
    [
        QuotedItem(
            quote: "We cannot regulate tomorrow’s energy grid with yesterday’s transmission maps.",
            speaker: "Dr. Hendrik Lindeman, Grid Infrastructure Envoy",
            context: "Spoken during the closing keynote of the European Energy Transition Plenary in Brussels.",
            sourceLink: "https://example.com"
        ),
        QuotedItem(
            quote: "A great newspaper is a nation talking to itself—even when the conversation is uncomfortable.",
            speaker: "Arthur Miller",
            context: "Often cited in editorial roundtables examining the role of independent public-interest journalism.",
            sourceLink: "https://example.com"
        )
    ]
}


func makeSampleAdvertisements() -> [Advertisement] {
    [
        Advertisement(
            sponsorName: "Vacheron & Co.",
            imageSource: .endpoint(url: "https://unsplash.com"),
            altText: "The Chronometer Heritage Series — Vacheron & Co.",
            targetURL: "https://example.com",
            priority: .high
        ),
        Advertisement(
            sponsorName: "NAi Booksellers",
            imageSource: .endpoint(url: "https://unsplash.com"),
            altText: "The Rotterdam Architectural Press — Autumn Catalogue",
            targetURL: "https://example.com",
            priority: .normal
        )
    ]
}

