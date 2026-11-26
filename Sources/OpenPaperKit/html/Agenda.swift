import Foundation
import Elementary

package struct AgendaItemRow: HTML {
    package let point: AgendaPoint

    package var body: some HTML {
        div(.class("agenda-item")) {
            span(.class("agenda-place")) { point.place }
            h4(.class("agenda-subject")) {
                a(.href(point.link)) { point.subject }
            }
            p(.class("agenda-summary")) { point.summary }
        }
    }
}

package struct AgendaSection: HTML {
    package let points: [AgendaPoint]

    package var body: some HTML {
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
                        "Nog \(overflowPoints.count) tonen"
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

