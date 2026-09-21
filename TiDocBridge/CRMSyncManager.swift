//
//  CRMSyncManager.swift
//  TiDocBridge
//
//  Created by Marie Rigal on 21/09/2026.
//


import WebKit

// MARK: - Modèle

enum CRMTab: String, CaseIterable {
    case client = "clients"
    case prospect = "prospects"
    case fournisseur = "suppliers"

    /// Nom de fichier suggéré pour l'export local
    var nomFichier: String {
        switch self {
        case .client: return "clients.csv"
        case .prospect: return "prospects.csv"
        case .fournisseur: return "fournisseurs.csv"
        }
    }
}

enum DocGenSyncError: LocalizedError {
    case chargementEchoue(Error)
    case ongletNonActif(CRMTab)
    case exportEchoue(CRMTab)
    case telechargementEchoue(CRMTab)
    case timeout(String)
    case sessionExpiree

    var errorDescription: String? {
        switch self {
        case .chargementEchoue(let err):
            return "Le chargement de la page CRM a échoué : \(err.localizedDescription)"
        case .ongletNonActif(let tab):
            return "Impossible d'activer l'onglet \(tab.rawValue)."
        case .exportEchoue(let tab):
            return "L'export pour l'onglet \(tab.rawValue) a échoué."
        case .telechargementEchoue(let tab):
            return "Le téléchargement du fichier pour \(tab.rawValue) a échoué."
        case .timeout(let contexte):
            return "Délai dépassé : \(contexte)"
        case .sessionExpiree:
            return "La session n'est plus valide, une reconnexion manuelle est nécessaire."
        }
    }
}

/// Résultat de la synchronisation pour une catégorie donnée.
/// `url` est nil si la catégorie n'avait aucun enregistrement (bouton Exporter absent).
struct ResultatSyncCategorie {
    let tab: CRMTab
    let url: URL?
}

// MARK: - CRMSyncManager

@MainActor
final class CRMSyncManager: NSObject {

    private let urlDashboard = URL(string: "https://app.inter-fast.fr/dashboard/crm")!
    private let dossierDestination: URL

    /// Fragment d'URL identifiant la page de connexion. À ajuster selon l'URL réelle
    /// (ex: "/login", "/auth/signin"...).
    private let motifPageLogin = "/login"

    private var webView: WKWebView!

    // Chargement de page
    private var navigationContinuation: CheckedContinuation<Void, Error>?

    // Téléchargement en cours
    private var downloadContinuation: CheckedContinuation<URL, Error>?
    private var downloadDestinationURL: URL?

    init(dossierDestination: URL) {
        self.dossierDestination = dossierDestination
        super.init()

        // WKWebsiteDataStore.default() persiste automatiquement les cookies
        // entre les lancements de l'app : pas besoin de gérer la session nous-même.
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
    }

    // MARK: API publique

    /// Affiche la webview dans une fenêtre visible, pour une connexion manuelle initiale.
    func fenetreDeConnexion() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Connexion à l'application CRM"
        window.contentView = webView
        webView.load(URLRequest(url: urlDashboard))
        return window
    }

    /// Lance la synchronisation des catégories demandées, dans l'ordre séquentiel
    /// (une seule WKWebView, navigation par onglets sans reload).
    func synchroniser(
        categories: [CRMTab] = CRMTab.allCases
    ) async throws -> [ResultatSyncCategorie] {

        try await chargerPageInitiale()

        var resultats: [ResultatSyncCategorie] = []

        for tab in categories {
            try await activerOnglet(tab)

            guard try await boutonExporterDisponible() else {
                resultats.append(ResultatSyncCategorie(tab: tab, url: nil))
                continue
            }

            try await lancerExport(pour: tab)
            // Le traitement le plus récent est toujours inséré en tête de liste
            // (index 0), quel que soit le nombre de traitements déjà présents.
            let fichier = try await recupererTelechargement(pour: tab, indexLigne: 0)
            resultats.append(ResultatSyncCategorie(tab: tab, url: fichier))
        }

        return resultats
    }

    // MARK: Chargement de page

    /// Charge le dashboard CRM et vérifie qu'on n'a pas été redirigé vers le login
    /// (session expirée). Si c'est le cas, lève `.sessionExpiree` plutôt que de
    /// continuer à cliquer sur des éléments qui n'existent pas sur cette page.
    private func chargerPageInitiale() async throws {
        try await naviguer(vers: urlDashboard)

        if let url = webView.url, url.absoluteString.contains(motifPageLogin) {
            throw DocGenSyncError.sessionExpiree
        }
    }

    private func naviguer(vers url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.navigationContinuation = continuation
            webView.load(URLRequest(url: url))
        }
    }

    /// À utiliser après avoir affiché `fenetreDeConnexion()` : attend que l'utilisateur
    /// quitte manuellement la page de login (identifiants saisis avec succès), puis
    /// force la navigation vers le dashboard CRM (le site ne le fait pas automatiquement).
    func attendreConnexionPuisChargerDashboard(timeout: TimeInterval = 300) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        // 1. Attendre qu'on ne soit plus sur la page de login, avec un court délai
        //    de stabilisation pour éviter de réagir à une redirection transitoire.
        while Date() < deadline {
            if let url = webView.url, !url.absoluteString.contains(motifPageLogin) {
                try await Task.sleep(nanoseconds: 1_000_000_000)  // 1s de stabilisation
                if let urlConfirmee = webView.url, !urlConfirmee.absoluteString.contains(motifPageLogin) {
                    break
                }
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        guard let url = webView.url, !url.absoluteString.contains(motifPageLogin) else {
            throw DocGenSyncError.timeout("connexion manuelle non détectée dans le délai imparti")
        }

        // 2. Le site ne redirige pas vers /dashboard/crm après connexion : on le fait nous-mêmes.
        try await chargerPageInitiale()
    }

    // MARK: Navigation par onglets (sans reload, cf. structure SPA de l'appli)

    private func activerOnglet(_ tab: CRMTab) async throws {
        let jsClick = "document.getElementById('flex-tabs-tab-\(tab.rawValue)')?.click();"
        _ = try? await webView.evaluateJavaScript(jsClick)

        let deadline = Date().addingTimeInterval(5)
        let jsCheck = "document.getElementById('flex-tabs-tab-\(tab.rawValue)')?.getAttribute('aria-selected') === 'true'"

        while Date() < deadline {
            if let actif = try? await webView.evaluateJavaScript(jsCheck) as? Bool, actif {
                // Court délai de stabilisation : laisse le temps au contenu
                // de l'onglet de finir de se charger après le changement
                try await Task.sleep(nanoseconds: 400_000_000)
                return
            }
            try await Task.sleep(nanoseconds: 150_000_000)
        }
        throw DocGenSyncError.ongletNonActif(tab)
    }

    // MARK: Détection du bouton Exporter (absent si catégorie vide)

    /// Le contenu de l'onglet (liste + bouton Exporter) peut se charger un peu après
    /// que l'onglet soit devenu actif (aria-selected), notamment s'il y a des données
    /// à récupérer côté serveur. On poll donc sur une courte fenêtre plutôt que de
    /// vérifier une seule fois, pour éviter de conclure à tort à une catégorie vide.
    private func boutonExporterDisponible(timeoutSecondes: TimeInterval = 5) async throws -> Bool {
        let js = """
        (() => {
            const btn = Array.from(document.querySelectorAll('button'))
                .find(b => b.textContent.trim() === 'Exporter');
            return !!btn;
        })()
        """

        let deadline = Date().addingTimeInterval(timeoutSecondes)
        while Date() < deadline {
            if let present = try? await webView.evaluateJavaScript(js) as? Bool, present {
                return true
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        return false
    }

    // MARK: Lancement de l'export + suivi de la ligne dans la modale des traitements

    /// Clique sur "Exporter" et attend qu'une nouvelle ligne apparaisse dans la modale
    /// (`.modal-body > div > div`). Les nouveaux traitements sont insérés en tête de
    /// liste (index 0) : on ne cible donc jamais par position calculée, seulement en
    /// confirmant qu'une ligne de plus est présente avant de lire l'index 0.
    private func lancerExport(pour tab: CRMTab) async throws {
        let countAvant = try await compterLignesModale()

        let jsClick = """
        (() => {
            const btn = Array.from(document.querySelectorAll('button'))
                .find(b => b.textContent.trim() === 'Exporter');
            if (btn) { btn.click(); return true; }
            return false;
        })()
        """
        let clique = try await webView.evaluateJavaScript(jsClick) as? Bool ?? false
        guard clique else { throw DocGenSyncError.exportEchoue(tab) }

        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            let count = try await compterLignesModale()
            if count >= countAvant + 1 { return }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        throw DocGenSyncError.timeout("nouvelle ligne de traitement non détectée pour \(tab.rawValue)")
    }

    private func compterLignesModale() async throws -> Int {
        let js = "document.querySelectorAll('.modal-body > div > div').length"
        let result = try await webView.evaluateJavaScript(js) as? Int
        return result ?? 0
    }

    // MARK: Attente de fin de traitement + téléchargement

    private func recupererTelechargement(pour tab: CRMTab, indexLigne: Int) async throws -> URL {
        // Attendre que le bouton "Télécharger" apparaisse dans la ligne ciblée
        // (le loader est remplacé par ce bouton une fois le job serveur terminé).
        let deadline = Date().addingTimeInterval(120)
        let jsPresenceBouton = """
        (() => {
            const rows = document.querySelectorAll('.modal-body > div > div');
            const row = rows[\(indexLigne)];
            if (!row) return false;
            const btn = Array.from(row.querySelectorAll('button'))
                .find(b => b.textContent.trim() === 'Télécharger');
            return !!btn;
        })()
        """

        var pret = false
        while Date() < deadline {
            if let ok = try? await webView.evaluateJavaScript(jsPresenceBouton) as? Bool, ok {
                pret = true
                break
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        guard pret else { throw DocGenSyncError.timeout("job d'export non terminé pour \(tab.rawValue)") }

        let destination = dossierDestination.appendingPathComponent(tab.nomFichier)
        downloadDestinationURL = destination

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            self.downloadContinuation = continuation

            let jsClickTelecharger = """
            (() => {
                const rows = document.querySelectorAll('.modal-body > div > div');
                const row = rows[\(indexLigne)];
                if (!row) return false;
                const btn = Array.from(row.querySelectorAll('button'))
                    .find(b => b.textContent.trim() === 'Télécharger');
                if (btn) { btn.click(); return true; }
                return false;
            })()
            """
            Task {
                let clique = try? await self.webView.evaluateJavaScript(jsClickTelecharger) as? Bool
                if clique != true {
                    self.downloadContinuation = nil
                    continuation.resume(throwing: DocGenSyncError.telechargementEchoue(tab))
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
        navigationContinuation?.resume(throwing: DocGenSyncError.chargementEchoue(error))
        navigationContinuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navigationContinuation?.resume(throwing: DocGenSyncError.chargementEchoue(error))
        navigationContinuation = nil
    }

    // Le clic sur "Télécharger" déclenche une réponse avec Content-Disposition,
    // que WKWebView convertit en WKDownload plutôt qu'en navigation classique.
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
            ?? dossierDestination.appendingPathComponent(suggestedFilename)

        // Supprime un éventuel fichier existant du run précédent, sinon WKDownload échoue.
        try? FileManager.default.removeItem(at: destination)
        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let destination = downloadDestinationURL else {
            downloadContinuation?.resume(throwing: DocGenSyncError.timeout("destination de téléchargement introuvable"))
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
