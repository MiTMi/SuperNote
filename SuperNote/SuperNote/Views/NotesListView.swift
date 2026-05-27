import SwiftUI

struct SidebarView: View {
    let rootFolders: [Folder]
    let allFolders: [Folder]
    let notes: [Note]
    @Binding var selectedScope: SidebarSelection
    @Binding var selectedNoteID: UUID?
    let inTrash: Bool
    let trashCount: Int
    let syncMonitor: CloudSyncMonitor

    let onCreateNote: () -> Void
    let onTrashNote: (Note) -> Void
    let onRestoreNote: (Note) -> Void
    let onPermanentlyDeleteNote: (Note) -> Void
    let onEmptyTrash: () -> Void

    let onTogglePin: (Note) -> Void
    let onDuplicate: (Note) -> Void
    let onExportFile: (Note) -> Void
    let onExportMail: (Note) -> Void
    let onMoveNote: (Note, Folder?) -> Void

    let onCreateFolder: () -> Void
    let onCreateSubfolder: (Folder) -> Void
    let onRenameFolder: (Folder, String) -> Void
    let onDeleteFolder: (Folder) -> Void

    @State private var renamingFolder: Folder?
    @State private var renameText: String = ""
    @State private var deletingFolder: Folder?
    @State private var confirmingEmptyTrash = false

    var body: some View {
        VStack(spacing: 0) {
            foldersHeader
            foldersList
                .frame(maxHeight: 220)
            Divider()
            notesHeader
            notesList
            Divider()
            CloudSyncStatusView(monitor: syncMonitor)
        }
        .alert(
            "Rename Folder",
            isPresented: Binding(
                get: { renamingFolder != nil },
                set: { if !$0 { renamingFolder = nil } }
            )
        ) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { renamingFolder = nil }
            Button("Rename") {
                if let folder = renamingFolder {
                    onRenameFolder(folder, renameText)
                }
                renamingFolder = nil
            }
        }
        .confirmationDialog(
            deletingFolder.map { "Delete \"\($0.name)\"?" } ?? "Delete folder?",
            isPresented: Binding(
                get: { deletingFolder != nil },
                set: { if !$0 { deletingFolder = nil } }
            ),
            presenting: deletingFolder
        ) { folder in
            Button("Delete", role: .destructive) {
                onDeleteFolder(folder)
                deletingFolder = nil
            }
            Button("Cancel", role: .cancel) { deletingFolder = nil }
        } message: { _ in
            Text("Subfolders will be deleted permanently. Notes inside will be moved to Trash.")
        }
        .confirmationDialog(
            "Empty Trash?",
            isPresented: $confirmingEmptyTrash
        ) {
            Button("Empty Trash", role: .destructive) {
                onEmptyTrash()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(trashCount) note\(trashCount == 1 ? "" : "s") will be permanently deleted.")
        }
    }

    // MARK: Folders

    private var foldersHeader: some View {
        HStack(spacing: 8) {
            Text("Folders")
                .font(.headline)
            Spacer()
            Button(action: onCreateFolder) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.borderless)
            .help("New Folder")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var foldersList: some View {
        List(selection: $selectedScope) {
            Section {
                Label("All Notes", systemImage: "tray.full")
                    .tag(SidebarSelection.allNotes)
                OutlineGroup(rootFolders, children: \.optionalSortedChildren) { folder in
                    folderRow(folder)
                }
            }
            Section {
                HStack {
                    Label("Trash", systemImage: "trash")
                    Spacer()
                    if trashCount > 0 {
                        Text("\(trashCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(SidebarSelection.trash)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    private func folderRow(_ folder: Folder) -> some View {
        Label(folder.name, systemImage: "folder")
            .tag(SidebarSelection.folder(folder.id))
            .contextMenu {
                Button {
                    onCreateSubfolder(folder)
                } label: {
                    Label("New Subfolder", systemImage: "folder.badge.plus")
                }
                Button {
                    renameText = folder.name
                    renamingFolder = folder
                } label: {
                    Label("Rename…", systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive) {
                    deletingFolder = folder
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    // MARK: Notes

    private var currentScopeName: String {
        switch selectedScope {
        case .allNotes:
            return "All Notes"
        case .folder(let id):
            return allFolders.first(where: { $0.id == id })?.name ?? "Folder"
        case .trash:
            return "Trash"
        }
    }

    private var scopeIcon: String? {
        switch selectedScope {
        case .allNotes: return nil
        case .folder: return "folder.fill"
        case .trash: return "trash.fill"
        }
    }

    private var notesHeader: some View {
        HStack(spacing: 8) {
            if let icon = scopeIcon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(currentScopeName)
                .font(.headline)
                .lineLimit(1)
            if !notes.isEmpty {
                Text("\(notes.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(.tertiary.opacity(0.35)))
            }
            Spacer()
            if inTrash {
                if trashCount > 0 {
                    Button {
                        confirmingEmptyTrash = true
                    } label: {
                        Image(systemName: "trash.slash")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .help("Empty Trash")
                }
            } else {
                Button(action: onCreateNote) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.borderless)
                .help("New Note")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var notesList: some View {
        List(selection: $selectedNoteID) {
            ForEach(notes) { note in
                NotesListRow(note: note, inTrash: inTrash)
                    .tag(Optional(note.id))
                    .contextMenu {
                        if inTrash {
                            trashContextMenu(for: note)
                        } else {
                            normalContextMenu(for: note)
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .overlay {
            if notes.isEmpty {
                emptyState
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: inTrash ? "trash" : "tray")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.tertiary)
            Text(inTrash ? "Trash is empty" : "No notes here")
                .font(.callout)
                .foregroundStyle(.secondary)
            if !inTrash {
                Button(action: onCreateNote) {
                    Label("Create Note", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func normalContextMenu(for note: Note) -> some View {
        Button {
            onTogglePin(note)
        } label: {
            Label(
                note.isPinned ? "Unpin" : "Pin",
                systemImage: note.isPinned ? "pin.slash" : "pin"
            )
        }
        Button {
            onDuplicate(note)
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }
        moveToMenu(for: note)
        Menu {
            Button {
                onExportFile(note)
            } label: {
                Label("Save as Markdown…", systemImage: "doc.text")
            }
            Button {
                onExportMail(note)
            } label: {
                Label("Send via Mail…", systemImage: "envelope")
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        Divider()
        Button(role: .destructive) {
            onTrashNote(note)
        } label: {
            Label("Move to Trash", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func trashContextMenu(for note: Note) -> some View {
        Button {
            onRestoreNote(note)
        } label: {
            Label("Restore", systemImage: "arrow.uturn.backward")
        }
        Divider()
        Button(role: .destructive) {
            onPermanentlyDeleteNote(note)
        } label: {
            Label("Delete Permanently", systemImage: "trash.slash")
        }
    }

    private func moveToMenu(for note: Note) -> some View {
        Menu {
            Button {
                onMoveNote(note, nil)
            } label: {
                Label("No Folder", systemImage: "tray")
            }
            if !allFolders.isEmpty {
                Divider()
                ForEach(flattenedFolders(), id: \.folder.id) { item in
                    Button {
                        onMoveNote(note, item.folder)
                    } label: {
                        Text(String(repeating: "    ", count: item.depth) + item.folder.name)
                    }
                    .disabled(note.folder?.id == item.folder.id)
                }
            }
        } label: {
            Label("Move to", systemImage: "folder")
        }
    }

    private struct IndentedFolder {
        let folder: Folder
        let depth: Int
    }

    private func flattenedFolders() -> [IndentedFolder] {
        var result: [IndentedFolder] = []
        func walk(_ folders: [Folder], depth: Int) {
            let sorted = folders.sorted { $0.createdAt < $1.createdAt }
            for f in sorted {
                result.append(IndentedFolder(folder: f, depth: depth))
                walk(f.sortedChildren, depth: depth + 1)
            }
        }
        walk(allFolders.filter { $0.parent == nil }, depth: 0)
        return result
    }
}

private struct NotesListRow: View {
    let note: Note
    let inTrash: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: note.backgroundColorHex) ?? .gray)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle().stroke(Color.primary.opacity(0.18), lineWidth: 0.5)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(note.displayTitle)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(rowDate, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if note.isPinned && !inTrash {
                Spacer(minLength: 4)
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(45))
            }
        }
        .padding(.vertical, 3)
    }

    private var rowDate: Date {
        inTrash ? (note.trashedAt ?? note.updatedAt) : note.updatedAt
    }
}
