import Foundation
import UIKit
import SwiftData
@testable import TriggerIQ

final class MockPhotoStorageService: PhotoStorageServiceProtocol {
    var savedData: Data?
    var savedFileName: String = "mock-photo.jpg"
    var loadedImage: UIImage?
    var deletedFileNames: [String] = []
    var purgeExpiredCalled = false
    var shouldThrowOnSave = false

    func save(jpegData: Data) throws -> String {
        if shouldThrowOnSave { throw URLError(.cannotCreateFile) }
        savedData = jpegData
        return savedFileName
    }

    func load(fileName: String) -> UIImage? {
        loadedImage
    }

    func delete(fileName: String) {
        deletedFileNames.append(fileName)
    }

    func purgeExpired(context: ModelContext) {
        purgeExpiredCalled = true
    }
}
