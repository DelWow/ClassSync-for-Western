import Security
import XCTest
@testable import ClassSync

final class KeychainServiceTests: XCTestCase {
    func testSaveReadAndDeleteUseSecureKeychainQueries() throws {
        let client = FakeKeychainClient()
        let service = KeychainService(service: "test.classsync", client: client)
        let token = Data("fixture-value".utf8)

        try service.saveToken(token, account: "brightspace")
        client.valueToReturn = token

        XCTAssertEqual(try service.readToken(account: "brightspace"), token)
        try service.deleteToken(account: "brightspace")

        XCTAssertEqual(client.lastAdded?[kSecClass as String] as? String, kSecClassGenericPassword as String)
        XCTAssertEqual(client.lastAdded?[kSecAttrAccessible as String] as? String, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        XCTAssertNil(client.lastAdded?[kSecReturnData as String])
    }

    func testEmptyTokenIsRejected() {
        let service = KeychainService(service: "test.classsync", client: FakeKeychainClient())
        XCTAssertThrowsError(try service.saveToken(Data(), account: "brightspace")) { error in
            XCTAssertEqual(error as? KeychainError, .emptyToken)
        }
    }

    func testMissingTokenReturnsNil() throws {
        let client = FakeKeychainClient()
        client.copyStatus = errSecItemNotFound
        let service = KeychainService(service: "test.classsync", client: client)

        XCTAssertNil(try service.readToken(account: "brightspace"))
    }

    func testKeychainFailureIsMappedToTypedError() {
        let client = FakeKeychainClient()
        client.addStatus = errSecAuthFailed
        let service = KeychainService(service: "test.classsync", client: client)

        XCTAssertThrowsError(try service.saveToken(Data("token".utf8), account: "brightspace")) { error in
            XCTAssertEqual(error as? KeychainError, .status(errSecAuthFailed))
        }
    }
}

private final class FakeKeychainClient: KeychainClient {
    var addStatus: OSStatus = errSecSuccess
    var copyStatus: OSStatus = errSecSuccess
    var deleteStatus: OSStatus = errSecItemNotFound
    var valueToReturn: Data?
    var lastAdded: [String: Any]?

    func add(_ query: CFDictionary) -> OSStatus {
        lastAdded = query as? [String: Any]
        return addStatus
    }

    func copyMatching(_ query: CFDictionary, result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        if copyStatus == errSecSuccess, let valueToReturn {
            result?.pointee = valueToReturn as CFData
        }
        return copyStatus
    }

    func delete(_ query: CFDictionary) -> OSStatus {
        deleteStatus
    }
}
