import SwiftUI

struct RAMPolicySettingsView: View {
    @ObservedObject var viewModel: RAMPolicySettingsViewModel
    let onBack: () -> Void

    @State private var showingEditor = false
    @State private var editingPolicyID: UUID?
    @State private var draft = RAMPolicyDraft()

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 10) {
                header

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverTheme.red)
                        .lineLimit(2)
                }

                if viewModel.policies.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.policies) { policy in
                                policyCard(policy)
                            }
                        }
                    }
                }

                footer
            }

            if showingEditor {
                editorOverlay
            }
        }
        .onAppear {
            viewModel.refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                onBack()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(PopoverTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button {
                startNewPolicy()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Add Policy")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(PopoverTheme.accentContrastText)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(PopoverTheme.accent)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(PopoverTheme.textMuted)

            Text("No RAM policies")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PopoverTheme.textPrimary)

            Text("Create one for apps like Cursor, Docker, or Chrome.")
                .font(.system(size: 11))
                .foregroundStyle(PopoverTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button("Add First Policy") {
                startNewPolicy()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(PopoverTheme.accent)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func policyCard(_ policy: RAMPolicy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(policy.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(policy.enabled ? PopoverTheme.textPrimary : PopoverTheme.textMuted)
                    .lineLimit(1)

                Spacer(minLength: 6)

                PopoverToggle(
                    isOn: Binding(
                        get: { policy.enabled },
                        set: { viewModel.setEnabled($0, for: policy.id) }
                    )
                )
            }

            Text(policy.bundleID)
                .font(.system(size: 10))
                .foregroundStyle(PopoverTheme.textMuted)
                .lineLimit(1)

            HStack(spacing: 6) {
                policyTag(text: "> \(policy.thresholdDescription)", tint: PopoverTheme.accent, background: PopoverTheme.accentDim)
                policyTag(text: triggerTagText(for: policy), tint: PopoverTheme.mint, background: PopoverTheme.mintDim)
                policyTag(text: "Cooldown \(policy.notifyCooldownSeconds)s", tint: PopoverTheme.purple, background: PopoverTheme.purpleDim)
            }

            HStack(spacing: 12) {
                Button("Edit") {
                    editingPolicyID = policy.id
                    draft = RAMPolicyDraft(policy: policy)
                    viewModel.clearError()
                    showingEditor = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PopoverTheme.textSecondary)

                Button("Delete") {
                    viewModel.deletePolicy(id: policy.id)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PopoverTheme.textMuted)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(policy.enabled ? PopoverTheme.accent.opacity(0.20) : PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func policyTag(text: String, tint: Color, background: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(background)
            )
            .lineLimit(1)
    }

    private var footer: some View {
        HStack {
            Text("\(viewModel.policies.filter(\.enabled).count) active of \(viewModel.policies.count)")
                .font(.system(size: 10))
                .foregroundStyle(PopoverTheme.textMuted)

            Spacer(minLength: 0)
        }
    }

    private var editorOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text(editingPolicyID == nil ? "Add RAM Policy" : "Edit RAM Policy")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)

                modalField(label: "App") {
                    Picker("App", selection: $draft.bundleID) {
                        if viewModel.runningApps.isEmpty {
                            Text("No running app found").tag("")
                        } else {
                            ForEach(viewModel.runningApps) { app in
                                Text(app.displayName).tag(app.bundleID)
                            }
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .disabled(viewModel.runningApps.isEmpty)
                }

                modalField(label: "Bundle ID") {
                    Text(draft.bundleID)
                        .font(.system(size: 12))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(modalFieldBackground)
                }

                modalField(label: "Limit Mode") {
                    HStack(spacing: 2) {
                        limitModeButton(title: "GB", mode: .gigabytes)
                        limitModeButton(title: "Percent", mode: .percent)
                    }
                    .padding(3)
                    .background(modalFieldBackground)
                }

                modalField(label: "Limit Value") {
                    TextField(draft.limitMode == .percent ? "10" : "6", text: $draft.limitValueText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(PopoverTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(modalFieldBackground)
                }

                modalField(label: "Trigger") {
                    HStack(spacing: 2) {
                        triggerModeButton(title: "Instant", mode: .immediate)
                        triggerModeButton(title: "Sustained", mode: .sustained)
                        triggerModeButton(title: "Both", mode: .both)
                    }
                    .padding(3)
                    .background(modalFieldBackground)
                }

                if draft.triggerMode.includesSustained {
                    modalField(label: "Sustained Window") {
                        TextField("15", text: sustainedWindowBinding)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(PopoverTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(modalFieldBackground)
                    }
                }

                modalField(label: "Alert Cooldown") {
                    TextField("60", text: cooldownBinding)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(PopoverTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(modalFieldBackground)
                }

                HStack {
                    Text("Enabled")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PopoverTheme.textSecondary)

                    Spacer(minLength: 0)

                    PopoverToggle(isOn: $draft.enabled)
                }

                if let validationError {
                    Text(validationError)
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverTheme.red)
                }

                HStack(spacing: 8) {
                    Spacer(minLength: 0)

                    Button("Cancel") {
                        showingEditor = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(PopoverTheme.borderMedium)
                    )

                    Button("Save") {
                        draft.displayName = viewModel.runningApps.first(where: { $0.bundleID == draft.bundleID })?.displayName ?? draft.displayName
                        if viewModel.saveDraft(draft, editingID: editingPolicyID) {
                            showingEditor = false
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PopoverTheme.accentContrastText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(PopoverTheme.accent)
                    )
                    .disabled(validationError != nil)
                    .opacity(validationError == nil ? 1 : 0.6)
                }
            }
            .padding(20)
            .frame(width: 340)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PopoverTheme.bgPanel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PopoverTheme.borderMedium, lineWidth: 1)
            )
        }
    }

    private func modalField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PopoverTheme.textSecondary)

            content()
        }
    }

    private var modalFieldBackground: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(PopoverTheme.bgElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(PopoverTheme.borderMedium, lineWidth: 1)
            )
    }

    private func limitModeButton(title: String, mode: RAMPolicyLimitMode) -> some View {
        Button {
            draft.limitMode = mode
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(draft.limitMode == mode ? PopoverTheme.accentContrastText : PopoverTheme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(draft.limitMode == mode ? PopoverTheme.accent : Color.white.opacity(0.001))
                )
        }
        .buttonStyle(.plain)
    }

    private func triggerModeButton(title: String, mode: RAMPolicyTriggerMode) -> some View {
        Button {
            draft.triggerMode = mode
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(draft.triggerMode == mode ? PopoverTheme.accentContrastText : PopoverTheme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(draft.triggerMode == mode ? PopoverTheme.accent : Color.white.opacity(0.001))
                )
        }
        .buttonStyle(.plain)
    }

    private var sustainedWindowBinding: Binding<String> {
        Binding(
            get: { String(draft.sustainedSeconds) },
            set: { newValue in
                if let parsed = Int(newValue.trimmingCharacters(in: .whitespacesAndNewlines)), parsed > 0 {
                    draft.sustainedSeconds = parsed
                }
            }
        )
    }

    private var cooldownBinding: Binding<String> {
        Binding(
            get: { String(draft.notifyCooldownSeconds) },
            set: { newValue in
                if let parsed = Int(newValue.trimmingCharacters(in: .whitespacesAndNewlines)), parsed >= 0 {
                    draft.notifyCooldownSeconds = parsed
                }
            }
        )
    }

    private func startNewPolicy() {
        editingPolicyID = nil
        draft = viewModel.makeDraftForNewPolicy()
        viewModel.clearError()
        showingEditor = true
    }

    private func triggerTagText(for policy: RAMPolicy) -> String {
        switch policy.triggerMode {
        case .immediate:
            return "Instant"
        case .sustained:
            return "Sustained \(policy.sustainedSeconds)s"
        case .both:
            return "Both \(policy.sustainedSeconds)s"
        }
    }

    private var validationError: String? {
        if draft.bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Select an app."
        }

        let limit = draft.limitValueText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard let limitValue = Double(limit), limitValue > 0 else {
            return "Enter a positive limit."
        }

        if draft.limitMode == .percent, limitValue > 100 {
            return "Percent cannot exceed 100."
        }

        return nil
    }
}
