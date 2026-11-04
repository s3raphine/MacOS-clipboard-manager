import SwiftUI
import AppKit

struct ClipboardItemRow: View {
    @EnvironmentObject var monitor: ClipboardMonitor
    let item: ClipboardItem
    let isHovered: Bool
    let isSelected: Bool

    private static let tileSize: CGFloat = 34
    private static let tileShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

    var body: some View {
        HStack(spacing: 10) {
            iconView

            VStack(alignment: .leading, spacing: 2) {
                Text(item.previewText)
                    .font(item.type == .color
                          ? .system(size: 13, weight: .medium, design: .monospaced)
                          : .system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text("\(item.kindLabel) · \(item.relativeTime(now: context.date))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            if isHovered {
                HStack(spacing: 4) {
                    actionButton(
                        icon: item.isPinned ? "pin.slash.fill" : "pin.fill",
                        label: item.isPinned ? "Unpin" : "Pin",
                        tint: item.isPinned ? .orange : .secondary
                    ) {
                        monitor.togglePin(item)
                    }
                    actionButton(icon: "trash.fill", label: "Delete", tint: .secondary) {
                        monitor.delete(item)
                    }
                }
            } else if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(rowFill)
        )
        .contentShape(Rectangle())
    }

    private var rowFill: Color {
        if isSelected { return Color.accentColor.opacity(0.2) }
        return isHovered ? Color.primary.opacity(0.06) : .clear
    }

    @ViewBuilder
    private var iconView: some View {
        switch item.type {
        case .color:
            Self.tileShape
                .fill(item.swiftUIColor ?? .gray)
                .frame(width: Self.tileSize, height: Self.tileSize)
                .overlay(Self.tileShape.strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
        case .image:
            if let thumbnail = item.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: Self.tileSize, height: Self.tileSize)
                    .clipShape(Self.tileShape)
                    .overlay(Self.tileShape.strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
            } else {
                iconBadge(systemName: "photo", color: .purple)
            }
        case .url:
            iconBadge(systemName: "link", color: .blue)
        case .text:
            iconBadge(systemName: "text.alignleft", color: .gray)
        case .file:
            iconBadge(systemName: "doc.fill", color: .teal)
        }
    }

    private func iconBadge(systemName: String, color: Color) -> some View {
        Self.tileShape
            .fill(color.opacity(0.16))
            .frame(width: Self.tileSize, height: Self.tileSize)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color)
            )
    }

    private func actionButton(icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(Color.primary.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}
