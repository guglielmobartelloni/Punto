import SwiftUI
import AppKit

struct PuntoLauncherView: View {
    @ObservedObject var model: SettingsModel
    private let coral = Color(red: 0.98, green: 0.36, blue: 0.40)
    private let names = ["Up", "Right", "Down", "Left"]
    private let arrows = ["↑", "→", "↓", "←"]
    private var selectedPath: String {
        guard (0..<4).contains(model.launcherDirection), (0..<2).contains(model.launcherSlot) else { return "" }
        return model.launcherApps[model.launcherDirection][model.launcherSlot]
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.40))
                RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1)
                VStack {
                    HStack {
                        Text("PUNTO").font(.system(size: 10, weight: .semibold)).tracking(2)
                        Spacer()
                        Text("LAUNCHER").font(.system(size: 10, weight: .medium)).tracking(2).foregroundColor(.white.opacity(0.45))
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Label("Auto", systemImage: "bolt.fill").foregroundColor(.white.opacity(0.55))
                        Button { model.controller.hideLauncher() } label: {
                            HStack(spacing: 7) { Text("○"); Text("Dismiss") }
                        }
                        Spacer()
                        Text("Same direction: switch app")
                            .font(.system(size: 9)).foregroundColor(.white.opacity(0.45))
                    }.font(.system(size: 10, weight: .medium)).buttonStyle(.plain)
                }.padding(18)
                direction(0).position(x: geometry.size.width / 2, y: geometry.size.height * 0.20)
                direction(1).position(x: geometry.size.width * 0.81, y: geometry.size.height / 2)
                direction(2).position(x: geometry.size.width / 2, y: geometry.size.height * 0.80)
                direction(3).position(x: geometry.size.width * 0.19, y: geometry.size.height / 2)
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller").font(.system(size: 20, weight: .light)).foregroundColor(.white.opacity(0.65))
                    if selectedPath.isEmpty {
                        Text("No app assigned").font(.system(size: 11, weight: .medium))
                        Text("Choose apps in\nLauncher settings")
                            .font(.system(size: 9)).foregroundColor(.white.opacity(0.45)).multilineTextAlignment(.center).lineSpacing(2)
                    } else {
                        Text(FileManager.default.displayName(atPath: selectedPath)).font(.system(size: 12, weight: .medium)).lineLimit(2).multilineTextAlignment(.center)
                        Text("OPENED").font(.system(size: 8, weight: .semibold)).tracking(1).foregroundColor(.white.opacity(0.45))
                    }
                }.frame(width: 110).position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }.foregroundColor(.white).preferredColorScheme(.dark)
            .animation(.easeOut(duration: 0.12), value: model.launcherDirection)
            .animation(.easeOut(duration: 0.12), value: model.launcherSlot)
    }
    private func direction(_ index: Int) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Text(arrows[index]).font(.system(size: 12, weight: .medium))
                Text(names[index].uppercased()).font(.system(size: 9, weight: .medium)).tracking(1.5)
            }.foregroundColor(model.launcherDirection == index ? coral : .white.opacity(0.45))
            HStack(spacing: 7) {
                ForEach(0..<2, id: \.self) { slot in
                    let path = model.launcherApps[index][slot]
                    let selected = model.launcherDirection == index && model.launcherSlot == slot
                    VStack(spacing: 5) {
                        if path.isEmpty {
                            Image(systemName: "plus.app").font(.system(size: 25, weight: .ultraLight)).foregroundColor(.white.opacity(0.25)).frame(height: 28)
                        } else {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().scaledToFit().frame(width: 28, height: 28)
                        }
                        Text(path.isEmpty ? "Empty slot" : FileManager.default.displayName(atPath: path))
                            .font(.system(size: 9, weight: selected ? .semibold : .regular)).lineLimit(1).foregroundColor(path.isEmpty ? .white.opacity(0.35) : .white.opacity(0.90))
                    }.frame(width: 68, height: 62)
                        .background(selected ? coral.opacity(0.16) : .white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(selected ? coral : .white.opacity(0.09), lineWidth: selected ? 1.5 : 1))
                        .overlay(alignment: .topTrailing) {
                            Text("\(slot + 1)").font(.system(size: 8, weight: .medium)).foregroundColor(.white.opacity(selected ? 0.8 : 0.25)).padding(6)
                        }
                }
            }
        }.frame(width: 152)
    }
}
