import Foundation
import Security

enum KeychainStoreError: LocalizedError {
    case unexpectedData
    case unhandled(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedData:
            return "Stored keychain data was invalid."
        case .unhandled(let status):
            return "Keychain operation failed with status \(status)."
        }
    }
}

struct KeychainStore {
    private let service = "local.macvoiceinput"
    private let account = "llm.apiKey"

    func readAPIKey() throws -> String {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let key = String(data: data, encoding: .utf8) else {
                throw KeychainStoreError.unexpectedData
            }
            return key
        case errSecItemNotFound:
            return ""
        default:
            throw KeychainStoreError.unhandled(status)
        }
    }

    func saveAPIKey(_ value: String) throws {
        if value.isEmpty {
            let status = SecItemDelete(baseQuery as CFDictionary)
            if status == errSecSuccess || status == errSecItemNotFound {
                return
            }
            throw KeychainStoreError.unhandled(status)
        }

        let data = Data(value.utf8)
        var updateQuery = baseQuery
        let attributes = [kSecValueData as String: data] as CFDictionary
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            throw KeychainStoreError.unhandled(updateStatus)
        }

        updateQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(updateQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainStoreError.unhandled(addStatus)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
