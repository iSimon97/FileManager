//
//  FileManagerHelper.swift
//  FileManager
//
//  Created by Simon Stasius on 19.09.25.
//
import Foundation

class FileManagerHelper {
    private let fileManager = FileManager.default
    
    // Neue Funktion mit beiden Daten
    func updateFileMetadata(file: URL, newName: String, newCreationDate: Date, newModificationDate: Date) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.performFileUpdate(
                        file: file,
                        newName: newName,
                        newCreationDate: newCreationDate,
                        newModificationDate: newModificationDate
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // Alte Funktion für Rückwärtskompatibilität (nur Erstellungsdatum)
    func updateFileMetadata(file: URL, newName: String, newCreationDate: Date) async throws -> URL {
        return try await updateFileMetadata(
            file: file,
            newName: newName,
            newCreationDate: newCreationDate,
            newModificationDate: Date() // Aktuelles Datum als Bearbeitungsdatum
        )
    }
    
    private func performFileUpdate(file: URL, newName: String, newCreationDate: Date, newModificationDate: Date) throws -> URL {
        let directory = file.deletingLastPathComponent()
        let fileExtension = file.pathExtension
        let newFileName = fileExtension.isEmpty ? newName : "\(newName).\(fileExtension)"
        let newURL = directory.appendingPathComponent(newFileName)
        
        // Check if we need to rename the file
        var finalURL = file
        if newURL != file {
            // Check if target file already exists
            if fileManager.fileExists(atPath: newURL.path) {
                throw FileOperationError.fileAlreadyExists(newURL.lastPathComponent)
            }
            
            // Rename file
            try fileManager.moveItem(at: file, to: newURL)
            finalURL = newURL
        }
        
        // Update both creation and modification dates
        let attributes: [FileAttributeKey: Any] = [
            .creationDate: newCreationDate,
            .modificationDate: newModificationDate
        ]
        
        try fileManager.setAttributes(attributes, ofItemAtPath: finalURL.path)
        
        return finalURL
    }
    
    func requestFileAccess(for url: URL) -> Bool {
        // For sandboxed apps, this would handle security-scoped bookmarks
        // For now, we'll just check if the file is accessible
        return fileManager.isReadableFile(atPath: url.path) && fileManager.isWritableFile(atPath: url.path)
    }
}

enum FileOperationError: LocalizedError {
    case fileAlreadyExists(String)
    case accessDenied(String)
    case invalidPath(String)
    case invalidDateRange
    
    var errorDescription: String? {
        switch self {
        case .fileAlreadyExists(let fileName):
            return "Eine Datei mit dem Namen '\(fileName)' existiert bereits"
        case .accessDenied(let path):
            return "Zugriff verweigert für: \(path)"
        case .invalidPath(let path):
            return "Ungültiger Pfad: \(path)"
        case .invalidDateRange:
            return "Das Erstellungsdatum darf nicht nach dem Bearbeitungsdatum liegen"
        }
    }
}
