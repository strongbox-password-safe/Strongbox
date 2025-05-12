import Foundation

@propertyWrapper
struct UserDefault<Value> {
    let key: String
    let defaultValue: Value
    private let defaults: UserDefaults

    init(_ key: String,
         default defaultValue: Value,
         defaults: UserDefaults = .standard)
    {
        self.key = key
        self.defaultValue = defaultValue
        self.defaults = defaults
    }

    var wrappedValue: Value {
        get {
            if let value = defaults.object(forKey: key) as? Value {
                return value
            } else {
                defaults.set(defaultValue, forKey: key)
                return defaultValue
            }
        }
        set {
            defaults.set(newValue, forKey: key)
        }
    }
}
