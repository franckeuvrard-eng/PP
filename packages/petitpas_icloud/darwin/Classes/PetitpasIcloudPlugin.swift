import Foundation
#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif

/// Acces au conteneur iCloud Drive prive de l'application.
///
/// Tout passe par des chemins de fichiers dans le conteneur : lecture et
/// ecriture coordonnees (NSFileCoordinator, obligatoire pour iCloud),
/// telechargement des fichiers pas encore presents sur l'appareil, et
/// versions en conflit quand deux appareils ont ecrit en meme temps.
/// Tout le travail se fait hors du fil principal.
public class PetitpasIcloudPlugin: NSObject, FlutterPlugin {
  private let queue = DispatchQueue(label: "fr.franckeuvrard.apetitspas.icloud", qos: .utility)

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: "petitpas/icloud", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(PetitpasIcloudPlugin(), channel: channel)
    FlutterEventChannel(name: "petitpas/icloud/changes", binaryMessenger: messenger)
      .setStreamHandler(ICloudChangeWatcher())
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    queue.async {
      let value: Any?
      do {
        value = try self.run(call.method, args)
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "icloud", message: error.localizedDescription, details: nil))
        }
        return
      }
      DispatchQueue.main.async { result(value) }
    }
  }

  private func run(_ method: String, _ args: [String: Any]) throws -> Any? {
    let fm = FileManager.default
    switch method {
    case "isAvailable":
      return fm.ubiquityIdentityToken != nil

    case "containerDocuments":
      // A appeler hors du fil principal : peut prendre du temps au 1er appel.
      guard let id = args["id"] as? String,
            let root = fm.url(forUbiquityContainerIdentifier: id) else { return nil }
      let docs = root.appendingPathComponent("Documents", isDirectory: true)
      try fm.createDirectory(at: docs, withIntermediateDirectories: true)
      return docs.path

    case "exists":
      let url = URL(fileURLWithPath: try path(args))
      return fm.fileExists(atPath: url.path) || fm.fileExists(atPath: placeholder(of: url).path)

    case "list":
      // Chemins relatifs des fichiers sous `path`, y compris ceux pas encore
      // telecharges (presents sous forme de « .nom.icloud »).
      let dir = URL(fileURLWithPath: try path(args), isDirectory: true)
      guard let e = fm.enumerator(at: dir, includingPropertiesForKeys: [.isDirectoryKey]) else { return [String]() }
      var out: [String] = []
      for case let url as URL in e {
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if isDir { continue }
        var rel = String(url.path.dropFirst(dir.path.count + 1))
        let name = url.lastPathComponent
        if name.hasPrefix(".") && name.hasSuffix(".icloud") {
          let real = String(name.dropFirst().dropLast(".icloud".count))
          rel = (rel as NSString).deletingLastPathComponent
          rel = rel.isEmpty ? real : rel + "/" + real
        } else if name.hasPrefix(".") {
          continue
        }
        out.append(rel)
      }
      return out

    case "ensureDownloaded":
      let url = URL(fileURLWithPath: try path(args))
      let timeout = (args["timeoutMs"] as? Int ?? 30000)
      return try ensureDownloaded(url, timeoutMs: timeout)

    case "read":
      let url = URL(fileURLWithPath: try path(args))
      var data: Data?
      var readError: Error?
      var coordError: NSError?
      NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { u in
        do { data = try Data(contentsOf: u) } catch { readError = error }
      }
      if let e = coordError ?? readError { throw e }
      return data.map { FlutterStandardTypedData(bytes: $0) }

    case "write":
      let url = URL(fileURLWithPath: try path(args))
      guard let bytes = args["bytes"] as? FlutterStandardTypedData else { throw err("octets manquants") }
      try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      var writeError: Error?
      var coordError: NSError?
      NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { u in
        do { try bytes.data.write(to: u, options: .atomic) } catch { writeError = error }
      }
      if let e = coordError ?? writeError { throw e }
      return true

    case "conflictVersions":
      // Contenu des versions ecrites en meme temps par d'autres appareils.
      let url = URL(fileURLWithPath: try path(args))
      let versions = NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []
      return versions.compactMap { v -> FlutterStandardTypedData? in
        guard let d = try? Data(contentsOf: v.url) else { return nil }
        return FlutterStandardTypedData(bytes: d)
      }

    case "resolveConflicts":
      let url = URL(fileURLWithPath: try path(args))
      for v in NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? [] { v.isResolved = true }
      try NSFileVersion.removeOtherVersionsOfItem(at: url)
      return true

    default:
      throw err("methode inconnue : \(method)")
    }
  }

  private func ensureDownloaded(_ url: URL, timeoutMs: Int) throws -> Bool {
    let fm = FileManager.default
    if !fm.fileExists(atPath: url.path) && !fm.fileExists(atPath: placeholder(of: url).path) {
      return false
    }
    try? fm.startDownloadingUbiquitousItem(at: url)
    let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000)
    while Date() < deadline {
      var u = url
      u.removeAllCachedResourceValues()
      let status = try? u.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        .ubiquitousItemDownloadingStatus
      // Fichier local hors iCloud (status nil) ou a jour : pret a lire.
      if fm.fileExists(atPath: url.path) && (status == nil || status == .current) { return true }
      Thread.sleep(forTimeInterval: 0.3)
    }
    return false
  }

  private func placeholder(of url: URL) -> URL {
    url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).icloud")
  }

  private func path(_ args: [String: Any]) throws -> String {
    guard let p = args["path"] as? String, !p.isEmpty else { throw err("chemin manquant") }
    return p
  }

  private func err(_ message: String) -> NSError {
    NSError(domain: "petitpas_icloud", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
  }
}

/// Previent Flutter des que iCloud apporte une nouvelle version d'un fichier
/// du conteneur (ecrit par un autre appareil), pour synchroniser aussitot au
/// lieu d'attendre la verification periodique.
///
/// Arguments d'ecoute : { "name": nom du fichier surveille }. Un evenement
/// (nil) est envoye a chaque changement signale par iCloud.
class ICloudChangeWatcher: NSObject, FlutterStreamHandler {
  private var query: NSMetadataQuery?
  private var sink: FlutterEventSink?
  private var observers: [NSObjectProtocol] = []

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    let name = (arguments as? [String: Any])?["name"] as? String ?? "classe.json"
    sink = events
    // NSMetadataQuery doit vivre sur le fil principal (boucle d'evenements).
    DispatchQueue.main.async {
      let q = NSMetadataQuery()
      q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
      q.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, name)
      let center = NotificationCenter.default
      for n in [Notification.Name.NSMetadataQueryDidUpdate, .NSMetadataQueryDidFinishGathering] {
        self.observers.append(center.addObserver(forName: n, object: q, queue: .main) { [weak self] _ in
          self?.sink?(nil)
        })
      }
      self.query = q
      q.start()
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    DispatchQueue.main.async {
      self.query?.stop()
      self.query = nil
      for o in self.observers { NotificationCenter.default.removeObserver(o) }
      self.observers = []
    }
    sink = nil
    return nil
  }
}
