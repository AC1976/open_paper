import Foundation
import Elementary

struct AgendaItemRow: HTML {
    let point: AgendaPoint

    var body: some HTML {
        div(.class("agenda-item")) {
            span(.class("agenda-place")) { point.place }
            h4(.class("agenda-subject")) {
                a(.href(point.link)) { point.subject }
            }
            p(.class("agenda-summary")) { point.summary }
        }
    }
}

struct AgendaSection: HTML {
    let points: [AgendaPoint]

    var body: some HTML {
        let initialPoints = Array(points.prefix(3))
        let overflowPoints = Array(points.dropFirst(3))

        section(.class("rail-section agenda-section")) {
            h3(.class("rail-header")) { "Agenda" }

            for point in initialPoints {
                AgendaItemRow(point: point)
            }

            if !overflowPoints.isEmpty {
                details(.class("agenda-expand")) {
                    summary(.class("show-more-toggle")) {
                        "Show \(overflowPoints.count) more"
                    }
                    div(.class("agenda-overflow-list")) {
                        for point in overflowPoints {
                            AgendaItemRow(point: point)
                        }
                    }
                }
            }
        }
    }
}

