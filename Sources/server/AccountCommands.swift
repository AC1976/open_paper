import Foundation
import OpenPaperKit

///     swift run server add-editor you@example.com
///     swift run server set-password you@example.com
///     swift run server remove-editor you@example.com
///     swift run server list-editors
///
/// Passwords are typed at a prompt (not shown), so they never end up in the
/// shell history. When input is piped, one line is read instead.
func runAccountCommand(_ arguments: [String], database: PaperDatabase) -> Int32 {
    let usage = """
    usage: swift run server                              run the paper
           swift run server add-editor <email>           create an editor account
           swift run server set-password <email>         change a password
           swift run server remove-editor <email>        delete an account
           swift run server list-editors
    """
    do {
        switch (arguments.first, arguments.count) {
        case ("add-editor", 2):
            guard let password = askForPassword() else { return 1 }
            let editor = try database.addEditor(email: arguments[1], password: password)
            print("Created editor \(editor.email).")
        case ("set-password", 2):
            guard let password = askForPassword() else { return 1 }
            try database.setPassword(email: arguments[1], password: password)
            print("Password changed. Existing sessions are signed out.")
        case ("remove-editor", 2):
            try database.removeEditor(email: arguments[1])
            print("Removed \(arguments[1]).")
        case ("list-editors", 1):
            let editors = try database.editors()
            if editors.isEmpty { print("No editor accounts yet.") }
            for editor in editors { print(editor.email) }
        default:
            print(usage)
            return 64
        }
        return 0
    } catch {
        print("Error: \(error)")
        return 1
    }
}

private func askForPassword() -> String? {
    guard isatty(STDIN_FILENO) != 0 else { return readLine() }
    func prompt(_ text: String) -> String? {
        var buffer = [CChar](repeating: 0, count: 256)
        guard readpassphrase(text, &buffer, buffer.count, 0) != nil else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
    guard let first = prompt("Password: "), let second = prompt("Password again: ") else { return nil }
    guard first == second else {
        print("The passwords are not the same.")
        return nil
    }
    return first
}
