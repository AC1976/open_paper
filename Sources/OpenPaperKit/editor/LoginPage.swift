import Elementary

/// `/editor/login`.
package struct LoginPage: HTMLDocument {
    /// The editor page to open after signing in.
    package let next: String
    package let email: String
    package let problem: String?
    /// False until the first account has been made on the command line.
    package let hasEditors: Bool

    package init(next: String = "/editor", email: String = "", problem: String? = nil, hasEditors: Bool = true) {
        self.next = next
        self.email = email
        self.problem = problem
        self.hasEditors = hasEditors
    }

    package var title: String { "Editor — Log in" }

    package var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        style { BroadsheetStyles.css }
        style { HTMLRaw(EditorStyles.css) }
    }

    package var body: some HTML {
        header(.class("editor-bar")) {
            span(.class("editor-brand")) { "Het Grootboek · Editor" }
            a(.href("/"), .class("editor-link")) { "The paper" }
        }

        main(.class("login")) {
            h1(.class("review-title")) { "Log in" }

            if !hasEditors {
                p(.class("notice")) {
                    "There is no editor account yet. Create one in Terminal with "
                    code { "swift run server add-editor you@example.com" }
                    "."
                }
            }
            if let problem {
                div(.class("problems")) { p { problem } }
            }

            form(.method(.post), .action("/editor/login"), .enctype(.multipartFormData), .class("review-form")) {
                input(.type(.hidden), .name("next"), .value(next))
                fieldset {
                    div(.class("field")) {
                        label(.for("email")) { "Email" }
                        input(.type(.email), .id("email"), .name("email"), .value(email), .required,
                              .custom(name: "autocomplete", value: "username"))
                    }
                    div(.class("field")) {
                        label(.for("password")) { "Password" }
                        input(.type(.password), .id("password"), .name("password"), .required,
                              .custom(name: "autocomplete", value: "current-password"))
                    }
                }
                div(.class("actions")) {
                    button(.type(.submit), .class("button primary")) { "Log in" }
                }
            }
        }
    }
}
