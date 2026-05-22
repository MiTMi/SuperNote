import SwiftData
import SwiftUI

struct NoteEditorView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var modelContext

    static let palette: [String] = [
        "#FFF8B8", "#FFD8A8", "#FFB8B8", "#E0C8FF",
        "#B8D8FF", "#B8F0E0", "#D8F0B8", "#FFFFFF",
        "#2A2A2A"
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            editor
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: note.body) { _, _ in
            note.updatedAt = .now
            try? modelContext.save()
        }
    }

    private var header: some View {
        HStack {
            Text(note.updatedAt, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
            ColorChipPicker(
                selectedHex: note.backgroundColorHex,
                palette: Self.palette
            ) { newHex in
                note.backgroundColorHex = newHex
                note.updatedAt = .now
                try? modelContext.save()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.6)
        }
    }

    private var editor: some View {
        ZStack {
            Color(hex: note.backgroundColorHex) ?? Color(nsColor: .windowBackgroundColor)
            MarkdownTextView(text: $note.body, backgroundHex: note.backgroundColorHex)
        }
    }
}

private struct ColorChipPicker: View {
    let selectedHex: String
    let palette: [String]
    let onSelect: (String) -> Void

    @State private var isShowing = false

    var body: some View {
        Button {
            isShowing.toggle()
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(hex: selectedHex) ?? .gray)
                    .frame(width: 18, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.primary.opacity(0.22), lineWidth: 0.5)
                    )
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(.quaternary.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(.tertiary.opacity(0.5), lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help("Background color")
        .popover(isPresented: $isShowing, arrowEdge: .top) {
            paletteGrid
                .padding(12)
        }
    }

    private var paletteGrid: some View {
        let columns = Array(repeating: GridItem(.fixed(28), spacing: 10), count: 5)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Background")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(palette, id: \.self) { hex in
                    ColorSwatch(
                        hex: hex,
                        isSelected: hex.uppercased() == selectedHex.uppercased()
                    ) {
                        onSelect(hex)
                        isShowing = false
                    }
                }
            }
            .frame(width: 28 * 5 + 10 * 4)
        }
    }
}

private struct ColorSwatch: View {
    let hex: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(hex: hex) ?? .gray)
                    .frame(width: 26, height: 26)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.5)
                    )
                if isSelected {
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .frame(width: 32, height: 32)
                }
            }
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
