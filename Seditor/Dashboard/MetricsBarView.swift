import SwiftUI

struct MetricsBarView: View {
    let metrics: [Metric]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(metrics) { metric in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: metric.icon)
                                .font(.headline)
                                .foregroundStyle(metric.accent)
                            Text(metric.label)
                                .font(.caption)
                                .foregroundStyle(DashboardTheme.textSecondary)
                        }
                        Text(metric.value)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(DashboardTheme.textPrimary)
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(DashboardTheme.panelBackground.opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(DashboardTheme.outline, lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
}
