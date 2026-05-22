import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Note.updatedAt, order: .reverse)]) private var notes: [Note]
    @State private var selectedID: UUID?

    var body: some View {
        NavigationSplitView {
            NotesListView(notes: notes, selectedID: $selectedID, onCreate: createNote, onDelete: deleteNote)
                .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 280)
        } detail: {
            if let note = currentNote {
                NoteEditorView(note: note)
                    .id(note.id)
            } else {
                EmptyEditorPlaceholder(onCreate: createNote)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 560, minHeight: 440)
        .background(.ultraThinMaterial)
        .onAppear {
            if selectedID == nil {
                selectedID = notes.first?.id
            }
        }
    }

    private var currentNote: Note? {
        guard let selectedID else { return notes.first }
        return notes.first(where: { $0.id == selectedID })
    }

    private func createNote() {
        let note = Note()
        modelContext.insert(note)
        try? modelContext.save()
        selectedID = note.id
    }

    private func deleteNote(_ note: Note) {
        let wasSelected = note.id == selectedID
        modelContext.delete(note)
        try? modelContext.save()
        if wasSelected {
            selectedID = notes.first(where: { $0.id != note.id })?.id
        }
    }
}

private struct EmptyEditorPlaceholder: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "note.text")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No note selected")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            Button(action: onCreate) {
                Label("New Note", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    RootView()
        .modelContainer(for: Note.self, inMemory: true)
        .frame(width: 520, height: 420)
}
