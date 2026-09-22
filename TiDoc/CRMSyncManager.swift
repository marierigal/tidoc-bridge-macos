//
//  CRMSyncManager.swift
//  TiDoc
//
//  Created by Marie Rigal on 21/09/2026.
//


import WebKit

// MARK: - Model

enum CRMTab: String, CaseIterable {
    case client = "clients"
    case prospect = "prospects"
    case supplier = "suppliers"

    /// Suggested file name for the local export
    var fileName: String {
        switch self {
        case .client: return "clients.csv"
        case .prospect: return "prospects.csv"
        case .supplier: return "suppliers.csv"
        }
    }
}

enum CRMSyncError: LocalizedError {
    case loadingFailed(Error)
    case tabNotActive(CRMTab)
    case exportFailed(CRMTab)
    case downloadFailed(CRMTab)
    case timeout(String)
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .loadingFailed(let err):
            return "Le chargement de la page CRM a échoué : \(err.localizedDescription)"
        case .tabNotActive(let tab):
            return "Impossible d'activer l'onglet \(tab.rawValue)."
        case .exportFailed(let tab):
            return "L'export pour l'onglet \(tab.rawValue) a échoué."
        case .downloadFailed(let tab):
            return "Le téléchargement du fichier pour \(tab.rawValue) a échoué."
        case .timeout(let context):
            return "Délai dépassé : \(context)"
        case .sessionExpired:
            return "La session n'est plus valide, une reconnexion manuelle est nécessaire."
        }
    }
}

/// Result of the synchronization for a given category.
/// `url` is nil if the category had no records (no Export button present).
struct SyncCategoryResult {
    let tab: CRMTab
    let url: URL?
}

// MARK: - CRMSyncManager

@MainActor
final class CRMSyncManager: NSObject {

    private let dashboardURL = URL(string: "https://app.inter-fast.fr/dashboard/crm")!
    private let destinationFolder: URL

    /// URL fragment identifying the login page. Adjust to match the real URL
    /// (e.g. "/login", "/auth/signin"...).
    private let loginPagePattern = "/login"

    private var webView: WKWebView!

    // Page loading
    private var navigationContinuation: CheckedContinuation<Void, Error>?

    // Ongoing download
    private var downloadContinuation: CheckedContinuation<URL, Error>?
    private var downloadDestinationURL: URL?

    // Login window is created once and reused — recreating an NSWindow on
    // every call while reassigning the same WKWebView as its contentView
    // causes a memory crash (over-release) when the previous window closes.
    private var loginWindowCache: NSWindow?

    init(destinationFolder: URL) {
        self.destinationFolder = destinationFolder
        super.init()

        // WKWebsiteDataStore.default() automatically persists cookies across
        // app launches: no need to manage the session ourselves.
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
    }

    // MARK: Public API

    /// Shows the webview in a visible window, for an initial manual login.
    func loginWindow() -> NSWindow {
        if let existingWindow = loginWindowCache {
            webView.load(URLRequest(url: dashboardURL))
            return existingWindow
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Connexion à l'application CRM"
        window.contentView = webView
        window.isReleasedWhenClosed = false // extra safety, even while cached
        webView.load(URLRequest(url: dashboardURL))

        loginWindowCache = window
        return window
    }

    /// Clears the CRM session data (cookies), forcing a manual reconnection
    /// on the next access.
    func logOut() async {
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()

        let records = await dataStore.dataRecords(ofTypes: types)
        let crmRecords = records.filter { $0.displayName.contains("inter-fast.fr") }

        await dataStore.removeData(ofTypes: types, for: crmRecords)
    }

    /// Runs the synchronization for the requested categories, sequentially
    /// (a single WKWebView, tab navigation without reload).
    func synchronize(
        categories: [CRMTab] = CRMTab.allCases
    ) async throws -> [SyncCategoryResult] {

        try await loadInitialPage()

        var results: [SyncCategoryResult] = []

        for tab in categories {
            try await activateTab(tab)

            guard try await exportButtonAvailable() else {
                results.append(SyncCategoryResult(tab: tab, url: nil))
                continue
            }

            try await startExport(for: tab)
            // The most recent job is always inserted at the head of the list
            // (index 0), regardless of how many jobs are already present.
            let file = try await retrieveDownload(for: tab, rowIndex: 0)
            results.append(SyncCategoryResult(tab: tab, url: file))
        }

        return results
    }

    // MARK: Page loading

    /// Loads the CRM dashboard and checks we weren't redirected to the login
    /// page (expired session). If so, throws `.sessionExpired` rather than
    /// continuing to click on elements that don't exist on that page.
    private func loadInitialPage() async throws {
        try await navigate(to: dashboardURL)

        if let url = webView.url, url.absoluteString.contains(loginPagePattern) {
            throw CRMSyncError.sessionExpired
        }
    }

    private func navigate(to url: URL) async throws {
        // If a previous navigation is still pending (e.g. a redundant load
        // request to a URL that's already loading), resolve it explicitly
        // instead of risking leaving it dangling — which would crash with a
        // "leaked continuation" error.
        navigationContinuation?.resume(throwing: CRMSyncError.timeout("navigation supplantée par une nouvelle demande"))
        navigationContinuation = nil

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.navigationContinuation = continuation
            webView.load(URLRequest(url: url))
        }
    }

    /// To be used after showing `loginWindow()`: waits until the user
    /// manually leaves the login page (credentials entered successfully),
    /// then forces navigation to the CRM dashboard (the site doesn't do it
    /// automatically).
    func waitForLoginThenLoadDashboard(timeout: TimeInterval = 300) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        // 1. Wait until we're no longer on the login page, with a short
        //    stabilization delay to avoid reacting to a transient redirect.
        while Date() < deadline {
            if let url = webView.url, !url.absoluteString.contains(loginPagePattern) {
                try await Task.sleep(nanoseconds: 1_000_000_000)  // 1s stabilization
                if let confirmedURL = webView.url, !confirmedURL.absoluteString.contains(loginPagePattern) {
                    break
                }
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        guard let url = webView.url, !url.absoluteString.contains(loginPagePattern) else {
           throw CRMSyncError.timeout("connexion manuelle non détectée dans le délai imparti")
        }

        // 2. The site doesn't redirect to /dashboard/crm after login: we do it ourselves.
        try await loadInitialPage()
    }

    // MARK: Tab navigation (no reload, since the app is a SPA)

    private func activateTab(_ tab: CRMTab) async throws {
        let jsClick = "document.getElementById('flex-tabs-tab-\(tab.rawValue)')?.click();"
        _ = try? await webView.evaluateJavaScript(jsClick)

        let deadline = Date().addingTimeInterval(5)
        let jsCheck = "document.getElementById('flex-tabs-tab-\(tab.rawValue)')?.getAttribute('aria-selected') === 'true'"

        while Date() < deadline {
            if let active = try? await webView.evaluateJavaScript(jsCheck) as? Bool, active {
                // Short stabilization delay: gives the tab's content time to
                // finish loading after the switch
                try await Task.sleep(nanoseconds: 400_000_000)
                return
            }
            try await Task.sleep(nanoseconds: 150_000_000)
        }
        throw CRMSyncError.tabNotActive(tab)
    }

    // MARK: Export button detection (absent if the category is empty)

    /// The tab's content (list + Export button) may load a bit after the tab
    /// becomes active (aria-selected), especially if there's data to fetch
    /// from the server. We therefore poll over a short window rather than
    /// checking only once, to avoid wrongly concluding the category is empty.
    private func exportButtonAvailable(timeoutSeconds: TimeInterval = 5) async throws -> Bool {
        let js = """
        (() => {
            const btn = Array.from(document.querySelectorAll('button'))
                .find(b => b.textContent.trim() === 'Exporter');
            return !!btn;
        })()
        """

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if let present = try? await webView.evaluateJavaScript(js) as? Bool, present {
                return true
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        return false
    }

    // MARK: Starting the export + tracking the row in the jobs modal

    /// Clicks "Exporter" and waits for a new row to appear in the modal
    /// (`.modal-body > div > div`). New jobs are inserted at the head of the
    /// list (index 0): we therefore never target by a computed position,
    /// only after confirming one more row is present before reading index 0.
    private func startExport(for tab: CRMTab) async throws {
        let countBefore = try await countModalRows()

        let jsClick = """
        (() => {
            const btn = Array.from(document.querySelectorAll('button'))
                .find(b => b.textContent.trim() === 'Exporter');
            if (btn) { btn.click(); return true; }
            return false;
        })()
        """
        let clicked = try await webView.evaluateJavaScript(jsClick) as? Bool ?? false
        guard clicked else { throw CRMSyncError.exportFailed(tab) }

        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            let count = try await countModalRows()
            if count >= countBefore + 1 { return }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        throw CRMSyncError.timeout("nouvelle ligne de traitement non détectée pour \(tab.rawValue)")
    }

    private func countModalRows() async throws -> Int {
        let js = "document.querySelectorAll('.modal-body > div > div').length"
        let result = try await webView.evaluateJavaScript(js) as? Int
        return result ?? 0
    }

    // MARK: Waiting for job completion + download

    private func retrieveDownload(for tab: CRMTab, rowIndex: Int) async throws -> URL {
        // Wait for the "Télécharger" button to appear in the targeted row
        // (the loader is replaced by this button once the server job is done).
        let deadline = Date().addingTimeInterval(120)
        let jsButtonPresence = """
        (() => {
            const rows = document.querySelectorAll('.modal-body > div > div');
            const row = rows[\(rowIndex)];
            if (!row) return false;
            const btn = Array.from(row.querySelectorAll('button'))
                .find(b => b.textContent.trim() === 'Télécharger');
            return !!btn;
        })()
        """

        var ready = false
        while Date() < deadline {
            if let ok = try? await webView.evaluateJavaScript(jsButtonPresence) as? Bool, ok {
                ready = true
                break
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        guard ready else { throw CRMSyncError.timeout("job d'export non terminé pour \(tab.rawValue)") }

        let destination = destinationFolder.appendingPathComponent(tab.fileName)
        downloadDestinationURL = destination

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            self.downloadContinuation = continuation

            let jsClickDownload = """
            (() => {
                const rows = document.querySelectorAll('.modal-body > div > div');
                const row = rows[\(rowIndex)];
                if (!row) return false;
                const btn = Array.from(row.querySelectorAll('button'))
                    .find(b => b.textContent.trim() === 'Télécharger');
                if (btn) { btn.click(); return true; }
                return false;
            })()
            """
            Task {
                let clicked = try? await self.webView.evaluateJavaScript(jsClickDownload) as? Bool
                if clicked != true {
                    self.downloadContinuation = nil
                    continuation.resume(throwing: CRMSyncError.downloadFailed(tab))
                }
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension CRMSyncManager: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationContinuation?.resume(returning: ())
        navigationContinuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationContinuation?.resume(throwing: CRMSyncError.loadingFailed(error))
        navigationContinuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navigationContinuation?.resume(throwing: CRMSyncError.loadingFailed(error))
        navigationContinuation = nil
    }

    // Clicking "Télécharger" triggers a response with Content-Disposition,
    // which WKWebView turns into a WKDownload rather than a normal navigation.
    func webView(
        _ webView: WKWebView,
        navigationAction: WKNavigationAction,
        didBecome download: WKDownload
    ) {
        download.delegate = self
    }

    func webView(
        _ webView: WKWebView,
        navigationResponse: WKNavigationResponse,
        didBecome download: WKDownload
    ) {
        download.delegate = self
    }
}

// MARK: - WKDownloadDelegate

extension CRMSyncManager: WKDownloadDelegate {

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let destination = downloadDestinationURL
            ?? destinationFolder.appendingPathComponent(suggestedFilename)

        // Remove any leftover file from a previous run, otherwise WKDownload fails.
        try? FileManager.default.removeItem(at: destination)
        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let destination = downloadDestinationURL else {
            downloadContinuation?.resume(throwing: CRMSyncError.timeout("destination de téléchargement introuvable"))
            downloadContinuation = nil
            return
        }
        downloadContinuation?.resume(returning: destination)
        downloadContinuation = nil
        downloadDestinationURL = nil
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloadContinuation?.resume(throwing: error)
        downloadContinuation = nil
        downloadDestinationURL = nil
    }
}
