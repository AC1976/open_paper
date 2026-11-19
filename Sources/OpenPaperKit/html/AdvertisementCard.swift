import Elementary

package struct AdvertisementCard: HTML {
    package let ad: Advertisement

    package var body: some HTML {
        aside(.class("story-card category-advertisement")) {
            span(.class("ad-label")) { "ADVERTISEMENT" }

            a(.href(ad.targetURL), .target(.blank), .rel("noopener sponsored"), .class("ad-image-link")) {
                img(
                    .src(ad.imageSource.htmlSrc),
                    .alt(ad.altText),
                    .class("ad-graphic")
                )
            }
        }
    }
}

