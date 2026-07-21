import SwiftUI
import AppKit
import CoreImage.CIFilterBuiltins

/// 局域网地址 + 二维码：同一 Wi-Fi 下用手机扫码在真机上打开。
struct NetworkShareView: View {
    let port: Int
    @Environment(AppSettings.self) private var settings
    private var zh: Bool { settings.resolvedLanguage == .zh }

    private var lanURL: String? {
        guard let ip = SystemProbe.localIP() else { return nil }
        return "http://\(ip):\(port)"
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(zh ? "局域网" : "LAN")
                .font(.system(.caption, design: .monospaced)).bold()
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let url = lanURL {
                Text(zh ? "手机同一 Wi-Fi 扫码打开" : "Scan on a device in the same network")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textDim)
                    .multilineTextAlignment(.center)

                if let img = qr(url) {
                    Image(nsImage: img)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 168, height: 168)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                HStack(spacing: 8) {
                    Text(url)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(Theme.text)
                        .textSelection(.enabled)
                        .lineLimit(1)
                    Button { copy(url) } label: {
                        Image(systemName: "doc.on.doc").font(.caption)
                    }
                    .buttonStyle(.hit).foregroundStyle(Theme.textDim)
                    .help(zh ? "复制" : "copy")
                }
            } else {
                Text(zh ? "未获取到局域网 IP（未联网？）" : "No LAN IP found (offline?)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.textDim)
            }
        }
        .padding(18)
        .frame(width: 230)
        .background(Theme.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
    }

    private func qr(_ s: String) -> NSImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(s.utf8)
        f.correctionLevel = "M"
        guard let ci = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)) else { return nil }
        let rep = NSCIImageRep(ciImage: ci)
        let img = NSImage(size: rep.size)
        img.addRepresentation(rep)
        return img
    }

    private func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}

/// 端口只绑在 localhost(127.0.0.1)时:局域网设备访问不了,不给死二维码,而是提示如何暴露。
struct LocalOnlyHint: View {
    let port: Int
    @Environment(AppSettings.self) private var settings
    private var zh: Bool { settings.resolvedLanguage == .zh }
    private var localURL: String { "http://localhost:\(port)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(zh ? "仅本机" : "Local only")
                .font(.system(.caption, design: .monospaced)).bold()
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Text(localURL)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Theme.text).textSelection(.enabled).lineLimit(1)
                Button { copy(localURL) } label: {
                    Image(systemName: "doc.on.doc").font(.caption)
                }
                .buttonStyle(.hit).foregroundStyle(Theme.textDim)
                .help(zh ? "复制" : "copy")
            }

            Text(zh ? "只绑在 localhost，局域网设备访问不了。要手机扫码，让 dev server 绑到 0.0.0.0:"
                    : "Bound to localhost — other devices can't reach it. To expose, bind the dev server to 0.0.0.0:")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Theme.textDim)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 3) {
                Text("vite:  --host")
                Text("next:  -H 0.0.0.0")
                Text("CRA:   HOST=0.0.0.0")
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(Theme.textDim)
        }
        .padding(18)
        .frame(width: 230)
        .background(Theme.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
    }

    private func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}
