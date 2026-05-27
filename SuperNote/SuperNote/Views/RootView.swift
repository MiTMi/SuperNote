import AppKit
import SwiftData
import SwiftUI

enum SidebarSelection: Hashable {
    case allNotes
    case folder(UUID)
    case trash
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Note.updatedAt, order: .reverse)]) private var notes: [Note]
    @Query(sort: [SortDescriptor(\Folder.createdAt, order: .forward)]) private var folders: [Folder]

    @State private var selectedScope: SidebarSelection = .allNotes
    @State private var selectedNoteID: UUID?
    @State private var syncMonitor = CloudSyncMonitor(
        enabled: AppContainer.useCloudKit,
        containerID: AppContainer.cloudKitContainerID
    )

    private var rootFolders: [Folder] {
        folders.filter { $0.parent == nil }
    }

    private var selectedFolder: Folder? {
        guard case .folder(let id) = selectedScope else { return nil }
        return folders.first(where: { $0.id == id })
    }

    private var inTrash: Bool {
        if case .trash = selectedScope { return true }
        return false
    }

    private var visibleNotes: [Note] {
        switch selectedScope {
        case .allNotes:
            return notes
                .filter { !$0.isTrashed }
                .sorted(by: noteSort)
        case .folder:
            guard let folder = selectedFolder else { return [] }
            return notes
                .filter { !$0.isTrashed && isDescendant(note: $0, of: folder) }
                .sorted(by: noteSort)
        case .trash:
            return notes
                .filter { $0.isTrashed }
                .sorted { ($0.trashedAt ?? .distantPast) > ($1.trashedAt ?? .distantPast) }
        }
    }

    private func noteSort(_ lhs: Note, _ rhs: Note) -> Bool {
        if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
        return lhs.updatedAt > rhs.updatedAt
    }

    private func isDescendant(note: Note, of folder: Folder) -> Bool {
        var current: Folder? = note.folder
        while let f = current {
            if f.id == folder.id { return true }
            current = f.parent
        }
        return false
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                rootFolders: rootFolders,
                allFolders: folders,
                notes: visibleNotes,
                selectedScope: $selectedScope,
                selectedNoteID: $selectedNoteID,
                inTrash: inTrash,
                trashCount: notes.filter { $0.isTrashed }.count,
                syncMonitor: syncMonitor,
                onCreateNote: { createNote(in: selectedFolder) },
                onTrashNote: trashNote,
                onRestoreNote: restoreNote,
                onPermanentlyDeleteNote: permanentlyDeleteNote,
                onEmptyTrash: emptyTrash,
                onTogglePin: togglePin,
                onDuplicate: duplicateNote,
                onExportFile: exportNoteToFile,
                onExportMail: exportNoteByMail,
                onMoveNote: moveNote,
                onCreateFolder: { createFolder(parent: nil) },
                onCreateSubfolder: { createFolder(parent: $0) },
                onRenameFolder: renameFolder,
                onDeleteFolder: deleteFolder
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            if let note = currentNote {
                NoteEditorView(note: note)
                    .id(note.id)
            } else {
                EmptyEditorPlaceholder(
                    inTrash: inTrash,
                    onCreate: { createNote(in: selectedFolder) }
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 600, minHeight: 460)
        .background(.ultraThinMaterial)
        .onAppear {
            if selectedNoteID == nil {
                selectedNoteID = visibleNotes.first?.id
            }
        }
    }

    private var currentNote: Note? {
        if let selectedNoteID,
           let match = visibleNotes.first(where: { $0.id == selectedNoteID }) {
            return match
        }
        return visibleNotes.first
    }

    private func createNote(in folder: Folder?) {
        let note = Note(folder: folder)
        modelContext.insert(note)
        try? modelContext.save()
        selectedNoteID = note.id
    }

    private func trashNote(_ note: Note) {
        let wasSelected = note.id == selectedNoteID
        note.isTrashed = true
        note.trashedAt = .now
        try? modelContext.save()
        if wasSelected {
            selectedNoteID = visibleNotes.first(where: { $0.id != note.id })?.id
        }
    }

    private func restoreNote(_ note: Note) {
        let wasSelected = note.id == selectedNoteID
        note.isTrashed = false
        note.trashedAt = nil
        try? modelContext.save()
        if wasSelected {
            selectedNoteID = visibleNotes.first(where: { $0.id != note.id })?.id
        }
    }

    private func permanentlyDeleteNote(_ note: Note) {
        let wasSelected = note.id == selectedNoteID
        modelContext.delete(note)
        try? modelContext.save()
        if wasSelected {
            selectedNoteID = visibleNotes.first(where: { $0.id != note.id })?.id
        }
    }

    private func emptyTrash() {
        let trashed = notes.filter { $0.isTrashed }
        for note in trashed {
            modelContext.delete(note)
        }
        try? modelContext.save()
        selectedNoteID = nil
    }

    private func togglePin(_ note: Note) {
        note.isPinned.toggle()
        try? modelContext.save()
    }

    private func duplicateNote(_ note: Note) {
        let copy = Note(
            body: note.body,
            backgroundColorHex: note.backgroundColorHex,
            isPinned: note.isPinned,
            folder: note.folder
        )
        modelContext.insert(copy)
        try? modelContext.save()
        selectedNoteID = copy.id
    }

    private func moveNote(_ note: Note, to folder: Folder?) {
        note.folder = folder
        note.updatedAt = .now
        try? modelContext.save()
    }

    private func createFolder(parent: Folder?) {
        let folder = Folder(name: "New Folder", parent: parent)
        modelContext.insert(folder)
        try? modelContext.save()
        selectedScope = .folder(folder.id)
    }

    private func renameFolder(_ folder: Folder, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        folder.name = trimmed
        try? modelContext.save()
    }

    private func deleteFolder(_ folder: Folder) {
        trashNotesRecursively(in: folder)
        let wasSelected: Bool
        if case .folder(let id) = selectedScope, id == folder.id {
            wasSelected = true
        } else {
            wasSelected = false
        }
        modelContext.delete(folder)
        try? modelContext.save()
        if wasSelected {
            selectedScope = .allNotes
        }
    }

    private func trashNotesRecursively(in folder: Folder) {
        for note in folder.notes ?? [] {
            note.isTrashed = true
            note.trashedAt = .now
        }
        for child in folder.children ?? [] {
            trashNotesRecursively(in: child)
        }
    }

    private func exportNoteToFile(_ note: Note) {
        let panel = NSSavePanel()
        panel.title = "Export Note"
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(sanitizedFilename(note.displayTitle)).md"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? Data(note.body.utf8).write(to: url, options: .atomic)
        }
    }

    private func exportNoteByMail(_ note: Note) {
        let subject = note.displayTitle
        let body = note.body

        if let service = NSSharingService(named: .composeEmail),
           service.canPerform(withItems: [body]) {
            service.subject = subject
            service.perform(withItems: [body])
            return
        }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = ""
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func sanitizedFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
        let trimmed = cleaned.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Note" : trimmed
    }
}

private struct EmptyEditorPlaceholder: View {
    let inTrash: Bool
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: inTrash ? "trash" : "note.text")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text(inTrash ? "Trash is empty" : "No note selected")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            if !inTrash {
                Button(action: onCreate) {
                    Label("New Note", systemImage: "square.and.pencil")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    RootView()
        .modelContainer(for: Note.self, inMemory: true)
        .frame(width: 600, height: 460)
}
