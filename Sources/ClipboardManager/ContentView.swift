import SwiftUI
import AppKit

final class ViewValue<Value>: ObservableObject {
    @Published var value: Value
    init(_ value: Value) { self.value = value }
}

struct ContentView: View {
    @EnvironmentObject var monitor: ClipboardMonitor
    @StateObject private var hoveredItemID = ViewValue<UUID?>(nil)
    @StateObject private var confirmingClear = ViewValue(false)
    @FocusState private var searchFocused: Bool

    let onClose: () -> Void

    private static let cornerRadius: CGFloat = 16

    var body: some View {
        let visible = monitor.filteredItems

        VStack(spacing: 0) {
            header
            searchBar
            Divider().opacity(0.6)

            if visible.isEmpty {
                emptyState
            } else {
                itemList(visible)
            }

            Divider().opacity(0.6)
            footer
        }
        .frame(width: 400, height: 520)
        .background(PanelBackground(cornerRadius: Self.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
        .onAppear {
            DispatchQueue.main.async { searchFocused = true }
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 26, height: 26)
            Text("Clipboard")
                .font(.system(size: 15, weight: .semibold))
            if !monitor.items.isEmpty {
                Text("\(monitor.items.count)")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08), in: Capsule())
            }
            Spacer()
            KeyCap("⌘⇧V")
        }
        .padding(.horizontal, 14)
        .padding(.top, 13)
        .padding(.bottom, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13, weight: .medium))
            TextField("Search your clipboard…", text: $monitor.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
            if !monitor.searchQuery.isEmpty {
                Button {
                    monitor.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private func itemList(_ visible: [ClipboardItem]) -> some View {
        let pinned = visible.filter(\.isPinned)
        let recent = visible.filter { !$0.isPinned }
        let selectedID = monitor.selectedItem?.id

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if !pinned.isEmpty {
                        sectionTitle("Pinned")
                        rows(pinned, selectedID: selectedID)
                        if !recent.isEmpty { sectionTitle("Recent") }
                    }
                    rows(recent, selectedID: selectedID)
                }
                .padding(8)
            }
            .onChange(of: monitor.selectedID) { id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }

    private func rows(_ items: [ClipboardItem], selectedID: UUID?) -> some View {
        ForEach(items) { item in
            ClipboardItemRow(
                item: item,
                isHovered: hoveredItemID.value == item.id,
                isSelected: selectedID == item.id
            )
            .id(item.id)
            .onHover { hovering in
                if hovering {
                    hoveredItemID.value = item.id
                } else if hoveredItemID.value == item.id {
                    hoveredItemID.value = nil
                }
            }
            .onTapGesture {
                monitor.copyToClipboard(item)
                onClose()
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }

    private var emptyState: some View {
        let searching = !monitor.searchQuery.isEmpty

        return VStack(spacing: 8) {
            Spacer()
            Image(systemName: searching ? "magnifyingglass" : "doc.on.clipboard")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 4)
            Text(searching ? "No results" : "Nothing copied yet")
                .font(.system(size: 13, weight: .semibold))
            Text(searching ? "Try a different search." : "Everything you copy will show up here.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 10) {
            if confirmingClear.value {
                Text("Clear all unpinned items?")
                    .font(.system(size: 11.5, weight: .medium))
                Spacer()
                Button("Cancel") { confirmingClear.value = false }
                    .controlSize(.small)
                Button("Clear", role: .destructive) {
                    monitor.clearHistory(keepPinned: true)
                    confirmingClear.value = false
                }
                .controlSize(.small)
            } else {
                KeyHint(key: "↩", label: "Copy")
                KeyHint(key: "⌘P", label: "Pin")
                KeyHint(key: "⌘⌫", label: "Delete")
                Spacer()
                FooterIconButton(systemName: "trash", label: "Clear history") {
                    confirmingClear.value = true
                }
                .disabled(!monitor.items.contains { !$0.isPinned })
                FooterIconButton(systemName: "power", label: "Quit Clipboard Manager") {
                    NSApp.terminate(nil)
                }
            }
        }
        .frame(height: 24)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}

private struct PanelBackground: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.maskImage = Self.mask(radius: cornerRadius)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}

    private static func mask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

private struct KeyCap: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct KeyHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            KeyCap(key)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

private struct FooterIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @StateObject private var isHovered = ViewValue(false)

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered.value && isEnabled ? .primary : .secondary)
                .frame(width: 24, height: 24)
                .background(
                    Color.primary.opacity(isHovered.value && isEnabled ? 0.08 : 0),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { isHovered.value = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}
