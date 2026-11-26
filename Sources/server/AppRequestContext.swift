import Hummingbird
import NIOCore

/// Hummingbird's usual request context, plus the address the request came from.
struct AppRequestContext: RequestContext {
    var coreContext: CoreRequestContextStorage
    let remoteAddress: String?

    init(source: ApplicationRequestContextSource) {
        coreContext = .init(source: source)
        remoteAddress = source.channel.remoteAddress?.ipAddress
    }
}
