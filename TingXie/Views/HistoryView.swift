import SwiftUI

struct HistoryView: View {
    @ObservedObject var manager = TranscriptionManager.shared
    @State private var searchText = ""
    @State private var currentPage = 0
    private let pageSize = 20
    
    var filteredHistory: [TranscriptionRecord] {
        if searchText.isEmpty {
            return manager.history
        } else {
            return manager.history.filter {
                $0.finalText.localizedCaseInsensitiveContains(searchText) ||
                $0.rawText.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var totalPages: Int {
        max(1, Int(ceil(Double(filteredHistory.count) / Double(pageSize))))
    }
    
    var pagedHistory: [TranscriptionRecord] {
        let start = currentPage * pageSize
        let end = min(start + pageSize, filteredHistory.count)
        guard start < filteredHistory.count else { return [] }
        return Array(filteredHistory[start..<end])
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header & Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索历史记录...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .onChange(of: searchText) { _, _ in
                        currentPage = 0 // Reset to first page on search
                    }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // List
            if filteredHistory.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    Text(searchText.isEmpty ? "暂无历史记录" : "未找到相关记录")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            } else {
                List {
                    ForEach(pagedHistory) { record in
                        HistoryRow(record: record)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                copyToClipboard(record.finalText)
                            }
                            .contextMenu {
                                Button("复制") {
                                    copyToClipboard(record.finalText)
                                }
                                Button("复制原文 (无 AI 润色)") {
                                    copyToClipboard(record.rawText)
                                }
                                Divider()
                                Button("删除", role: .destructive) {
                                    manager.deleteRecord(record)
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
            
            Divider()
            
            // Footer with pagination
            HStack {
                Text("\(filteredHistory.count) 条记录")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if totalPages > 1 {
                    Button(action: { currentPage = max(0, currentPage - 1) }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentPage == 0)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Text("\(currentPage + 1) / \(totalPages)")
                        .font(.caption)
                        .monospacedDigit()
                        .frame(minWidth: 50)
                    
                    Button(action: { currentPage = min(totalPages - 1, currentPage + 1) }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(currentPage >= totalPages - 1)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Spacer()
                
                Button("清空历史") {
                    manager.clearHistory()
                    currentPage = 0
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(minWidth: 400, minHeight: 500)
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        NSSound(named: "Pop")?.play()
    }
}

struct HistoryRow: View {
    let record: TranscriptionRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.finalText)
                .font(.system(size: 14))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(.primary)
            
            HStack(spacing: 8) {
                Text(formatDate(record.date))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                
                if record.polishedText != nil {
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 3) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 10))
                        Text("AI 润色")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.purple.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.3))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}
