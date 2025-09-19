//
//  FileValidator.swift
//  FileManager
//
//  Created by Simon Stasius on 19.09.25.
//

import Foundation

struct FileValidator {
    struct ValidationResult {
        let isValid: Bool
        let errorMessage: String?
    }
    
    private let invalidCharacters: Set<Character> = [
        "/", "\\", ":", "*", "\"", "<", ">", "|", "\0"
    ]
    
    private let reservedNames: Set<String> = [
        "CON", "PRN", "AUX", "NUL",
        "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
        "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
    ]
    
    func validateFileName(_ fileName: String) -> ValidationResult {
        // Check if empty
        let trimmedName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return ValidationResult(isValid: false, errorMessage: "Dateiname darf nicht leer sein")
        }
        
        // Check length (macOS supports up to 255 characters)
        if trimmedName.count > 255 {
            return ValidationResult(isValid: false, errorMessage: "Dateiname ist zu lang (max. 255 Zeichen)")
        }
        
        // Check for invalid characters
        for char in trimmedName {
            if invalidCharacters.contains(char) {
                return ValidationResult(
                    isValid: false,
                    errorMessage: "Ungültiges Zeichen '\(char)' im Dateinamen"
                )
            }
        }
        
        // Check for reserved names (mostly Windows, but good practice)
        let nameWithoutExtension = (trimmedName as NSString).deletingPathExtension.uppercased()
        if reservedNames.contains(nameWithoutExtension) {
            return ValidationResult(
                isValid: false,
                errorMessage: "'\(nameWithoutExtension)' ist ein reservierter Name"
            )
        }
        
        // Check if name starts or ends with space or dot
        if trimmedName.hasPrefix(".") && trimmedName.count == 1 {
            return ValidationResult(isValid: false, errorMessage: "Dateiname darf nicht nur aus einem Punkt bestehen")
        }
        
        if trimmedName.hasPrefix("..") && trimmedName.count == 2 {
            return ValidationResult(isValid: false, errorMessage: "Dateiname darf nicht '..' sein")
        }
        
        if trimmedName.hasSuffix(" ") {
            return ValidationResult(isValid: false, errorMessage: "Dateiname darf nicht mit Leerzeichen enden")
        }
        
        return ValidationResult(isValid: true, errorMessage: nil)
    }
}
