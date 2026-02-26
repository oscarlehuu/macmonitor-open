import SwiftUI

struct BatteryScreenView: View {
    let battery: BatterySnapshot?

    @ObservedObject var settings: SettingsStore
    @ObservedObject var coordinator: BatteryPolicyCoordinator
    @ObservedObject var scheduleViewModel: BatteryScheduleViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryCard
            controlsCard
            scheduleCard
            statusCard
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title + percent
            HStack {
                Text("Battery")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)

                Spacer(minLength: 8)

                Text(displayPercent)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PopoverTheme.green)
            }

            // Progress bar
            if let percent = battery?.percentage {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(PopoverTheme.borderMedium)

                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(PopoverTheme.green)
                            .frame(width: geometry.size.width * min(max(Double(percent) / 100.0, 0), 1))
                    }
                }
                .frame(height: 6)
            }

            // Status line: dot + state + flow on right
            HStack(spacing: 6) {
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 6, height: 6)

                Text(summaryText)
                    .font(.system(size: 11))
                    .foregroundStyle(PopoverTheme.textSecondary)

                Spacer(minLength: 4)

                if let flowText = compactFlowText {
                    Text(flowText)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PopoverTheme.textMuted)
                }
            }

            // 2x2 stats grid
            if let battery {
                batteryStatsGrid(battery)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func batteryStatsGrid(_ battery: BatterySnapshot) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 6),
            GridItem(.flexible(), spacing: 6)
        ]

        return LazyVGrid(columns: columns, spacing: 6) {
            if let temperature = battery.temperatureCelsius {
                batteryStatCell(
                    label: "TEMP",
                    value: "\(temperature)\u{00B0}C",
                    valueColor: PopoverTheme.textPrimary,
                    help: "Current battery pack temperature in Celsius."
                )
            }

            if let cycleCount = battery.cycleCount {
                batteryStatCell(
                    label: "CYCLES",
                    value: "\(cycleCount)",
                    valueColor: PopoverTheme.textPrimary,
                    help: "One cycle equals 100% total discharge across one or more partial discharges."
                )
            }

            if let healthText = batteryHealthText {
                batteryStatCell(
                    label: "HEALTH",
                    value: healthText,
                    valueColor: PopoverTheme.green,
                    help: "Battery health estimate from macOS telemetry."
                )
            }

            if let condition = batteryConditionText {
                batteryStatCell(
                    label: "CONDITION",
                    value: condition,
                    valueColor: PopoverTheme.textPrimary,
                    help: "Battery condition reported by macOS."
                )
            }
        }
    }

    private func batteryStatCell(label: String, value: String, valueColor: Color, help: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(PopoverTheme.textMuted)
                .tracking(0.5)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PopoverTheme.bgDeep)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
        .help(help)
    }

    private var statusDotColor: Color {
        guard let battery else { return PopoverTheme.textMuted }
        if battery.isCharging { return PopoverTheme.green }
        if battery.isCharged { return PopoverTheme.green }
        switch battery.powerSource {
        case .ac, .ups: return PopoverTheme.yellow
        case .battery: return PopoverTheme.orange
        case .unknown: return PopoverTheme.textMuted
        }
    }

    private var compactFlowText: String? {
        formattedAmperageText(battery?.amperageMilliAmps)
    }

    private var controlsCard: some View {
        let config = settings.batteryPolicyConfiguration

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                helpLabel(
                    "Controls",
                    help: "Battery control rules. Click the info icons for details."
                )
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PopoverTheme.textPrimary)

                Spacer(minLength: 8)

                startStopButton
            }

            helpLabel(
                "Limit \(config.chargeLimitPercent)%",
                help: "Target battery limit used by charging and discharge rules."
            )
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(PopoverTheme.textSecondary)

            Slider(
                value: chargeLimitBinding,
                in: 50...95,
                step: 1
            )
            .tint(PopoverTheme.accent)

            Toggle(isOn: automaticDischargeBinding) {
                helpLabel(
                    "Automatic Discharge",
                    help: "Automatically tries to return to the limit when battery is above it."
                )
            }
            Toggle(isOn: manualDischargeBinding) {
                helpLabel(
                    "Manual Discharge",
                    help: "Manual override to discharge toward the limit. Enabling this turns off Automatic Discharge."
                )
            }
            Toggle(isOn: bindingFor(\.sailingModeEnabled)) {
                helpLabel(
                    "Sailing Mode",
                    help: "Keeps battery between sailing low/high bounds."
                )
            }
            Toggle(isOn: bindingFor(\.topUpEnabled)) {
                helpLabel(
                    "Top Up Mode",
                    help: "Temporarily charges to 100% and overrides normal limit behavior."
                )
            }
            Toggle(isOn: bindingFor(\.heatProtectionEnabled)) {
                helpLabel(
                    "Heat Protection",
                    help: "Pauses charging when battery temperature reaches the configured threshold."
                )
            }

            if config.sailingModeEnabled {
                HStack(spacing: 8) {
                    Stepper(value: sailingLowerBinding, in: 50...95) {
                        helpLabel(
                            "Sailing Low \(config.sailingLowerPercent)%",
                            help: "Lower bound of Sailing Mode. At or below this, charging resumes toward Sailing High."
                        )
                    }
                    Stepper(value: sailingUpperBinding, in: 50...95) {
                        helpLabel(
                            "Sailing High \(config.sailingUpperPercent)%",
                            help: "Upper bound of Sailing Mode. At or above this, discharge starts toward Sailing Low."
                        )
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(PopoverTheme.textSecondary)
            }

            if config.heatProtectionEnabled {
                Stepper(value: heatThresholdBinding, in: 20...55) {
                    helpLabel(
                        "Heat Threshold \(config.heatProtectionThresholdCelsius)\u{00B0}C",
                        help: "Temperature threshold where charging is paused to reduce heat stress."
                    )
                }
                .font(.system(size: 10))
                .foregroundStyle(PopoverTheme.textSecondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
        .toggleStyle(.switch)
        .tint(PopoverTheme.accent)
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            helpLabel(
                "Schedule",
                help: "Create one-shot battery actions that run at a specific date and time."
            )
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(PopoverTheme.textPrimary)

            scheduleFieldRow("Action") {
                Picker("Action", selection: $scheduleViewModel.draftAction) {
                    ForEach(BatteryScheduleDraftAction.allCases) { action in
                        Text(action.title).tag(action)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            scheduleFieldRow("Run At") {
                DatePicker(
                    "Run At",
                    selection: $scheduleViewModel.draftScheduledAt,
                    in: scheduleViewModel.minimumAllowedDate...Date.distantFuture,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if scheduleViewModel.draftAction.usesTargetPercent {
                scheduleFieldRow("Target") {
                    HStack(spacing: 8) {
                        Slider(
                            value: draftTargetPercentBinding,
                            in: 50...95,
                            step: 1
                        )
                        .tint(PopoverTheme.accent)

                        Text("\(scheduleViewModel.draftTargetPercent)%")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PopoverTheme.textSecondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }

            HStack(spacing: 8) {
                actionButton(title: "Schedule Task", tint: PopoverTheme.accent) {
                    _ = scheduleViewModel.scheduleDraftTask()
                }

                Text("At least 1 minute ahead.")
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textMuted)
            }

            if let errorMessage = scheduleViewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PopoverTheme.red)
            }

            Rectangle()
                .fill(PopoverTheme.borderSubtle)
                .frame(height: 1)

            Text("Pending Tasks")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PopoverTheme.textSecondary)

            if scheduleViewModel.pendingTasks.isEmpty {
                Text("No pending schedule tasks.")
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textMuted)
            } else {
                ForEach(Array(scheduleViewModel.pendingTasks.prefix(4))) { task in
                    scheduledTaskRow(task)
                }
            }

            if let summary = scheduleViewModel.lastExecutionSummary {
                Text("Last run: \(summary)")
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textSecondary)
                    .lineLimit(2)
            }

            if let lastFailureReason = scheduleViewModel.lastFailureReason {
                Text("Last schedule failure: \(lastFailureReason)")
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.red)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func scheduledTaskRow(_ task: BatteryScheduledTask) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(scheduleViewModel.formattedAction(task.action))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)

                Text("\(scheduleViewModel.formattedScheduledTime(task.scheduledAt)) (\(scheduleViewModel.formattedRelativeTime(task.scheduledAt)))")
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Button("Cancel") {
                scheduleViewModel.cancelTask(task.id)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(PopoverTheme.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(PopoverTheme.orangeDim)
            )
        }
        .padding(.vertical, 2)
    }

    private func scheduleFieldRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PopoverTheme.textSecondary)
                .frame(width: 44, alignment: .leading)

            content()
        }
    }

    private var draftTargetPercentBinding: Binding<Double> {
        Binding(
            get: { Double(scheduleViewModel.draftTargetPercent) },
            set: { scheduleViewModel.draftTargetPercent = Int($0.rounded()) }
        )
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PopoverTheme.textPrimary)

            helperStatusRow

            Rectangle()
                .fill(PopoverTheme.borderSubtle)
                .frame(height: 1)

            Text(coordinator.statusText())
                .font(.system(size: 10))
                .foregroundStyle(PopoverTheme.textSecondary)

            if let errorMessage = coordinator.lastErrorMessage {
                Text(errorMessage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PopoverTheme.red)
            }

            if coordinator.recentEvents.isEmpty {
                Text("No battery events yet.")
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textMuted)
            } else {
                ForEach(Array(coordinator.recentEvents.prefix(4))) { event in
                    HStack(spacing: 8) {
                        Text(event.timestamp, style: .time)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(PopoverTheme.textMuted)
                            .frame(width: 50, alignment: .leading)

                        Text(event.accepted ? "OK" : "ERR")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(event.accepted ? PopoverTheme.green : PopoverTheme.red)
                            .frame(width: 28, alignment: .leading)

                        Text(event.message)
                            .font(.system(size: 10))
                            .foregroundStyle(PopoverTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var helperStatusRow: some View {
        switch coordinator.helperAvailability {
        case .available:
            HStack(spacing: 8) {
                helpLabel(
                    "Helper",
                    help: "Privileged helper required for battery control commands."
                )
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PopoverTheme.textSecondary)
                Text("Installed")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PopoverTheme.green)
            }
        case .unavailable(let reason):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    helpLabel(
                        "Helper",
                        help: "Privileged helper required for battery control commands."
                    )
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textSecondary)
                    Text("Not Installed")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PopoverTheme.orange)
                }

                Text(reason)
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textMuted)
                    .lineLimit(2)

                if coordinator.isInstallingHelper {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Installing helper...")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(PopoverTheme.textSecondary)
                    }
                }

                actionButton(title: "Install Helper", tint: PopoverTheme.blue) {
                    Task {
                        await coordinator.installHelperIfNeededAsync()
                    }
                }
                .help("Install or update the privileged helper used for battery control.")
                .disabled(coordinator.isInstallingHelper)
                .opacity(coordinator.isInstallingHelper ? 0.6 : 1.0)
            }
        }
    }

    private var displayPercent: String {
        battery?.percentage.map { "\($0)%" } ?? "--"
    }

    private var summaryText: String {
        guard let battery else {
            return "No battery telemetry available"
        }
        return "\(battery.chargeState.title) • \(battery.powerSource.title)"
    }

    private var isAdapterConnected: Bool {
        guard let battery else { return false }
        return battery.powerSource == .ac || battery.powerSource == .ups
    }

    private var isPausedOnAdapter: Bool {
        guard let battery, isAdapterConnected else { return false }
        if battery.isCharging {
            return false
        }
        if let current = battery.amperageMilliAmps, current < 0 {
            return false
        }
        return true
    }

    private var isStartMode: Bool {
        guard isAdapterConnected else { return true }
        if settings.batteryPolicyConfiguration.topUpEnabled || coordinator.state == .topUp {
            return false
        }
        return isPausedOnAdapter
    }

    private var startStopButton: some View {
        let title = isStartMode ? "Start" : "Stop"
        let tint = isStartMode ? PopoverTheme.green : PopoverTheme.orange
        let helpText = isStartMode
            ? "Start charging override (Top Up)."
            : "Stop charging override and pause adapter charging."

        return HStack(spacing: 4) {
            actionButton(title: title, tint: tint) {
                Task {
                    if isStartMode {
                        _ = await coordinator.startChargingNow()
                    } else {
                        _ = await coordinator.pauseChargingNow()
                    }
                }
            }
            .disabled(!isAdapterConnected)
            .opacity(isAdapterConnected ? 1.0 : 0.6)

            InlineHelpIcon(text: helpText)
        }
    }

    private var chargeLimitBinding: Binding<Double> {
        Binding(
            get: { Double(settings.batteryPolicyConfiguration.chargeLimitPercent) },
            set: { newValue in
                coordinator.updateConfiguration { configuration in
                    configuration.chargeLimitPercent = Int(newValue.rounded())
                }
            }
        )
    }

    private var sailingLowerBinding: Binding<Int> {
        Binding(
            get: { settings.batteryPolicyConfiguration.sailingLowerPercent },
            set: { newValue in
                coordinator.updateConfiguration { configuration in
                    configuration.sailingLowerPercent = newValue
                }
            }
        )
    }

    private var sailingUpperBinding: Binding<Int> {
        Binding(
            get: { settings.batteryPolicyConfiguration.sailingUpperPercent },
            set: { newValue in
                coordinator.updateConfiguration { configuration in
                    configuration.sailingUpperPercent = newValue
                }
            }
        )
    }

    private var heatThresholdBinding: Binding<Int> {
        Binding(
            get: { settings.batteryPolicyConfiguration.heatProtectionThresholdCelsius },
            set: { newValue in
                coordinator.updateConfiguration { configuration in
                    configuration.heatProtectionThresholdCelsius = newValue
                }
            }
        )
    }

    private var automaticDischargeBinding: Binding<Bool> {
        Binding(
            get: { settings.batteryPolicyConfiguration.automaticDischargeEnabled },
            set: { newValue in
                coordinator.setAutomaticDischargeEnabled(newValue)
            }
        )
    }

    private var manualDischargeBinding: Binding<Bool> {
        Binding(
            get: { settings.batteryPolicyConfiguration.manualDischargeEnabled },
            set: { newValue in
                coordinator.setManualDischargeEnabled(newValue)
            }
        )
    }

    private func bindingFor(_ keyPath: WritableKeyPath<BatteryPolicyConfiguration, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings.batteryPolicyConfiguration[keyPath: keyPath] },
            set: { newValue in
                coordinator.updateConfiguration { configuration in
                    configuration[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func actionButton(title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint == PopoverTheme.green || tint == PopoverTheme.accent ? PopoverTheme.accentContrastText : Color.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(tint)
                )
        }
        .buttonStyle(.plain)
    }

    private func helpLabel(_ title: String, help: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(PopoverTheme.textPrimary)
            InlineHelpIcon(text: help)
        }
    }

    private func formattedAmperageText(_ amperage: Int?) -> String? {
        guard let amperage else { return nil }
        if amperage > 0 {
            return "+\(amperage) mA"
        }
        return "\(amperage) mA"
    }

    private var batteryHealthText: String? {
        guard let health = battery?.health?.trimmingCharacters(in: .whitespacesAndNewlines), !health.isEmpty else {
            return nil
        }
        return health
    }

    private var batteryConditionText: String? {
        guard let condition = battery?.healthCondition?.trimmingCharacters(in: .whitespacesAndNewlines),
              !condition.isEmpty else {
            return nil
        }
        return condition
    }
}

private struct InlineHelpIcon: View {
    let text: String

    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PopoverTheme.textMuted)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(PopoverTheme.textPrimary)
                .multilineTextAlignment(.leading)
                .padding(12)
                .frame(width: 280, alignment: .leading)
                .background(PopoverTheme.bgCard)
        }
    }
}
