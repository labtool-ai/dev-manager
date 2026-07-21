import SwiftUI
import AppKit

/// 新建项目面板：一个文件夹 + 多条命令（各自成为一个项目，共享 path 和 tag）。
struct AddProjectSheet: View {
    @Environment(ProcessManager.self) private var manager
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var path: String = ""
    @State private var tag: String = ""
    @State private var commands: [CommandDraft] = [CommandDraft()]
    @State private var detected: PackageScripts.Detected?

    private var folderName: String {
        let expanded = (path as NSString).expandingTildeInPath
        let name = (expanded as NSString).lastPathComponent
        return name.isEmpty ? "…" : name
    }

    private var validCommands: [CommandDraft] {
        commands.filter { !$0.command.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var canSubmit: Bool {
        !path.trimmingCharacters(in: .whitespaces).isEmpty && !validCommands.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(settings.t("add_new_process"))
                .font(.system(.title2, design: .monospaced)).bold()
                .foregroundStyle(Theme.text)

            // 文件夹
            HStack(spacing: 10) {
                fieldBox {
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .foregroundStyle(Theme.textDim)
                        TextField("~/my-app or browse →", text: $path)
                            .textFieldStyle(.plain)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(Theme.text)
                    }
                }
                Button {
                    browseForFolder()
                } label: {
                    Label(settings.t("browse"), systemImage: "folder")
                        .font(.system(.callout, design: .monospaced))
                }
                .buttonStyle(GhostButtonStyle(tint: Theme.textDim))
            }

            // 检测到的 package.json 脚本 → 点一下加成命令
            if let d = detected {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel(settings.resolvedLanguage == .zh
                                 ? "检测到 package.json 脚本 · \(d.manager)"
                                 : "package.json scripts · \(d.manager)")
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(d.scripts, id: \.name) { s in
                            Button { addCommand(s.command) } label: {
                                Text(s.name)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(Theme.text)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Theme.activeBg, in: Capsule())
                                    .overlay(Capsule().stroke(Theme.border))
                            }
                            .buttonStyle(.hit)
                            .help(s.command)
                        }
                    }
                }
            }

            // 命令
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel(settings.t("commands"))

                ForEach($commands) { $cmd in
                    HStack(spacing: 8) {
                        fieldBox {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.right")
                                    .font(.caption).foregroundStyle(Theme.textDim)
                                TextField("npm run dev", text: $cmd.command)
                                    .textFieldStyle(.plain)
                                    .font(.system(.callout, design: .monospaced))
                                    .foregroundStyle(Theme.text)
                            }
                        }
                        fieldBox {
                            HStack(spacing: 4) {
                                Text(":").foregroundStyle(Theme.textDim)
                                TextField("port", text: $cmd.port)
                                    .textFieldStyle(.plain)
                                    .frame(width: 52)
                            }
                            .font(.system(.callout, design: .monospaced))
                        }
                        .frame(width: 96)

                        Button {
                            commands.removeAll { $0.id == cmd.id }
                            if commands.isEmpty { commands = [CommandDraft()] }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption).foregroundStyle(Theme.textDim)
                        }
                        .buttonStyle(.hit)
                        .frame(width: 28, height: 28)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                    }
                }

                Text("\(settings.t("name_auto")): \(folderName)/\(validCommands.first?.autoSuffix ?? "…")")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.textDim)

                Button {
                    commands.append(CommandDraft())
                } label: {
                    Label(settings.t("add_command"), systemImage: "plus")
                        .font(.system(.caption, design: .monospaced))
                }
                .buttonStyle(GhostButtonStyle(tint: Theme.textDim))
            }

            // tag（同一个 app 的前后端打同一个 tag → 归到一组）
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel(settings.t("tag_hint"))
                fieldBox {
                    HStack(spacing: 8) {
                        Image(systemName: "tag")
                            .foregroundStyle(Theme.textDim)
                        TextField("ark-us-vue", text: $tag)
                            .textFieldStyle(.plain)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(Theme.text)
                    }
                }
            }

            Divider()

            HStack(spacing: 10) {
                Button {
                    submit()
                } label: {
                    Label("\(settings.t("add_command_verb")) \(validCommands.count)", systemImage: "terminal")
                }
                .buttonStyle(GhostButtonStyle(tint: canSubmit ? Theme.active : Theme.stopped))
                .disabled(!canSubmit)

                Button {
                    dismiss()
                } label: {
                    Label(settings.t("cancel"), systemImage: "xmark")
                }
                .buttonStyle(GhostButtonStyle(tint: Theme.textDim))
            }
        }
        .padding(28)
        .frame(width: 560)
        .background(Theme.bg)
        .onChange(of: path) { _, _ in refreshDetected() }
        .onAppear { refreshDetected() }
    }

    // MARK: - Actions

    private func browseForFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
            refreshDetected()
        }
    }

    private func refreshDetected() {
        detected = PackageScripts.detect(atFolder: path)
        // 有 package.json 且没填 tag 时，用文件夹名预填 tag
        if detected != nil, tag.trimmingCharacters(in: .whitespaces).isEmpty {
            tag = folderName
        }
    }

    /// 点脚本 → 优先填第一个空命令，否则追加一条
    private func addCommand(_ command: String) {
        if let i = commands.firstIndex(where: { $0.command.trimmingCharacters(in: .whitespaces).isEmpty }) {
            commands[i].command = command
        } else {
            var d = CommandDraft()
            d.command = command
            commands.append(d)
        }
    }

    private func submit() {
        let trimmedTag = tag.trimmingCharacters(in: .whitespaces)
        let tags = trimmedTag.isEmpty ? [] : [trimmedTag]
        let newProjects: [Project] = validCommands.map { draft in
            Project(
                name: "\(folderName)/\(draft.autoSuffix)",
                path: path,
                command: draft.command.trimmingCharacters(in: .whitespaces),
                port: Int(draft.port.trimmingCharacters(in: .whitespaces)),
                tags: tags
            )
        }
        manager.addProjects(newProjects)
        dismiss()
    }

    // MARK: - 小组件

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Theme.textDim)
    }

    private func fieldBox<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))
    }
}

/// 一条命令草稿
struct CommandDraft: Identifiable {
    let id = UUID()
    var command: String = ""
    var port: String = ""

    /// 从命令推断名字后缀：npm run dev → dev；uvicorn app → uvicorn
    var autoSuffix: String {
        let words = command.split(separator: " ").map(String.init)
        if let runIdx = words.firstIndex(of: "run"), runIdx + 1 < words.count {
            return words[runIdx + 1]
        }
        return words.last ?? "dev"
    }
}
