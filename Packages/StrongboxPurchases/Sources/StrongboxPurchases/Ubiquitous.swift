import Foundation

#if !os(watchOS)
@propertyWrapper
struct Ubiquitous<T> {
    private var key: String
    private var defaultValue: T
    private var store: NSUbiquitousKeyValueStore

    init(key: String, defaultValue: @autoclosure () -> (T), store: NSUbiquitousKeyValueStore = .default) {
        self.key = key
        self.defaultValue = defaultValue()
        self.store = store
    }

    var wrappedValue: T {
        get {
            guard let existingValue = store.object(forKey: key) as? T else {
                store.set(defaultValue, forKey: key)
                return defaultValue
            }
            return existingValue
        }
        set {
            store.set(newValue, forKey: key)
        }
    }
}
#else
@propertyWrapper
struct Ubiquitous<T> {
    private var key: String
    private var defaultValue: T
    private var store: UserDefaults

    init(key: String, defaultValue: @autoclosure () -> (T), store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue()
        self.store = store
    }

    var wrappedValue: T {
        get {
            guard let existingValue = store.object(forKey: key) as? T else {
                store.set(defaultValue, forKey: key)
                return defaultValue
            }
            return existingValue
        }
        set {
            store.set(newValue, forKey: key)
        }
    }
}

#endif
