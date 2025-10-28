//
//  SubtitleModeToggle.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import SwiftUI

/// 字幕顯示模式切換組件
struct SubtitleModeToggle: View {
    @ObservedObject var viewModel: AudioPlayerViewModel

    var body: some View {
        Picker("字幕模式", selection: Binding(
            get: { viewModel.displayMode },
            set: { viewModel.setDisplayMode($0) }
        )) {
            ForEach(SubtitleDisplayMode.allCases, id: \.self) { mode in
                Text(mode.description)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 200)
    }
}

/// 更精美的設計版本（可選）
struct SubtitleModeToggleStyled: View {
    @ObservedObject var viewModel: AudioPlayerViewModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SubtitleDisplayMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.setDisplayMode(mode)
                    }
                }) {
                    Text(mode.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(viewModel.displayMode == mode ? .white : .blue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewModel.displayMode == mode ? Color.blue : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 30) {
        // 預覽標準版本
        SubtitleModeToggle(viewModel: AudioPlayerViewModel())
            .padding()

        // 預覽精美版本
        SubtitleModeToggleStyled(viewModel: AudioPlayerViewModel())
            .padding()
    }
}
