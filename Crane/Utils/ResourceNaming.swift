import Foundation

enum ResourceNaming {
    /// Conservative Docker-style id: alphanumeric ends; middle may use `.`, `_`, `-`; max 254 characters.
    static func isValidResourceName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 254 else { return false }
        if name.count == 1 {
            return name.range(of: #"^[a-zA-Z0-9]$"#, options: .regularExpression) != nil
        }
        let pattern = #"^[a-zA-Z0-9][a-zA-Z0-9_.-]*[a-zA-Z0-9]$"#
        return name.range(of: pattern, options: .regularExpression) != nil
    }
}
