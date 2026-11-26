import Elementary

package struct AdvertisementCard: HTML {
    package let ad: Advertisement

    package var body: some HTML {
        aside(.class("story-card category-advertisement")) {
            span(.class("ad-label")) { "ADVERTISEMENT" }

            a(.href(ad.targetURL), .target(.blank), .rel("noopener sponsored"), .class("ad-image-link")) {
                img(
                    // An uploaded image has smaller versions; the ad column is narrow.
                    .src(ad.imageSource.htmlSrc.hasPrefix("/images/") ? ad.imageSource.htmlSrc + "?w=960" : ad.imageSource.htmlSrc),
                    .alt(ad.altText),
                    .class("ad-graphic"),
                    .custom(name: "loading", value: "lazy")
                )
            }
        }
    }
}

