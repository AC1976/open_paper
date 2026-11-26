import Elementary
import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdElementary
import OpenPaperKit

private let sessionCookie = "editor_session"

/// Refuses state-changing requests that come from another site (CSRF).
struct SameOriginOnly: RouterMiddleware {
    func handle(
        _ request: Request,
        context: AppRequestContext,
        next: (Request, AppRequestContext) async throws -> Response
    ) async throws -> Response {
        if request.method != .get && request.method != .head {
            let allowed = RequestChecks.isSameOrigin(
                secFetchSite: HTTPField.Name("Sec-Fetch-Site").flatMap { request.headers[$0] },
                origin: HTTPField.Name("Origin").flatMap { request.headers[$0] },
                host: request.head.authority
            )
            guard allowed else {
                throw HTTPError(.forbidden, message: "This request did not come from the editor's own pages.")
            }
        }
        var response = try await next(request, context)
        // Editor pages must not be framed by other sites or kept in caches.
        if let frameOptions = HTTPField.Name("X-Frame-Options") { response.headers[frameOptions] = "DENY" }
        response.headers[.cacheControl] = "no-store"
        return response
    }
}

/// Lets only signed-in editors through. Page requests are sent to the login
/// page; anything else gets 401.
struct SignedInOnly: RouterMiddleware {
    let database: PaperDatabase

    func handle(
        _ request: Request,
        context: AppRequestContext,
        next: (Request, AppRequestContext) async throws -> Response
    ) async throws -> Response {
        if let token = request.cookies[sessionCookie]?.value, try database.editor(forSession: token) != nil {
            return try await next(request, context)
        }
        guard request.method == .get else {
            throw HTTPError(.unauthorized, message: "Log in to the editor first.")
        }
        let destination = RequestChecks.safeDestination(request.uri.path)
        let encoded = destination.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return .redirect(to: "/editor/login?next=\(encoded)")
    }
}

///     GET  /editor/login    the form
///     POST /editor/login    sign in
///     POST /editor/logout   sign out
///
/// `secureCookie` must be true whenever the editor is reached over HTTPS.
func addLoginRoutes(
    to router: some RouterMethods<AppRequestContext>,
    database: PaperDatabase,
    secureCookie: Bool
) {
    let throttle = LoginThrottle()

    @Sendable func loginPage(
        _ page: LoginPage, _ request: Request, _ context: AppRequestContext, status: HTTPResponse.Status = .ok
    ) -> Response {
        HTMLResponse(status: status) { page }.response(from: request, context: context)
    }

    router.get("/editor/login") { request, context -> Response in
        let next = request.uri.queryParameters["next"].map(String.init)?.removingPercentEncoding
        let page = LoginPage(
            next: RequestChecks.safeDestination(next),
            hasEditors: try !database.editors().isEmpty
        )
        return loginPage(page, request, context)
    }

    router.post("/editor/login") { request, context -> Response in
        let form = try await readForm(request)
        let email = form.text("email") ?? ""
        let password = form.rawText("password") ?? ""
        let next = RequestChecks.safeDestination(form.text("next"))

        func refuse(_ problem: String, status: HTTPResponse.Status) -> Response {
            loginPage(LoginPage(next: next, email: email, problem: problem), request, context, status: status)
        }

        guard await throttle.attempt(email) else {
            return refuse("Too many attempts. Wait 15 minutes and try again.", status: .tooManyRequests)
        }
        guard let editor = try database.authenticate(email: email, password: password) else {
            return refuse("The email address or password is not right.", status: .unauthorized)
        }
        await throttle.succeeded(email)

        var response = Response.redirect(to: next)
        response.setCookie(Cookie(
            name: sessionCookie,
            value: try database.startSession(for: editor),
            maxAge: Int(PaperDatabase.sessionLifetime),
            path: "/",
            secure: secureCookie,
            httpOnly: true,
            sameSite: .lax
        ))
        return response
    }

    router.post("/editor/logout") { request, _ -> Response in
        if let token = request.cookies[sessionCookie]?.value { try database.endSession(token) }
        var response = Response.redirect(to: "/editor/login")
        response.setCookie(Cookie(
            name: sessionCookie, value: "", maxAge: 0, path: "/",
            secure: secureCookie, httpOnly: true, sameSite: .lax
        ))
        return response
    }
}
