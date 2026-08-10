import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  /// Canal expose au Dart (voir lib/services/icloud_backup_service.dart).
  private static let icloudChannel = "petitpas/icloud"

  /// Les sauvegardes vivent sous `Documents/` du conteneur : c'est le seul
  /// sous-dossier qu'iOS expose dans l'app Fichiers quand
  /// NSUbiquitousContainerIsDocumentScopePublic vaut true.
  private static let backupFolder = "backups"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(
        name: AppDelegate.icloudChannel,
        binaryMessenger: controller.binaryMessenger
      ).setMethodCallHandler { [weak self] call, result in
        self?.handleICloudCall(call, result: result)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Sauvegarde iCloud

  private enum ICloudError: Error {
    /// Aucun conteneur : pas de compte iCloud, ou iCloud Drive desactive.
    case unavailable
    /// Le fichier est reste un marqueur, iCloud n'a pas pu le rapatrier.
    case notDownloaded
    case badArguments

    var code: String {
      switch self {
      case .unavailable: return "icloud_unavailable"
      case .notDownloaded: return "icloud_not_downloaded"
      case .badArguments: return "icloud_bad_arguments"
      }
    }

    var message: String {
      switch self {
      case .unavailable:
        return "Aucun conteneur iCloud disponible pour cette application."
      case .notDownloaded:
        return "La sauvegarde n'a pas pu etre telechargee depuis iCloud."
      case .badArguments:
        return "Arguments invalides."
      }
    }
  }

  private func handleICloudCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]

    switch call.method {
    case "available":
      // Ne jamais remonter d'erreur ici : l'absence d'iCloud est un etat
      // normal, que l'interface doit pouvoir afficher sans traiter un echec.
      inBackground(result) { () -> Any? in
        FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
      }

    case "push":
      guard let paths = args["paths"] as? [String] else {
        return result(flutterError(.badArguments))
      }
      let keep = args["keep"] as? Int ?? 5
      inBackground(result) { () -> Any? in try self.push(paths: paths, keep: keep) }

    case "list":
      inBackground(result) { () -> Any? in try self.list() }

    case "pull":
      guard let name = args["name"] as? String,
            let destination = args["destination"] as? String else {
        return result(flutterError(.badArguments))
      }
      inBackground(result) { () -> Any? in try self.pull(name: name, destination: destination) }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Execute hors du thread principal et repond dessus.
  ///
  /// `url(forUbiquityContainerIdentifier:)` fait des entrees-sorties et peut
  /// bloquer plusieurs secondes au premier appel : sur le thread principal il
  /// gelerait l'interface.
  private func inBackground(_ result: @escaping FlutterResult, _ work: @escaping () throws -> Any?) {
    DispatchQueue.global(qos: .utility).async {
      do {
        let value = try work()
        DispatchQueue.main.async { result(value) }
      } catch let error as ICloudError {
        DispatchQueue.main.async { result(self.flutterError(error)) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "icloud_error", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func flutterError(_ error: ICloudError) -> FlutterError {
    FlutterError(code: error.code, message: error.message, details: nil)
  }

  private func backupsDirectory() throws -> URL {
    guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
      throw ICloudError.unavailable
    }
    let directory = container
      .appendingPathComponent("Documents")
      .appendingPathComponent(AppDelegate.backupFolder)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  /// Nom reel d'un element, marqueur de telechargement compris.
  ///
  /// Une sauvegarde deposee par un autre appareil et pas encore rapatriee
  /// apparait dans le dossier sous la forme `.auto_....json.icloud`. Sans
  /// cette normalisation elle serait ignoree au listage et reteleversee en
  /// double a chaque demarrage.
  private func logicalName(_ url: URL) -> String {
    let name = url.lastPathComponent
    guard name.hasPrefix("."), name.hasSuffix(".icloud") else { return name }
    return String(name.dropFirst().dropLast(".icloud".count))
  }

  /// Sauvegardes presentes dans le conteneur, de la plus recente a la plus
  /// ancienne (les noms sont horodates, l'ordre alphabetique inverse suffit).
  private func backupNames(in directory: URL) throws -> [String] {
    try FileManager.default
      .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [])
      .map { logicalName($0) }
      .filter { $0.hasSuffix(".json") }
      .sorted(by: >)
  }

  private func push(paths: [String], keep: Int) throws -> Int {
    let directory = try backupsDirectory()
    let fileManager = FileManager.default
    let alreadyThere = try backupNames(in: directory)
    var pushed = 0

    for path in paths {
      let source = URL(fileURLWithPath: path)
      // Les noms sont horodates donc immuables : un fichier deja present dans
      // le conteneur n'a jamais a etre reteleverse.
      guard fileManager.fileExists(atPath: path),
            !alreadyThere.contains(source.lastPathComponent) else { continue }
      try coordinatedCopy(from: source, to: directory.appendingPathComponent(source.lastPathComponent))
      pushed += 1
    }

    // Le conteneur suit le meme plafond que le dossier local, sinon iCloud
    // accumulerait indefiniment les sauvegardes de tous les appareils.
    for name in try backupNames(in: directory).dropFirst(keep) {
      try? fileManager.removeItem(at: directory.appendingPathComponent(name))
    }
    return pushed
  }

  private func list() throws -> [[String: Any]] {
    let directory = try backupsDirectory()
    let keys: Set<URLResourceKey> = [
      .fileSizeKey, .contentModificationDateKey, .ubiquitousItemDownloadingStatusKey,
    ]

    return try backupNames(in: directory).map { name -> [String: Any] in
      // Les valeurs sont lues sur l'URL logique : sur le marqueur, la taille
      // serait celle du marqueur et non celle de la sauvegarde.
      let values = try? directory.appendingPathComponent(name).resourceValues(forKeys: keys)
      let status = values?.ubiquitousItemDownloadingStatus
      let modified = values?.contentModificationDate ?? Date()
      return [
        "name": name,
        "size": values?.fileSize ?? 0,
        "modified": Int(modified.timeIntervalSince1970 * 1000),
        "downloaded": status == nil || status == .current,
      ]
    }
  }

  private func pull(name: String, destination: String) throws -> String {
    let fileManager = FileManager.default
    let source = try backupsDirectory().appendingPathComponent(name)

    if !fileManager.fileExists(atPath: source.path) {
      try fileManager.startDownloadingUbiquitousItem(at: source)
    }

    // Le telechargement est asynchrone cote iOS. On est deja sur une file de
    // fond : attendre ici evite d'exposer un etat intermediaire au Dart.
    let deadline = Date().addingTimeInterval(60)
    while Date() < deadline {
      let status = try? source.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        .ubiquitousItemDownloadingStatus
      if status == .current || (status == nil && fileManager.fileExists(atPath: source.path)) {
        break
      }
      Thread.sleep(forTimeInterval: 0.25)
    }
    guard fileManager.fileExists(atPath: source.path) else { throw ICloudError.notDownloaded }

    let target = URL(fileURLWithPath: destination)
    try fileManager.createDirectory(
      at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
    try coordinatedCopy(from: source, to: target)
    return target.path
  }

  /// Copie sous NSFileCoordinator.
  ///
  /// Une copie directe entrerait en conflit avec le demon de synchronisation
  /// s'il touche le meme fichier au meme moment, et livrerait un JSON tronque.
  private func coordinatedCopy(from source: URL, to target: URL) throws {
    var coordinationError: NSError?
    var copyError: Error?

    NSFileCoordinator().coordinate(
      readingItemAt: source, options: .withoutChanges,
      writingItemAt: target, options: .forReplacing,
      error: &coordinationError
    ) { readURL, writeURL in
      do {
        if FileManager.default.fileExists(atPath: writeURL.path) {
          try FileManager.default.removeItem(at: writeURL)
        }
        try FileManager.default.copyItem(at: readURL, to: writeURL)
      } catch {
        copyError = error
      }
    }

    if let error = coordinationError { throw error }
    if let error = copyError { throw error }
  }
}
