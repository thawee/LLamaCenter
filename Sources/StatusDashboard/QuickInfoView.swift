import SwiftUI

struct QuickInfoView: View {
    var viewModel: DashboardViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🦙 LLM Center")
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
            
            HStack(spacing: 12) {
                QuickGaugeStat(label: "CPU", iconName: "cpu", value: viewModel.systemCPU, max: 100, color: .blue)
                QuickGaugeStat(label: "GPU", iconName: "display", value: viewModel.gpuUsage, max: 100, color: .orange)
                QuickGaugeStat(label: "RAM", iconName: "memorychip", value: viewModel.systemMemory, max: viewModel.totalMemory, color: .green, suffix: "G")
            }
            .padding(.vertical, 4)
            
            Divider()
            
            Button(action: {
                openWindow(id: "full-dashboard")
                NSApp.activate(ignoringOtherApps: true)
                dismiss()
            }) {
                Label("Dashboard", systemImage: "macwindow")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .frame(width: 280) // Slightly widened for spacing comfort
    }
}

struct QuickGaugeStat: View {
    let label: String
    let iconName: String
    let value: Double
    let max: Double
    let color: Color
    var suffix: String = "%"
    
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 2.5)
                    .frame(width: 28, height: 28)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(value / (max > 0 ? max : 1), 1.0)))
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(Angle(degrees: -90))
                
                Image(systemName: iconName)
                    .font(.system(size: 9))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                Text("\(Int(value))\(suffix)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
