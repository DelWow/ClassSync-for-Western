import Foundation

enum AssignmentURLValidator {
    static func validatedURL(for assignment: Assignment) -> URL? {
        guard let url = assignment.url else { return nil }
        return validatedURL(url, source: assignment.source)
    }

    static func validatedURL(_ url: URL, source: AssignmentSource) -> URL? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == "https",
            components.user == nil,
            components.password == nil,
            let host = components.host?.lowercased(),
            isAllowed(host: host, source: source)
        else {
            return nil
        }
        return components.url
    }

    private static func isAllowed(host: String, source: AssignmentSource) -> Bool {
        switch source {
        case .brightspace:
            return host == "brightspace.com" || host.hasSuffix(".brightspace.com")
        case .gradescope:
            return host == "gradescope.com" || host.hasSuffix(".gradescope.com")
        case .crowdmark:
            return host == "crowdmark.com" || host.hasSuffix(".crowdmark.com")
        case .manual:
            return true
        }
    }
}
