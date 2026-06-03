import SwiftUI

struct QuickInfoView: View {
    var viewModel: DashboardViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🦙 LlamaCenter")
                    .font(.headline)
                Spacer()
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            VStack(spacing: 12) {
                QuickStatProgress(label: "CPU", value: viewModel.systemCPU, color: .blue)
                QuickStatProgress(label: "RAM", value: viewModel.systemMemory, color: .green, max: viewModel.totalMemory, suffix: "GB")
            }
            
            Divider()
            
            HStack(spacing: 8) {
                Button(action: {
                    openWindow(id: "full-dashboard")
                    NSApp.activate(ignoringOtherApps: true)
                }) {
                    Label("Dashboard", systemImage: "macwindow")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button(action: {
                    openWindow(id: "observer-mini")
                }) {
                    Label("Observer", systemImage: "macwindow.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .frame(width: 260)
    }
}

struct QuickStatProgress: View {
    let label: String
    let value: Double
    let color: Color
    var max: Double = 100
    var suffix: String = "%"
    var format: String = "%.0f"
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: format, value))\(suffix)")
                    .font(.caption.monospacedDigit())
                    .bold()
            }
            ProgressView(value: value, total: max)
                .tint(color)
                .scaleEffect(x: 1, y: 0.5, anchor: .center)
        }
    }
}
