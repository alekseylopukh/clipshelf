@MainActor
public protocol UpdaterDriver: AnyObject {
    var automaticallyChecksForUpdates: Bool { get set }
    func start() throws
    func checkForUpdates()
}
