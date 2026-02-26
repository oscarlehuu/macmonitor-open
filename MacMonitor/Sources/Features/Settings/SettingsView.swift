import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var ramPolicyViewModel: RAMPolicySettingsViewModel
    @ObservedObject var appUpdateController: AppUpdateController
    let onOpenPolicyManager: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            themeSection
            settingSeparator
            policySection
            settingSeparator
            refreshSection
            settingSeparator
            menuBarSection
            settingSeparator
            startupSection
            settingSeparator
            updatesSection
        }
        .onAppear {
            ramPolicyViewModel.refresh()
        }
    }

    private var settingSeparator: some View {
        Rectangle()
            .fill(PopoverTheme.borderSubtle)
            .frame(height: 1)
    }

    private var themeSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Theme")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)

                Text(settings.appTheme.title)
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textMuted)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                ForEach(AppTheme.allCases) { theme in
                    themeSwatch(theme)
                }
            }
        }
        .padding(14)
    }

    private func themeSwatch(_ theme: AppTheme) -> some View {
        let palette = PopoverTheme.palette(for: theme)
        let isSelected = settings.appTheme == theme

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                settings.appTheme = theme
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(palette.bgDeep)
                    .frame(width: 28, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(palette.accent)
                            .frame(width: 10, height: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(
                                isSelected ? PopoverTheme.accent : palette.bgPanel,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            }
        }
        .buttonStyle(.plain)
        .help(theme.title)
    }

    private var policySection: some View {
        settingSection(title: "RAM Policy", subtitle: "Keep your memory in check") {
            HStack {
                Text("\(ramPolicyViewModel.policies.filter(\.enabled).count) active of \(ramPolicyViewModel.policies.count) policies")
                    .font(.system(size: 11))
                    .foregroundStyle(PopoverTheme.textSecondary)

                Spacer(minLength: 8)

                if let lastEvent = ramPolicyViewModel.recentEvents.first {
                    Text("Last: \(MetricFormatter.relativeTime(from: lastEvent.timestamp))")
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .lineLimit(1)
                }
            }

            if let errorMessage = ramPolicyViewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.red)
                    .lineLimit(2)
            }

            Button {
                onOpenPolicyManager()
            } label: {
                HStack(spacing: 6) {
                    Text("Manage Policies")
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(PopoverTheme.accentContrastText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(PopoverTheme.accent)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var refreshSection: some View {
        settingSection(title: "Auto Refresh", subtitle: "How obsessive are you") {
            optionGroup(
                selection: $settings.refreshInterval,
                options: RefreshInterval.allCases
            ) { interval, isSelected in
                Text(refreshTitle(for: interval))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? PopoverTheme.accentContrastText : PopoverTheme.textSecondary)
            }
        }
    }

    private var menuBarSection: some View {
        settingSection(title: "Menu Bar", subtitle: "The little guy up top") {
            optionGroup(
                selection: $settings.menuBarDisplayMode,
                options: MenuBarDisplayMode.allCases
            ) { mode, isSelected in
                HStack(spacing: 4) {
                    Image(systemName: menuBarDisplaySymbol(for: mode))
                        .font(.system(size: 10, weight: .semibold))
                    Text(mode.title)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(isSelected ? PopoverTheme.accentContrastText : PopoverTheme.textSecondary)
            }

            settingDivider

            settingRow(
                title: "Memory format",
                subtitle: "How RAM appears in menu bar"
            ) {
                optionGroup(
                    selection: $settings.menuBarMemoryFormat,
                    options: MenuBarMetricDisplayFormat.allCases
                ) { format, isSelected in
                    HStack(spacing: 4) {
                        Text(menuBarFormatBadge(for: format))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        Text(format.title)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(isSelected ? PopoverTheme.accentContrastText : PopoverTheme.textSecondary)
                }
            }

            settingDivider

            settingRow(
                title: "Storage format",
                subtitle: "How SSD appears in menu bar"
            ) {
                optionGroup(
                    selection: $settings.menuBarStorageFormat,
                    options: MenuBarMetricDisplayFormat.allCases
                ) { format, isSelected in
                    HStack(spacing: 4) {
                        Text(menuBarFormatBadge(for: format))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        Text(format.title)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(isSelected ? PopoverTheme.accentContrastText : PopoverTheme.textSecondary)
                }
            }
        }
    }

    private var startupSection: some View {
        settingSection(title: "Startup", subtitle: "Set it and forget it") {
            settingRow(
                title: "Launch at login",
                subtitle: settings.launchAtLoginError ?? "Start MacMonitor automatically after login",
                subtitleColor: settings.launchAtLoginError != nil ? PopoverTheme.red : PopoverTheme.textMuted
            ) {
                Toggle("", isOn: $settings.launchAtLoginEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(PopoverTheme.accent)
            }
        }
    }

    private var updatesSection: some View {
        settingSection(title: "Updates", subtitle: "Get new releases safely") {
            VStack(alignment: .leading, spacing: 8) {
                Text(appUpdateController.statusMessage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)

                if let detail = appUpdateController.detailMessage {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Button {
                        appUpdateController.checkForUpdates()
                    } label: {
                        updateActionLabel(
                            title: "Check for Updates",
                            symbol: "arrow.triangle.2.circlepath"
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!appUpdateController.canCheckForUpdates)
                    .opacity(appUpdateController.canCheckForUpdates ? 1 : 0.6)
                }
            }
        }
    }

    private func updateActionLabel(
        title: String,
        symbol: String,
        tint: Color = PopoverTheme.accent
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(PopoverTheme.accentContrastText)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint)
        )
    }

    private func settingSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textMuted)
            }

            content()
        }
        .padding(14)
    }

    private func settingRow<Content: View>(
        title: String,
        subtitle: String,
        subtitleColor: Color = PopoverTheme.textMuted,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PopoverTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(subtitleColor)

            content()
        }
    }

    private var settingDivider: some View {
        Rectangle()
            .fill(PopoverTheme.borderSubtle)
            .frame(height: 1)
            .padding(.vertical, 2)
    }

    private func optionGroup<Option: Identifiable & Hashable, Label: View>(
        selection: Binding<Option>,
        options: [Option],
        @ViewBuilder label: @escaping (Option, Bool) -> Label
    ) -> some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                let isSelected = selection.wrappedValue == option
                Button {
                    selection.wrappedValue = option
                } label: {
                    label(option, isSelected)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isSelected ? PopoverTheme.accent : Color.white.opacity(0.001))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func refreshTitle(for interval: RefreshInterval) -> String {
        switch interval {
        case .oneMinute:
            return "1 min"
        case .threeMinutes:
            return "3 min"
        case .fiveMinutes:
            return "5 min"
        case .tenMinutes:
            return "10 min"
        }
    }

    private func menuBarDisplaySymbol(for mode: MenuBarDisplayMode) -> String {
        switch mode {
        case .memory:
            return "memorychip.fill"
        case .storage:
            return "internaldrive.fill"
        case .cpu:
            return "cpu.fill"
        case .network:
            return "network"
        case .both:
            return "rectangle.3.group"
        case .icon:
            return "app.fill"
        }
    }

    private func menuBarFormatBadge(for format: MenuBarMetricDisplayFormat) -> String {
        switch format {
        case .percentUsage:
            return "%"
        case .numberUsage:
            return "123"
        case .numberLeft:
            return "LFT"
        }
    }
}
