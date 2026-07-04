import SwiftUI
import AppKit

/// 编辑已有项目：name / path / command / port / tags。
struct EditProjectSheet: View {
    @Environment(ProcessManager.self) private var manager
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let projectID: UUID

    @State private var name: String
    @State private var path: String
    @State private var command: String
    @State private var port: String
    @State private var tags: String
    @State private var autoRestart: Bool

    init(project: Project) {
        self.projectID = project.id
        _name = State(initialValue: project.name)
        _path = State(initialValue: project.path)
        _command = State(initialValue: project.command)
        _port = State(initialValue: project.port.map(String.init) ?? "")
        _tags = State(initialValue: project.tags.joined(separator: ", "))
        _autoRestart = State(initialValue: project.autoRestart)
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !path.trimmingCharacters(in: .whitespaces).isEmpty
            && !command.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(settings.t("edit_process"))
                .font(.system(.title2, design: .monospaced)).bold()
                .foregroundStyle(Theme.text)

            field("name", text: $name, placeholder: "ark-us-vue/dev", icon: "textformat")

            HStack(spacing: 10) {
                field("path", text: $path, placeholder: "~/my-app", icon: "folder")
                Button { browse() } label: {
                    Label(settings.t("browse"), systemImage: "folder")
                        .font(.system(.callout, design: .monospaced))
                }
                .buttonStyle(GhostButtonStyle(tint: Theme.textDim))
            }

            field("cmd", text: $command, placeholder: "npm run dev", icon: "chevron.right")

            HStack(spacing: 10) {
                field("port", text: $port, placeholder: "5173", icon: "number")
                field("tags", text: $tags, placeholder: "逗号分隔，如 ark-us-vue", icon: "tag")
            }

            Toggle(isOn: $autoRestart) {
                Text(settings.t("auto_restart"))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Theme.text)
            }
            .toggleStyle(.switch)
            .tint(Theme.active)

            Divider()

            HStack(spacing: 10) {
                Button { submit() } label: {
                    Label(settings.t("save"), systemImage: "checkmark")
                }
                .buttonStyle(GhostButtonStyle(tint: canSubmit ? Theme.active : Theme.stopped))
                .disabled(!canSubmit)

                Button { dismiss() } label: {
                    Label(settings.t("cancel"), systemImage: "xmark")
                }
                .buttonStyle(GhostButtonStyle(tint: Theme.textDim))
            }
        }
        .padding(28)
        .frame(width: 560)
        .background(Theme.bg)
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { path = url.path }
    }

    private func submit() {
        let parsedTags = tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let edited = Project(
            name: name.trimmingCharacters(in: .whitespaces),
            path: path.trimmingCharacters(in: .whitespaces),
            command: command.trimmingCharacters(in: .whitespaces),
            port: Int(port.trimmingCharacters(in: .whitespaces)),
            tags: parsedTags,
            autoRestart: autoRestart
        )
        manager.update(id: projectID, with: edited)
        dismiss()
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.textDim)
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(Theme.textDim)
                TextField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Theme.text)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))
        }
    }
}
