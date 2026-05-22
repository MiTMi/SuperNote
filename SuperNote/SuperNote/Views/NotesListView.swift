import SwiftUI

struct NotesListView: View {
    let notes: [Note]
    @Binding var selectedID: UUID?
    let onCreate: () -> Void
    let onDelete: (Note) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            list
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Notes")
                .font(.headline)
            if !notes.isEmpty {
                Text("\(notes.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(.tertiary.opacity(0.35))
                    )
            }
            Spacer()
            Button(action: onCreate) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.borderless)
            .help("New Note")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var list: some View {
        List(selection: $selectedID) {
            ForEach(notes) { note in
                NotesListRow(note: note)
                    .tag(note.id)
                    .contextMenu {
                        Button(role: .destructive) {
                            onDelete(note)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .onDelete { offsets in
                for index in offsets {
                    onDelete(notes[index])
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .overlay {
            if notes.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("No notes yet")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button(action: onCreate) {
                        Label("Create Note", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding()
            }
        }
    }
}

private struct NotesListRow: View {
    let note: Note

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
                Text(note.updatedAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}
