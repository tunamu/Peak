import Foundation

/// iCloud's key-value store as the settings mirror (F8), so settings follow the user to their other devices.
///
/// Needs the iCloud key-value storage entitlement; without it (an unsigned build) the store keeps values only in
/// memory and nothing syncs, which `SettingsStore` handles like an empty mirror.
@MainActor
public final class UbiquitousSettingsMirror: @MainActor SettingsMirror {
    public var onExternalChange: (@MainActor ([String]) -> Void)?

    private let store: NSUbiquitousKeyValueStore
    private var observer: (any NSObjectProtocol)?

    public init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] notification in
            let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
            MainActor.assumeIsolated {
                self?.onExternalChange?(keys)
            }
        }
        // Asks iCloud for values changed elsewhere since the last launch; they arrive through the notification.
        store.synchronize()
    }

    isolated deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func value(forKey key: String) -> Any? {
        store.object(forKey: key)
    }

    public func set(_ value: Any?, forKey key: String) {
        store.set(value, forKey: key)
    }
}
