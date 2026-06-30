import Testing
import Foundation
import UIKit
@testable import TriggerIQ

@MainActor
struct PhotoStorageServiceTests {
    // Each test gets a fresh temp directory so files don't bleed between tests
    private func makeService() -> (PhotoStorageService, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let service = PhotoStorageService(directory: dir)
        return (service, dir)
    }

    // MARK: - save

    @Test func saveWritesFileToDirectory() throws {
        let (service, dir) = makeService()
        let data = UIImage(systemName: "fork.knife")!.jpegData(compressionQuality: 0.8)!
        let fileName = try service.save(jpegData: data)
        let fileURL = dir.appendingPathComponent(fileName)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func saveReturnsUniqueFileNames() throws {
        let (service, _) = makeService()
        let data = Data([0xFF, 0xD8, 0xFF])
        let name1 = try service.save(jpegData: data)
        let name2 = try service.save(jpegData: data)
        #expect(name1 != name2)
    }

    @Test func savedFileNamesHaveJpgExtension() throws {
        let (service, _) = makeService()
        let fileName = try service.save(jpegData: Data([0xFF, 0xD8, 0xFF]))
        #expect(fileName.hasSuffix(".jpg"))
    }

    // MARK: - load

    @Test func loadReturnsNilForMissingFile() {
        let (service, _) = makeService()
        #expect(service.load(fileName: "nonexistent.jpg") == nil)
    }

    @Test func loadReturnsImageAfterSave() throws {
        let (service, _) = makeService()
        let original = UIImage(systemName: "fork.knife")!
        let data = original.jpegData(compressionQuality: 0.8)!
        let fileName = try service.save(jpegData: data)
        let loaded = service.load(fileName: fileName)
        #expect(loaded != nil)
    }

    // MARK: - delete

    @Test func deleteRemovesFile() throws {
        let (service, dir) = makeService()
        let fileName = try service.save(jpegData: Data([0xFF, 0xD8, 0xFF]))
        service.delete(fileName: fileName)
        let fileURL = dir.appendingPathComponent(fileName)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func deleteNonExistentFileDoesNotThrow() {
        let (service, _) = makeService()
        service.delete(fileName: "ghost.jpg") // should not throw or crash
    }
}
