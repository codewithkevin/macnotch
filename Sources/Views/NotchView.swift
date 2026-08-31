import SwiftUI
import UniformTypeIdentifiers

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel

    private var collapsedWidth: CGFloat { max(viewModel.metrics.notchWidth, 180) }
    private var collapsedHeight: CGFloat { max(viewModel.metrics.notchHeight, 28) }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                NotchShape(cornerRadius: viewModel.isExpanded ? 22 : 10)
                    .fill(.black)
                    .shadow(color: .black.opacity(viewModel.isExpanded ? 0.35 : 0),
                            radius: 18, y: 8)

                if viewModel.isExpanded {
                    ExpandedContent(viewModel: viewModel)
                        .padding(.horizontal, 22)
                        .padding(.top, collapsedHeight)
                        .padding(.bottom, 18)
                        .transition(.opacity)
                } else {
                    CollapsedContent(viewModel: viewModel)
                        .frame(height: collapsedHeight)
                }
            }
            .frame(width: viewModel.isExpanded ? viewModel.metrics.expandedSize.width : collapsedWidth,
                   height: viewModel.isExpanded ? viewModel.metrics.expandedSize.height : collapsedHeight)
            .contentShape(Rectangle())
            .onHover { hovering in
                viewModel.setExpanded(hovering)
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    viewModel.addToShelf([url])
                    viewModel.setExpanded(true)
                }
            }
        }
        return true
    }
}

private struct CollapsedContent: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        HStack {
            Image(systemName: "music.note")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(viewModel.now, format: .dateTime.hour().minute())
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 14)
    }
}

private struct ExpandedContent: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.now, format: .dateTime.weekday(.wide))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Text(viewModel.now, format: .dateTime.hour().minute().second())
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            Divider().overlay(.white.opacity(0.15))

            ShelfView(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct ShelfView: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Shelf").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                if !viewModel.shelfItems.isEmpty {
                    Button("Clear") { viewModel.clearShelf() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            if viewModel.shelfItems.isEmpty {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                    .foregroundStyle(.white.opacity(0.2))
                    .overlay(
                        Text("Drop files here")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.shelfItems, id: \.self) { url in
                            ShelfChip(url: url)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ShelfChip: View {
    let url: URL

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 34, height: 34)
            Text(url.lastPathComponent)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .frame(maxWidth: 60)
        }
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
    }
}

/// A rounded-bottom shape that visually merges with the top edge of the screen.
struct NotchShape: Shape {
    var cornerRadius: CGFloat

    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(cornerRadius, rect.height / 2)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                          control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
