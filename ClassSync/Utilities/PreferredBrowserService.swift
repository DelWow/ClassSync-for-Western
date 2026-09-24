import AppKit
import Foundation

enum PreferredBrowserService {
    struct Browser: Equatable, Sendable {
        let name: String
        let bundleIdentifier: String
    }

    static let browsers = [
        Browser(name: "Google Chrome", bundleIdentifier: "com.google.Chrome"),
        Browser(name: "Safari", bundleIdentifier: "com.apple.Safari")
    ]

    static func preferredBrowser(
        resolvingApplicationURL: (String) -> URL?
    ) -> Browser? {
        browsers.first { resolvingApplicationURL($0.bundleIdentifier) != nil }
    }

    @MainActor
    static func open(_ url: URL) {
        open(url, candidates: browsers[...], workspace: .shared)
    }

    @MainActor
    private static func open(
        _ url: URL,
        candidates: ArraySlice<Browser>,
        workspace: NSWorkspace
    ) {
        guard let candidate = candidates.first else {
            AppLogger.browser.error("Chrome and Safari were unavailable; using the system URL handler")
            workspace.open(url)
            return
        }

        let remaining = candidates.dropFirst()
        guard let applicationURL = workspace.urlForApplication(
            withBundleIdentifier: candidate.bundleIdentifier
        ) else {
            open(url, candidates: remaining, workspace: workspace)
            return
        }

        workspace.open(
            [url],
            withApplicationAt: applicationURL,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            guard error != nil else { return }
            Task { @MainActor in
                AppLogger.browser.error("Preferred browser could not open the URL; trying the fallback")
                open(url, candidates: remaining, workspace: .shared)
            }
        }
    }
}
