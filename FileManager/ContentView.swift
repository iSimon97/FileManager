import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedFile: URL?
    @State private var fileName: String = ""
    @State private var originalFileName: String = ""
    @State private var creationDate: Date = Date()
    @State private var originalCreationDate: Date = Date()
    @State private var modificationDate: Date = Date()
    @State private var originalModificationDate: Date = Date()
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var isDragOver: Bool = false
    @State private var isLoading: Bool = false
    @State private var isBulkMode: Bool = false
    @State private var bulkDateOption: BulkDateOption = .modificationEqualsCreation
    @State private var selectedFiles: [URL] = []
    @State private var bulkProgress: Double = 0.0
    @State private var isProcessingBulk: Bool = false

    enum BulkDateOption: String, CaseIterable {
        case modificationEqualsCreation = "Bearbeitungszeit = Erstellungszeit"
        case creationEqualsModification = "Erstellungszeit = Bearbeitungszeit"
    }
    
    private let fileValidator = FileValidator()
    private let fileManagerHelper = FileManagerHelper()
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("File Metadata Editor")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            // File Drop Area
            fileDropArea
            
            if let selectedFile = selectedFile {
                // File Info Display
                fileInfoSection(for: selectedFile)
                
                // Edit Controls
                editingControls
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 500)
        .alert("Hinweis", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - File Drop Area
    private var fileDropArea: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isDragOver ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
            .stroke(isDragOver ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
            .frame(height: 120)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: selectedFile == nil ? "doc.badge.plus" : "doc.checkmark")
                        .font(.system(size: 40))
                        .foregroundColor(isDragOver ? .accentColor : .secondary)
                    
                    Text(selectedFile == nil ? "Datei hier hinziehen oder klicken zum Auswählen" : "Datei ausgewählt")
                        .font(.headline)
                        .foregroundColor(isDragOver ? .accentColor : .secondary)
                    
                    if selectedFile == nil {
                        Text("Unterstützt alle Dateitypen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            )
            .onTapGesture {
                selectFile()
            }
            .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                handleDrop(providers: providers)
            }
    }
    
    // MARK: - File Info Section
    private func fileInfoSection(for file: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.accentColor)
                Text("Ausgewählte Datei:")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pfad:")
                        .fontWeight(.semibold)
                        .frame(width: 120, alignment: .leading)
                    Text(file.path)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                
                HStack {
                    Text("Name:")
                        .fontWeight(.semibold)
                        .frame(width: 120, alignment: .leading)
                    Text(originalFileName)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Erstellt:")
                        .fontWeight(.semibold)
                        .frame(width: 120, alignment: .leading)
                    Text(DateFormatter.readable.string(from: originalCreationDate))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Bearbeitet:")
                        .fontWeight(.semibold)
                        .frame(width: 120, alignment: .leading)
                    Text(DateFormatter.readable.string(from: originalModificationDate))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Editing Controls
    private var editingControls: some View {
        VStack(spacing: 16) {
            // Bulk Mode Toggle
            HStack {
                Toggle("Bulk Changes", isOn: $isBulkMode)
                    .font(.headline)
                Spacer()
            }
            
            if isBulkMode {
                bulkModeControls
            } else {
                singleFileControls
            }
        }
    }

    private var bulkModeControls: some View {
        VStack(spacing: 16) {
            GroupBox("Bulk-Modus") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Datum-Option:")
                            .frame(width: 120, alignment: .leading)
                        Picker("", selection: $bulkDateOption) {
                            ForEach(BulkDateOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        Spacer()
                    }
                    
                    if !selectedFiles.isEmpty {
                        HStack {
                            Text("Dateien:")
                                .frame(width: 120, alignment: .leading)
                            Text("\(selectedFiles.count) Dateien ausgewählt")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    
                    if isProcessingBulk {
                        VStack {
                            ProgressView("Verarbeite Dateien...", value: bulkProgress, total: 1.0)
                            Text("\(Int(bulkProgress * 100))% abgeschlossen")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
            
            HStack(spacing: 12) {
                Button("Dateien wählen") {
                    selectMultipleFiles()
                }
                .disabled(isProcessingBulk)
                
                Button("Alle verarbeiten") {
                    processBulkFiles()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedFiles.isEmpty || isProcessingBulk)
            }
        }
    }

    private var singleFileControls: some View {
        VStack(spacing: 16) {
            GroupBox("Datei bearbeiten") {
                VStack(spacing: 16) {
                    // Filename
                    HStack {
                        Text("Dateiname:")
                            .frame(width: 120, alignment: .leading)
                        TextField("Neuer Dateiname", text: $fileName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Divider()
                    
                    // Creation Date
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Erstellungsdatum:")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        HStack {
                            Text("Datum:")
                                .frame(width: 120, alignment: .leading)
                            DatePicker("", selection: $creationDate, displayedComponents: [.date])
                                .datePickerStyle(.compact)
                            Spacer()
                        }
                        
                        HStack {
                            Text("Uhrzeit:")
                                .frame(width: 120, alignment: .leading)
                            DatePicker("", selection: $creationDate, displayedComponents: [.hourAndMinute])
                                .datePickerStyle(.compact)
                            Spacer()
                        }
                    }
                    
                    Divider()
                    
                    // Modification Date
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Bearbeitungsdatum:")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        HStack {
                            Text("Datum:")
                                .frame(width: 120, alignment: .leading)
                            DatePicker("", selection: $modificationDate, displayedComponents: [.date])
                                .datePickerStyle(.compact)
                            Spacer()
                        }
                        
                        HStack {
                            Text("Uhrzeit:")
                                .frame(width: 120, alignment: .leading)
                            DatePicker("", selection: $modificationDate, displayedComponents: [.hourAndMinute])
                                .datePickerStyle(.compact)
                            Spacer()
                        }
                    }
                    
                    // Quick Actions
                    HStack {
                        Button("Aktuelle Zeit für beide") {
                            let now = Date()
                            creationDate = now
                            modificationDate = now
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Bearbeitungszeit = Erstellungszeit") {
                            modificationDate = creationDate
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Erstellungszeit = Bearbeitungszeit") {
                            creationDate = modificationDate
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(.caption)
                }
                .padding()
            }
            
            HStack(spacing: 12) {
                Button("Abbrechen") {
                    cancelEditing()
                }
                .keyboardShortcut(.escape)
                
                Button("Speichern") {
                    saveChanges()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .disabled(fileName.isEmpty || isLoading)
            }
            
            if isLoading {
                ProgressView("Speichere Änderungen...")
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Neue Datei wählen") {
                selectFile()
            }
            
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - File Operations
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            loadFile(url: url)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        if isBulkMode {
            return handleBulkDrop(providers: providers)
        } else {
            guard let provider = providers.first else { return false }
            
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                DispatchQueue.main.async {
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        loadFile(url: url)
                    }
                }
            }
            return true
        }
    }
    
    private func loadFile(url: URL) {
        selectedFile = url
        originalFileName = url.lastPathComponent
        fileName = url.deletingPathExtension().lastPathComponent
        
        // Load creation and modification dates
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            
            if let creationDate = attributes[.creationDate] as? Date {
                self.originalCreationDate = creationDate
                self.creationDate = creationDate
            }
            
            if let modificationDate = attributes[.modificationDate] as? Date {
                self.originalModificationDate = modificationDate
                self.modificationDate = modificationDate
            }
        } catch {
            showAlert("Fehler beim Laden der Datei-Attribute: \(error.localizedDescription)")
        }
        
    }
    
    
    private func cancelEditing() {
        fileName = selectedFile?.deletingPathExtension().lastPathComponent ?? ""
        creationDate = originalCreationDate
        modificationDate = originalModificationDate
    }
    
    private func saveChanges() {
        guard let currentFile = selectedFile else { return }
        
        // Validate filename
        let validation = fileValidator.validateFileName(fileName)
        if !validation.isValid {
            showAlert("Ungültiger Dateiname: \(validation.errorMessage ?? "Unbekannter Fehler")")
            return
        }
        
        // Validate dates (creation date should not be after modification date)
        if creationDate > modificationDate {
            showAlert("Das Erstellungsdatum darf nicht nach dem Bearbeitungsdatum liegen.")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let newURL = try await fileManagerHelper.updateFileMetadata(
                    file: currentFile,
                    newName: fileName,
                    newCreationDate: creationDate,
                    newModificationDate: modificationDate
                )
                
                await MainActor.run {
                    selectedFile = newURL
                    originalFileName = newURL.lastPathComponent
                    originalCreationDate = creationDate
                    originalModificationDate = modificationDate
                    isLoading = false
                    showAlert("Datei erfolgreich aktualisiert!")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showAlert("Fehler beim Speichern: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func selectMultipleFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            selectedFiles = panel.urls
        }
    }

    private func handleBulkDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.selectedFiles = urls
            if !urls.isEmpty {
                self.processBulkFiles()
            }
        }
        
        return true
    }

    private func processBulkFiles() {
        guard !selectedFiles.isEmpty else { return }
        
        isProcessingBulk = true
        bulkProgress = 0.0
        
        Task {
            let totalFiles = selectedFiles.count
            
            for (index, fileURL) in selectedFiles.enumerated() {
                do {
                    // Get current file attributes
                    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    let currentCreation = attributes[.creationDate] as? Date ?? Date()
                    let currentModification = attributes[.modificationDate] as? Date ?? Date()
                    
                    // Determine new dates based on selected option
                    let (newCreation, newModification): (Date, Date)
                    switch bulkDateOption {
                    case .modificationEqualsCreation:
                        newCreation = currentCreation
                        newModification = currentCreation
                    case .creationEqualsModification:
                        newCreation = currentModification
                        newModification = currentModification
                    }
                    
                    // Update file metadata (keep original name)
                    let fileName = fileURL.deletingPathExtension().lastPathComponent
                    _ = try await fileManagerHelper.updateFileMetadata(
                        file: fileURL,
                        newName: fileName,
                        newCreationDate: newCreation,
                        newModificationDate: newModification
                    )
                    
                    await MainActor.run {
                        bulkProgress = Double(index + 1) / Double(totalFiles)
                    }
                    
                } catch {
                    await MainActor.run {
                        showAlert("Fehler bei Datei \(fileURL.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            }
            
            await MainActor.run {
                isProcessingBulk = false
                selectedFiles.removeAll()
                bulkProgress = 0.0
                showAlert("Bulk-Verarbeitung abgeschlossen! \(totalFiles) Dateien wurden bearbeitet.")
            }
        }
    }
    
    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let readable: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
}

#Preview {
    ContentView()
}
