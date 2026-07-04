import SwiftUI

/// 新建/编辑启动 profile：命名 + 勾选项目 + 拖拽调启动顺序。
struct ProfileEditorSheet: View {
    @Environment(ProcessManager.self) private var manager
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    private let profileID: UUID
    @State private var name: String
    @State private var orderedIDs: [UUID]      // 所有项目，按显示顺序
    @State private var selected: Set<UUID>

    private var zh: Bool { settings.resolvedLanguage == .zh }

    init(profile: Profile, all: [ManagedProcess]) {
        profileID = profile.id
        _name = State(initialValue: profile.name)
        let inProfile = profile.projectIDs.filter { id in all.contains { $0.id == id } }
        let rest = all.map(\.id).filter { !inProfile.contains($0) }
        _orderedIDs = State(initialValue: inProfile + rest)
        _selected = State(initialValue: Set(inProfile))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selected.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(zh ? "启动组合" : "Startup profile")
                .font(.system(.title2, design: .monospaced)).bold()
                .foregroundStyle(Theme.text)

            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up").foregroundStyle(Theme.textDim)
                TextField(zh ? "组合名，如 全栈调试" : "profile name, e.g. Full-stack", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Theme.text)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Theme.surface).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))

            Text(zh ? "勾选项目 · 拖拽调启动顺序" : "Pick projects · drag to set start order")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.textDim)

            List {
                ForEach(orderedIDs, id: \.self) { id in
                    if let proc = manager.process(for: id) {
                        row(proc)
                    }
                }
                .onMove { from, to in orderedIDs.move(fromOffsets: from, toOffset: to) }
            }
            .listStyle(.plain)
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))

            Divider()

            HStack(spacing: 10) {
                Button { save() } label: {
                    Label(settings.t("save"), systemImage: "checkmark")
                }
                .buttonStyle(GhostButtonStyle(tint: canSave ? Theme.active : Theme.stopped))
                .disabled(!canSave)

                if manager.profiles.contains(where: { $0.id == profileID }) {
                    Button {
                        manager.deleteProfile(id: profileID); dismiss()
                    } label: {
                        Label(zh ? "删除" : "delete", systemImage: "trash")
                    }
                    .buttonStyle(GhostButtonStyle(tint: Theme.stopped))
                }

                Spacer()

                Button { dismiss() } label: {
                    Label(settings.t("cancel"), systemImage: "xmark")
                }
                .buttonStyle(GhostButtonStyle(tint: Theme.textDim))
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(Theme.bg)
    }

    private func row(_ proc: ManagedProcess) -> some View {
        HStack(spacing: 10) {
            Image(systemName: selected.contains(proc.id) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selected.contains(proc.id) ? Theme.active : Theme.textDim)
            Text(proc.project.name)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(Theme.text)
            Spacer()
            if let tag = proc.project.tags.first {
                Text(tag).font(.system(.caption2, design: .monospaced)).foregroundStyle(Theme.textDim)
            }
            Image(systemName: "line.3.horizontal").foregroundStyle(Theme.textDim.opacity(0.6))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if selected.contains(proc.id) { selected.remove(proc.id) } else { selected.insert(proc.id) }
        }
        .listRowBackground(Color.clear)
    }

    private func save() {
        let ids = orderedIDs.filter { selected.contains($0) }
        var p = Profile(id: profileID, name: name.trimmingCharacters(in: .whitespaces), projectIDs: ids)
        p.name = name.trimmingCharacters(in: .whitespaces)
        manager.saveProfile(p)
        dismiss()
    }
}
