import Foundation
import UIKit
import SwiftData

@MainActor
protocol PhotoStorageServiceProtocol {
    func save(jpegData: Data) throws -> String
    func load(fileName: String) -> UIImage?
    func delete(fileName: String)
    func purgeExpired(context: ModelContext)
}

@MainActor
final class PhotoStorageService: PhotoStorageServiceProtocol {
    let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directory = base.appendingPathComponent("MealPhotos", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    func save(jpegData: Data) throws -> String {
        let fileName = UUID().uuidString + ".jpg"
        let url = directory.appendingPathComponent(fileName)
        try jpegData.write(to: url, options: .atomic)
        return fileName
    }

    func load(fileName: String) -> UIImage? {
        let url = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func delete(fileName: String) {
        let url = directory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }

    func purgeExpired(context: ModelContext) {
        let now = Date()
        let descriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { $0.photoDeleted == false && $0.photoFileName != nil }
        )
        guard let meals = try? context.fetch(descriptor) else { return }
        for meal in meals where meal.photoExpiryDate <= now {
            if let fileName = meal.photoFileName {
                delete(fileName: fileName)
            }
            meal.photoFileName = nil
            meal.photoDeleted = true
        }
        try? context.save()
    }
}
