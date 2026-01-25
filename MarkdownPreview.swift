import SwiftUI
import AppKit
import SwiftData

struct MarkdownPreview: View {
    let markdown: String
    let images: [String: NSImage]
    @Binding var selectedNote: Note?
    
    @Query private var allNotes: [Note]
    @State private var showCopyToast = false
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("app_accent_color") private var appAccentColor = "azure"

    private var currentAccent: Color {
        AppAccentColor(rawValue: appAccentColor)?.color ?? .cyan
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                let blocks = parseMarkdown(markdown)
                ForEach(blocks.indices, id: \.self) { index in
                    renderBlock(blocks[index])
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(NSColor.textBackgroundColor))
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "tahoe" {
                let title = url.host?.removingPercentEncoding ?? ""
                if let target = allNotes.first(where: { $0.title.lowercased() == title.lowercased() }) {
                    selectedNote = target; return .handled
                }
            }
            return .systemAction
        })
        .toast(isPresented: $showCopyToast) {
            Text("Copied!").padding(8).background(.ultraThinMaterial, in: Capsule())
        }
    }
    
    @ViewBuilder
    private func renderBlock(_ block: ContentBlock) -> some View {
        switch block {
        case .header(let level, let content):
            VStack(alignment: .leading) {
                Text(parseInline(content)).font(level == 1 ? .largeTitle : .title2).bold()
                if level == 1 { Divider().opacity(0.5) }
            }.padding(.top, 8)
            
        case .text(let content):
            Text(parseInline(content))
                .foregroundStyle(Color.primary.opacity(0.9))
            
        case .listItem(let content):
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(currentAccent)
                    .frame(width: 5, height: 5)
                    .padding(.top, 7)
                Text(parseInline(content))
                    .foregroundStyle(Color.primary.opacity(0.9))
            }
            .padding(.leading, 8)
            
        case .image(let path):
            if let img = loadImageFromPath(path) {
                Image(nsImage: img).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
        case .code(let lang, let code):
            CodeBlockView(code: code, language: lang, showCopyToast: $showCopyToast)
            
        case .callout(let type, let title, let content):
            CalloutView(type: type, title: title, content: content)
            
        case .quote(let content):
            HStack(spacing: 12) {
                Rectangle().fill(currentAccent.opacity(0.5)).frame(width: 4)
                Text(parseInline(content)).italic().foregroundStyle(.secondary)
            }.padding(.vertical, 4).padding(.leading, 4)
            
        case .task(let isDone, let content):
            HStack(alignment: .top) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle").foregroundStyle(isDone ? Color.green : Color.secondary)
                Text(parseInline(content)).strikethrough(isDone).opacity(isDone ? 0.6 : 1)
            }
            
        case .horizontalRule: Divider().padding(.vertical, 12)
            
        case .footnote(let id, let content):
            HStack(alignment: .top, spacing: 4) {
                Text("[\(id)]:").font(.caption.bold()).foregroundStyle(currentAccent)
                Text(parseInline(content)).font(.caption).foregroundStyle(.secondary)
            }.padding(.top, 8)
        }
    }

    enum ContentBlock {
        case header(level: Int, content: String), text(String), listItem(content: String), image(String), code(String, String), quote(String), callout(type: String, title: String?, content: String), task(isDone: Bool, content: String), horizontalRule, footnote(id: String, content: String)
    }

    private func parseMarkdown(_ text: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        let lines = text.components(separatedBy: .newlines)
        var isInsideCode = false
        var currentCode = ""
        var currentLang = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("```") {
                if isInsideCode {
                    blocks.append(.code(currentLang, currentCode.trimmingCharacters(in: .newlines)))
                    currentCode = ""; isInsideCode = false
                } else {
                    currentLang = String(trimmed.dropFirst(3)).uppercased(); isInsideCode = true
                }
                continue
            }
            if isInsideCode { currentCode += line + "\n"; continue }
            
            if (trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ")) && !trimmed.hasPrefix("- [") {
                blocks.append(.listItem(content: String(trimmed.dropFirst(2))))
                continue
            }
            
            if trimmed.hasPrefix("[^") && trimmed.contains("]:") {
                let parts = trimmed.components(separatedBy: "]:")
                let id = parts[0].replacingOccurrences(of: "[^", with: "").trimmingCharacters(in: .whitespaces)
                let content = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
                blocks.append(.footnote(id: id, content: content))
                continue
            }

            if trimmed.hasPrefix("> [!") && trimmed.contains("]") {
                let parts = trimmed.components(separatedBy: "]")
                let type = parts[0].replacingOccurrences(of: "> [!", with: "").trimmingCharacters(in: .whitespaces)
                let title = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : nil
                blocks.append(.callout(type: type, title: title?.isEmpty == true ? nil : title, content: "")); continue
            } else if trimmed.hasPrefix(">") {
                blocks.append(.quote(String(trimmed.dropFirst().trimmingCharacters(in: .whitespaces)))); continue
            }
            
            if trimmed.hasPrefix("#") {
                let lv = trimmed.prefix(while: { $0 == "#" }).count
                blocks.append(.header(level: lv, content: String(trimmed.dropFirst(lv)).trimmingCharacters(in: .whitespaces))); continue
            }
            if (trimmed.hasPrefix("![") || trimmed.hasPrefix("![[")) {
                blocks.append(.image(extractPath(from: trimmed))); continue
            }
            if !line.isEmpty { blocks.append(.text(line)) }
        }
        return blocks
    }

    private func extractPath(from line: String) -> String {
        line.replacingOccurrences(of: "![[", with: "").replacingOccurrences(of: "]]", with: "")
            .replacingOccurrences(of: "![image](", with: "").replacingOccurrences(of: ")", with: "")
    }

    private func loadImageFromPath(_ path: String) -> NSImage? {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return NSImage(contentsOfFile: docsDir.appendingPathComponent("TahoeNotes").appendingPathComponent(path).path)
    }

    private func parseInline(_ input: String) -> AttributedString {
        var cleanString = input
        let highlightRegex = /==(.+?)==/
        var highlightRanges: [Range<String.Index>] = []
        while let match = try? highlightRegex.firstMatch(in: cleanString) {
            let content = String(match.output.1)
            let startIdx = match.range.lowerBound
            cleanString.replaceSubrange(match.range, with: content)
            let newEndIdx = cleanString.index(startIdx, offsetBy: content.count)
            highlightRanges.append(startIdx..<newEndIdx)
        }
        var attr = (try? AttributedString(markdown: cleanString, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(cleanString)
        for range in highlightRanges { if let attrRange = Range(range, in: attr) { attr[attrRange].backgroundColor = Color.yellow.opacity(0.3) } }
        if let wiki = try? Regex(#"\[\[(.*?)\]\]"#) {
            let plainText = String(attr.characters)
            for m in plainText.ranges(of: wiki).reversed() {
                if let r = Range(m, in: attr) {
                    let title = plainText[m].replacingOccurrences(of: "[[", with: "").replacingOccurrences(of: "]]", with: "")
                    attr[r].link = URL(string: "tahoe://\(title.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")")
                    attr[r].foregroundColor = currentAccent
                }
            }
        }
        return attr
    }
}

struct CodeBlockView: View {
    let code: String
    let language: String
    @Binding var showCopyToast: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(language.uppercased())
                    .font(.system(.caption, design: .monospaced))
                    .bold()
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(action: openInVSCode) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                        Text("VS Code")
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .help("Copy and open in VS Code")

                Button(action: copyToClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.05))
            
            ScrollView(.horizontal) {
                Text(highlight(code))
                    .font(.system(size: 13, design: .monospaced))
                    .padding(12)
            }
            .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.5))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.1), lineWidth: 1))
        .padding(.vertical, 4)
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation { showCopyToast = true }
    }
    
    private func openInVSCode() {
        copyToClipboard()
        
        let bundleID = "com.microsoft.VSCode"
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        } else {
            NSWorkspace.shared.launchApplication("Visual Studio Code")
        }
    }
    
    private func highlight(_ input: String) -> AttributedString {
        var attr = AttributedString(input)
        let keywords = #"\b(func|let|var|if|else|return|import|struct|class|enum|try|catch|for|while|in|switch|case)\b"#
        if let ranges = try? Regex(keywords) {
            for match in input.ranges(of: ranges) {
                if let r = Range(match, in: attr) { attr[r].foregroundColor = .purple }
            }
        }
        return attr
    }
}

struct CalloutView: View {
    let type: String; let title: String?; let content: String
    var theme: (Color, String) {
        switch type.uppercased() {
        case "WARNING": return (.orange, "exclamationmark.triangle.fill")
        case "ERROR": return (.red, "xmark.octagon.fill")
        case "SUCCESS": return (.green, "checkmark.seal.fill")
        default: return (.blue, "info.circle.fill")
        }
    }
    var body: some View {
        VStack(alignment: .leading) {
            HStack { Image(systemName: theme.1); Text(title ?? type.uppercased()).bold() }.foregroundStyle(theme.0)
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(theme.0.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .leading) { Rectangle().fill(theme.0).frame(width: 4).padding(.vertical, 8) }
    }
}

extension View {
    func toast<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        self.overlay(alignment: .bottom) { if isPresented.wrappedValue { content().transition(.move(edge: .bottom).combined(with: .opacity)).padding(.bottom, 20).onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { isPresented.wrappedValue = false } } } } }
    }
}
