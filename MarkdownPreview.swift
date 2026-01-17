import SwiftUI
import AppKit

struct MarkdownPreview: View {
    let markdown: String
    @State private var showCopyToast = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(codeBlocks.indices, id: \.self) { index in
                    CodeBlockView(code: codeBlocks[index])
                }
                
                ForEach(nonCodeLines(), id: \.self) { line in
                    MarkdownLineView(line: line)
                }
            }
            .padding()
            .toast(isPresented: $showCopyToast) {
                Text("Copied!")
                    .padding()
                    .background(.blue.opacity(0.8), in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    private var codeBlocks: [(language: String, code: String)] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [(language: String, code: String)] = []
        var i = 0
        
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                let rawLanguage = String(trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces))
                let displayLanguage = rawLanguage.isEmpty ? "<shell>" : rawLanguage.uppercased()
                var codeLines: [String] = []
                i += 1
                
                while i < lines.count {
                    let nextTrimmed = lines[i].trimmingCharacters(in: .whitespaces)
                    if nextTrimmed.hasPrefix("```") {
                        i += 1
                        break
                    }
                    codeLines.append(lines[i])
                    i += 1
                }
                
                let code = codeLines.joined(separator: "\n")
                blocks.append((displayLanguage, code))
            } else {
                i += 1
            }
        }
        return blocks
    }
    
    private func nonCodeLines() -> [String] {
        let allLines = markdown.components(separatedBy: .newlines)
        var result: [String] = []
        var inCodeBlock = false
        
        for line in allLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("```") {
                inCodeBlock.toggle()
            } else if !inCodeBlock {
                result.append(line)
            }
        }
        
        return result.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

struct MarkdownLineView: View {
    let line: String
    
    var body: some View {
        Group {
            if line.hasPrefix("# ") {
                Text(line.dropFirst(2))
                    .font(.title)
                    .fontWeight(.bold)
            } else if line.hasPrefix("## ") {
                Text(line.dropFirst(4))
                    .font(.title2)
                    .fontWeight(.bold)
            } else if line.hasPrefix("### ") {
                Text(line.dropFirst(5))
                    .font(.title3)
                    .fontWeight(.bold)
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                HStack(alignment: .top) {
                    Text("•")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(line.dropFirst(2))
                        .font(.body)
                }
            } else {
                Text(line)
                    .font(.body)
                    .multilineTextAlignment(.leading)
            }
        }
        .foregroundStyle(.primary)
        .lineLimit(nil)
    }
}

struct CodeBlockView: View {
    let code: (language: String, code: String)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(code.language) 
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Button("📄") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code.code, forType: .string)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.9))
                .help("Copy")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.1))
            
            ScrollView {
                Text(code.code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.black.opacity(0.9))
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    func toast<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) -> some View {
        self.overlay {
            if isPresented.wrappedValue {
                content()
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
    }
}

