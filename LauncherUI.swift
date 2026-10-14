import SwiftUI
import AppKit

struct PuntoLauncherView: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let coral = Color(red: 0.98, green: 0.36, blue: 0.40)
    private let names = ["Up", "Right", "Down", "Left"]

    var body: some View {
        // Keep one stable animation clock; changing selection never replaces tile hosts.
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !model.launcherVisible)) { _ in
            VStack(spacing: 6) {
                direction(0)
                HStack(spacing: 0) {
                    direction(3)
                    Color.clear.frame(width: 76, height: 64).accessibilityHidden(true)
                    direction(1)
                }
                direction(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundColor(.white).preferredColorScheme(.dark)
        }
    }

    @ViewBuilder private func direction(_ index: Int) -> some View {
        if index == 0 || index == 2 {
            VStack(spacing: 6) { tiles(index) }
        } else {
            HStack(spacing: 6) { tiles(index) }
        }
    }

    private func tiles(_ index: Int) -> some View {
        Group {
            // Slot 1 is nearest the center; slot 2 extends outward.
            ForEach(index == 0 || index == 3 ? [1, 0] : [0, 1], id: \.self) { slot in
                let selected = model.launcherDirection == index && model.launcherSlot == slot
                tile(index, slot: slot, selected: selected, now: ProcessInfo.processInfo.systemUptime)
            }
        }
    }

    private func tile(_ index: Int, slot: Int, selected: Bool, now: Double) -> some View {
        let path = model.launcherApps[index][slot]
        let title = path.isEmpty ? "—" : FileManager.default.displayName(atPath: path)
        let elapsed = now - model.launcherOpenedTime
        let pulse = selected && model.launcherOpenedTime > 0 && elapsed >= 0 && elapsed < 0.28
            ? sin(.pi * elapsed / 0.28) : 0.0
        return VStack(spacing: 5) {
            if path.isEmpty {
                Image(systemName: "plus.app")
                    .font(.system(size: 25, weight: .ultraLight))
                    .foregroundColor(.white.opacity(0.25)).frame(height: 28)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable().scaledToFit().frame(width: 28, height: 28)
            }
            Text(title).font(.system(size: 9, weight: selected ? .semibold : .regular))
                .lineLimit(1).foregroundColor(.white.opacity(path.isEmpty ? 0.35 : 0.90))
                .frame(maxWidth: .infinity).padding(.horizontal, 4)
        }
        .frame(width: 64, height: 64)
        .background {
            RoundedRectangle(cornerRadius: 9).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 9).fill(Color.black.opacity(0.40))
            RoundedRectangle(cornerRadius: 9).fill(selected ? coral.opacity(0.16 + pulse * 0.14) : .white.opacity(0.04))
        }
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(selected ? coral.opacity(0.28) : .white.opacity(0.09), lineWidth: selected ? 1.5 : 1))
        .scaleEffect(reduceMotion ? 1 : 1 + pulse * 0.045)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(names[index]), app \(slot + 1): \(path.isEmpty ? "Empty slot" : title)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
