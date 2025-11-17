import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    private let service = "qinggan.ai.key"
    private var cache: String = ""
    func setAPIKey(_ key: String) {
        let account = "apiKey"
        let data = key.data(using: .utf8) ?? Data()
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        SecItemAdd(attrs as CFDictionary, nil)
        cache = key
    }
    func getAPIKey() -> String {
        let account = "apiKey"
        if !cache.isEmpty { return cache }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: kCFBooleanTrue as Any, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data, let str = String(data: data, encoding: .utf8) { cache = str; return str }
        return ""
    }
}