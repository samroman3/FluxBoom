//
//  KeychainHelper.swift
//  fluxBoom
//
//  Created by Sam Roman on 8/6/24.
//
import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()

    func save(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ] as CFDictionary

        SecItemDelete(query) // Delete old item if it exists
        SecItemAdd(query, nil) // Add new item
    }

    func retrieve(key: String) -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary

        var dataTypeRef: AnyObject? = nil
        if SecItemCopyMatching(query, &dataTypeRef) == noErr {
            if let data = dataTypeRef as? Data {
                return String(data: data, encoding: .utf8)
            }
        }
        return nil
    }
}

