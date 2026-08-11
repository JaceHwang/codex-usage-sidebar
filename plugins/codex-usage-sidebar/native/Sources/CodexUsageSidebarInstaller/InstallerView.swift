import InstallerCore
import SwiftUI

struct InstallerView: View {
    @ObservedObject var model: InstallerViewModel
    @State private var showDetails = false
    @State private var showUninstallConfirmation = false

    var body: some View {
        HStack(spacing: 0) {
            stepColumn
            Divider()
            content
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .confirmationDialog(
            model.copy.uninstall,
            isPresented: $showUninstallConfirmation
        ) {
            Button(model.copy.uninstall, role: .destructive) {
                Task { await model.uninstall() }
            }
        }
    }

    private var stepColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            quotaMark
                .padding(.bottom, 12)
            ForEach(Array(InstallerStep.allCases.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 10) {
                    Image(systemName: icon(for: step))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(color(for: step))
                        .frame(width: 22, height: 22)
                        .background(color(for: step).opacity(0.12), in: Circle())
                    Text(model.copy.stepTitles[index])
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(stepTextColor(for: step))
                }
                .accessibilityElement(children: .combine)
            }
            Spacer()
            Text(model.copy.version)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(26)
        .frame(width: 220, alignment: .leading)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var quotaMark: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor)
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .foregroundStyle(.white)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(width: 34, height: 34)
            Text("CUS")
                .font(.system(size: 15, weight: .bold, design: .rounded))
        }
        .accessibilityLabel(model.copy.title)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.copy.title)
                    .font(.system(size: 28, weight: .bold))
                Text(model.copy.subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 30)

            statusCard

            DisclosureGroup(model.copy.showDetails, isExpanded: $showDetails) {
                ScrollView {
                    Text(model.details.isEmpty ? model.copy.finderOpen : model.details)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }
                .frame(maxHeight: 100)
            }
            .padding(.top, 18)

            Spacer(minLength: 24)

            HStack {
                Button(model.copy.uninstall) {
                    showUninstallConfirmation = true
                }
                .disabled(model.isBusy)

                Button(model.copy.repair) {
                    Task { await model.repair() }
                }
                .disabled(model.isBusy)

                Spacer()

                if model.isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 8)
                }

                Button(model.primaryTitle) {
                    Task { await model.primaryAction() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.isBusy)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(34)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: statusIcon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(statusColor)
                .symbolEffect(.pulse, isActive: model.isBusy)
            VStack(alignment: .leading, spacing: 7) {
                Text(model.message)
                    .font(.system(size: 15, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if case .failed = model.presentation.phase {
                    Text(model.copy.finderOpen)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private var statusIcon: String {
        switch model.presentation.phase {
        case .succeeded: "checkmark.seal.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .running: "arrow.triangle.2.circlepath.circle.fill"
        case .waiting: "hand.raised.fill"
        case .ready: "shippingbox.fill"
        }
    }

    private var statusColor: Color {
        switch model.presentation.phase {
        case .succeeded: .green
        case .failed: .red
        default: .accentColor
        }
    }

    private func icon(for step: InstallerStep) -> String {
        if model.presentation.completedSteps.contains(step) {
            return "checkmark"
        }
        switch model.presentation.phase {
        case .running(let active) where active == step: return "ellipsis"
        case .waiting(let active) where active == step: return "hand.raised"
        default: return "circle"
        }
    }

    private func color(for step: InstallerStep) -> Color {
        if model.presentation.completedSteps.contains(step) {
            return .green
        }
        switch model.presentation.phase {
        case .running(let active) where active == step: return .accentColor
        case .waiting(let active) where active == step: return .orange
        default: return .secondary
        }
    }

    private func stepTextColor(for step: InstallerStep) -> Color {
        model.presentation.completedSteps.contains(step) ? .primary : .secondary
    }
}
