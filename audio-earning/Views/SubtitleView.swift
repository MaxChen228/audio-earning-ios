//
//  SubtitleView.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import SwiftUI

/// 字幕顯示視圖，支援逐字標記
struct SubtitleView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    let text: String
    let isActive: Bool

    private var wordTokens: [SubtitleToken] {
        tokenize(text: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if wordTokens.isEmpty {
                Text("—")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                WordWrapLayout(spacing: 8) {
                    ForEach(wordTokens) { token in
                        HighlightableWordView(
                            text: token.display,
                            isHighlighted: viewModel.isWordHighlighted(token.display),
                            highlightAction: {
                                viewModel.highlightWord(token.display)
                            },
                            removeAction: {
                                viewModel.removeHighlight(token.display)
                            }
                        )
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.highlightedWords)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
        )
    }

    /// 將字幕字串拆成逐字陣列
    private func tokenize(text: String) -> [SubtitleToken] {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { SubtitleToken(display: $0) }
    }
}

/// 字幕容器視圖（帶時間顯示與逐字標記）
struct SubtitleContainerView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel

    var body: some View {
        VStack(spacing: 12) {
            timeBar

            if viewModel.displayMode == .sentenceLevel {
                SentenceWheelSubtitleView(viewModel: viewModel)
                    .frame(height: 320)
                    .padding(.horizontal)
            } else {
                SubtitleView(
                    viewModel: viewModel,
                    text: viewModel.currentSubtitleText,
                    isActive: !viewModel.currentSubtitleText.isEmpty
                )
                .padding(.horizontal)
            }
        }
    }

    private var timeBar: some View {
        HStack {
            Text(formatTime(viewModel.currentTime))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)

            Spacer()

            Text(formatTime(viewModel.totalDuration))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
    }

    /// 格式化時間 (MM:SS)
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - 輔助資料結構與子視圖

private struct SubtitleToken: Identifiable {
    let id = UUID()
    let display: String
}

private struct HighlightableWordView: View {
    let text: String
    let isHighlighted: Bool
    let highlightAction: () -> Void
    let removeAction: () -> Void

    private let highlightColor = Color.orange

    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(isHighlighted ? highlightColor : .primary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHighlighted ? highlightColor.opacity(0.15) : Color.clear)
            )
            .onLongPressGesture(minimumDuration: 0.25) {
                if !isHighlighted {
                    highlightAction()
                }
            }
            .onTapGesture {
                if isHighlighted {
                    removeAction()
                }
            }
    }
}

private struct WordWrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        let proposedWidth = proposal.width ?? .infinity
        var currentLineWidth: CGFloat = 0
        var currentLineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            if currentLineWidth + subviewSize.width > proposedWidth, currentLineWidth > 0 {
                totalHeight += currentLineHeight + spacing
                let effectiveWidth = max(0, currentLineWidth - spacing)
                maxRowWidth = max(maxRowWidth, effectiveWidth)
                currentLineWidth = 0
                currentLineHeight = 0
            }

            currentLineWidth += subviewSize.width + spacing
            currentLineHeight = max(currentLineHeight, subviewSize.height)
        }

        totalHeight += currentLineHeight
        let effectiveWidth = max(0, currentLineWidth - spacing)
        maxRowWidth = max(maxRowWidth, effectiveWidth)

        let widthLimit = proposedWidth.isFinite ? min(maxRowWidth, proposedWidth) : maxRowWidth
        return CGSize(width: widthLimit, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        guard !subviews.isEmpty else { return }

        let availableWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width - bounds.minX > availableWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(size)
            )

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct SentenceWheelSubtitleView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel

    @State private var isUserInteracting = false
    @State private var nearestSubtitleID: Int?

    fileprivate static let coordinateSpaceName = "SentenceWheelScroll"
    private let itemSpacing: CGFloat = 24

    var body: some View {
        GeometryReader { outerGeo in
            let containerHeight = max(outerGeo.size.height, 260)

            ScrollViewReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: itemSpacing) {
                            ForEach(viewModel.displayedSubtitles) { subtitle in
                                SentenceWheelRow(
                                    subtitle: subtitle,
                                    containerHeight: containerHeight,
                                    isActive: isSubtitleActive(subtitle.id),
                                    isFocused: isSubtitleFocused(subtitle.id),
                                    shouldTrackFocus: shouldTrackFocus,
                                    onTap: {
                                        handleTap(on: subtitle, proxy: proxy)
                                    }
                                )
                                .id(subtitle.id)
                            }
                        }
                        .padding(.vertical, containerHeight / 2)
                        .frame(maxWidth: .infinity)
                    }
                    .coordinateSpace(name: Self.coordinateSpaceName)
                    .mask(fadeMask)
                    .contentShape(Rectangle())
                    .gesture(dragGesture())
                    .onAppear {
                        nearestSubtitleID = viewModel.currentSubtitle?.id ?? viewModel.displayedSubtitles.first?.id
                        scrollToActiveSubtitle(proxy: proxy, animate: false)
                    }
                    .onChange(of: viewModel.currentSubtitle?.id) { _, newValue in
                        guard !isUserInteracting else { return }
                        nearestSubtitleID = newValue ?? nearestSubtitleID
                        scrollToActiveSubtitle(proxy: proxy, animate: true)
                    }
                    .onChange(of: viewModel.displayedSubtitles) { _, _ in
                        guard !viewModel.displayedSubtitles.isEmpty else { return }
                        DispatchQueue.main.async {
                            nearestSubtitleID = viewModel.currentSubtitle?.id ?? viewModel.displayedSubtitles.first?.id
                            scrollToActiveSubtitle(proxy: proxy, animate: false)
                        }
                    }
                    .onPreferenceChange(SubtitleOffsetPreferenceKey.self) { entries in
                        updateNearestSubtitle(with: entries)
                    }
                }
            }
        }
    }

    private var shouldTrackFocus: Bool {
        isUserInteracting || viewModel.playerState != .playing
    }

    private func dragGesture() -> some Gesture {
        DragGesture()
            .onChanged { _ in
                if !isUserInteracting {
                    isUserInteracting = true
                    viewModel.pauseForUserInteraction()
                }
            }
            .onEnded { _ in
                isUserInteracting = false
            }
    }

    private func handleTap(on subtitle: SubtitleItem, proxy: ScrollViewProxy) {
        viewModel.pauseForUserInteraction()
        viewModel.seek(to: subtitle.startTime, autoResume: false)
        nearestSubtitleID = subtitle.id

        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(subtitle.id, anchor: .center)
        }
    }

    private func isSubtitleActive(_ id: Int) -> Bool {
        viewModel.currentSubtitle?.id == id
    }

    private func isSubtitleFocused(_ id: Int) -> Bool {
        guard let focusID = nearestSubtitleID else { return false }
        return shouldTrackFocus && focusID == id
    }

    private func scrollToActiveSubtitle(proxy: ScrollViewProxy, animate: Bool) {
        guard !viewModel.displayedSubtitles.isEmpty else { return }

        let targetID = viewModel.currentSubtitle?.id ?? nearestSubtitleID ?? viewModel.displayedSubtitles.first?.id
        guard let targetID else { return }

        let action = {
            proxy.scrollTo(targetID, anchor: .center)
        }

        if animate {
            withAnimation(.easeInOut(duration: 0.35)) {
                action()
            }
        } else {
            action()
        }
    }

    private func updateNearestSubtitle(with entries: [SubtitleOffsetEntry]) {
        guard shouldTrackFocus else { return }
        guard !entries.isEmpty else { return }

        if let closest = entries.min(by: { abs($0.offset) < abs($1.offset) }) {
            nearestSubtitleID = closest.id
        }
    }

    private var fadeMask: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .white, location: 0.18),
                .init(color: .white, location: 0.82),
                .init(color: .clear, location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct SubtitleOffsetEntry: Equatable {
    let id: Int
    let offset: CGFloat
}

private struct SubtitleOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [SubtitleOffsetEntry] = []

    static func reduce(value: inout [SubtitleOffsetEntry], nextValue: () -> [SubtitleOffsetEntry]) {
        value.append(contentsOf: nextValue())
    }
}

private struct SentenceWheelRow: View {
    let subtitle: SubtitleItem
    let containerHeight: CGFloat
    let isActive: Bool
    let isFocused: Bool
    let shouldTrackFocus: Bool
    let onTap: () -> Void

    @State private var offset: CGFloat = .zero

    var body: some View {
        let radius = max(containerHeight / 2, 1)
        let normalised = min(abs(offset) / radius, 1)
        let baseScale = 1 - normalised * 0.22
        let baseOpacity = 1 - normalised * 0.55
        let rotation = Double(offset / radius) * 35

        let emphasized = isActive || isFocused
        let scale = emphasized ? max(1.05, baseScale) : max(0.85, baseScale)
        let opacity = emphasized ? 1.0 : max(0.25, baseOpacity)
        let fontSize: CGFloat = emphasized ? 22 : 18
        let fontWeight: Font.Weight = emphasized ? .semibold : .medium

        Text(subtitle.text)
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundColor(Color.primary.opacity(opacity))
            .multilineTextAlignment(.center)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.accentColor.opacity(emphasized ? 0.22 : 0.06))
            )
            .scaleEffect(scale)
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: 1, y: 0, z: 0),
                anchor: .center,
                perspective: 0.9
            )
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: SubtitleOffsetPreferenceKey.self,
                            value: preferenceValue(for: computeOffset(in: geo))
                        )
                        .onAppear {
                            updateOffsetIfNeeded(computeOffset(in: geo))
                        }
                        .onChange(of: computeOffset(in: geo)) { _, newValue in
                            updateOffsetIfNeeded(newValue)
                        }
                }
            )
            .onTapGesture {
                onTap()
            }
            .animation(.easeInOut(duration: 0.2), value: emphasized)
            .animation(.easeInOut(duration: 0.2), value: offset)
    }
}

private extension SentenceWheelRow {
    func computeOffset(in geo: GeometryProxy) -> CGFloat {
        let frame = geo.frame(in: .named(SentenceWheelSubtitleView.coordinateSpaceName))
        let centerY = containerHeight / 2
        return frame.midY - centerY
    }

    func updateOffsetIfNeeded(_ newValue: CGFloat) {
        guard newValue.isFinite else { return }
        if abs(offset - newValue) > 0.5 {
            offset = newValue
        }
    }

    func preferenceValue(for offsetValue: CGFloat) -> [SubtitleOffsetEntry] {
        guard shouldTrackFocus else { return [] }
        return [SubtitleOffsetEntry(id: subtitle.id, offset: offsetValue)]
    }
}

#Preview {
    VStack(spacing: 20) {
        let previewViewModel = AudioPlayerViewModel()
        SubtitleView(
            viewModel: previewViewModel,
            text: "Welcome to the storytelling series!",
            isActive: true
        )
        .padding()

        SubtitleView(
            viewModel: previewViewModel,
            text: "This is a longer subtitle that demonstrates how the text wraps when it's too long for a single line.",
            isActive: true
        )
        .padding()

        SubtitleView(
            viewModel: previewViewModel,
            text: "",
            isActive: false
        )
        .padding()

        SubtitleContainerView(viewModel: previewContainerViewModel)
    }
}

private let previewContainerViewModel: AudioPlayerViewModel = {
    let viewModel = AudioPlayerViewModel()
    viewModel.totalDuration = 360.0
    viewModel.currentTime = 125.5
    viewModel.currentSubtitleText = "Learning English is fun!"
    return viewModel
}()
