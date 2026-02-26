import SwiftUI

private enum MainPopoverTab: CaseIterable, Hashable {
    case memory
    case storageApps
    case trends
    case settings

    var title: String {
        switch self {
        case .memory:
            return "Memory"
        case .storageApps:
            return "Storage & Apps"
        case .trends:
            return "Trends"
        case .settings:
            return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .memory:
            return "cpu"
        case .storageApps:
            return "internaldrive"
        case .trends:
            return "chart.line.uptrend.xyaxis"
        case .settings:
            return "gearshape"
        }
    }
}

private struct MemoryUsageSegment: Identifiable {
    let id: String
    let title: String
    let bytes: UInt64
    let ratio: Double
    let color: Color
}

private struct StorageUsageSegment: Identifiable {
    let id: String
    let title: String
    let bytes: UInt64
    let ratio: Double
    let color: Color
}

struct PopoverRootView: View {
    @ObservedObject var viewModel: SystemSummaryViewModel
    @ObservedObject var ramDetailsViewModel: RAMDetailsViewModel
    @ObservedObject var ramPolicyViewModel: RAMPolicySettingsViewModel
    @ObservedObject var storageManagementViewModel: StorageManagementViewModel
    @ObservedObject var batteryPolicyCoordinator: BatteryPolicyCoordinator
    @ObservedObject var batteryScheduleViewModel: BatteryScheduleViewModel
    @ObservedObject var settings: SettingsStore
    @ObservedObject var appUpdateController: AppUpdateController
    let diagnosticsExporter: DiagnosticsExporter

    @State private var hasNormalizedLegacyScreen = false
    @State private var diagnosticsStatusMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            content
            footer
        }
        .frame(width: 440, height: 620)
        .background(popoverBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 28, y: 14)
        .preferredColorScheme(settings.appTheme.isDark ? .dark : .light)
        .id(settings.appTheme)
        .onAppear {
            normalizeLegacyScreenIfNeeded()
            ramDetailsViewModel.setMode(.processes)
            ramDetailsViewModel.start()
            storageManagementViewModel.loadIfNeeded()
        }
        .onDisappear {
            ramDetailsViewModel.stop()
        }
        .alert("Terminate selected processes?", isPresented: $ramDetailsViewModel.showingTerminateConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Terminate", role: .destructive) {
                Task { await ramDetailsViewModel.terminateSelected() }
            }
        } message: {
            Text("MacMonitor proceeds with allowed processes only. Protected processes are skipped.")
        }
        .confirmationDialog(
            "Move selected items to Trash?",
            isPresented: $storageManagementViewModel.showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                Task { await storageManagementViewModel.deleteSelected() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Selected: \(storageManagementViewModel.selectedAllowedCount) • " +
                    MetricFormatter.bytes(storageManagementViewModel.selectedAllowedBytes)
            )
        }
        .confirmationDialog(
            "Force quit still-running apps?",
            isPresented: $storageManagementViewModel.showingForceQuitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Force Quit and Move to Trash", role: .destructive) {
                Task { await storageManagementViewModel.confirmForceQuitAndDelete() }
            }
            Button("Skip Running Apps") {
                Task { await storageManagementViewModel.skipForceQuitAndDelete() }
            }
            Button("Cancel Cleanup", role: .cancel) {
                storageManagementViewModel.cancelForceQuitPrompt()
            }
        } message: {
            Text(storageManagementViewModel.forceQuitPromptMessage)
        }
    }

    private var popoverBackground: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            LinearGradient(
                colors: settings.appTheme.isDark
                    ? [Color.black.opacity(0.52), Color.black.opacity(0.34)]
                    : [Color.white.opacity(0.72), Color.white.opacity(0.54)],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: settings.appTheme.isDark
                    ? [Color.white.opacity(0.05), Color.clear, Color(hex: 0x5E5CE6, opacity: 0.12)]
                    : [Color.white.opacity(0.38), Color.clear, Color(hex: 0x5E5CE6, opacity: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Label {
                    Text("MacMonitor")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PopoverTheme.textPrimary)
                } icon: {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PopoverTheme.accent)
                }
                .labelStyle(.titleAndIcon)

                Spacer(minLength: 8)

                thermalStatusBadge

                Button {
                    toggleTheme()
                } label: {
                    Image(systemName: settings.appTheme.isDark ? "sun.max" : "moon")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(PopoverTheme.bgCard.opacity(0.6))
                        )
                }
                .buttonStyle(.plain)
                .help("Toggle Light/Dark Theme")
            }

            HStack(spacing: 6) {
                ForEach(MainPopoverTab.allCases, id: \.self) { tab in
                    mainTabButton(tab)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(PopoverTheme.bgPanel.opacity(0.72))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PopoverTheme.borderSubtle)
                .frame(height: 1)
        }
    }

    private var thermalStatusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(thermalColor(for: viewModel.thermalState))
                .frame(width: 8, height: 8)
                .shadow(color: thermalColor(for: viewModel.thermalState).opacity(0.6), radius: 6)

            Text(viewModel.thermalState.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PopoverTheme.textSecondary)

            if viewModel.isStale {
                Text("Stale")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(PopoverTheme.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(PopoverTheme.orangeDim)
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(PopoverTheme.bgCard.opacity(0.65))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func mainTabButton(_ tab: MainPopoverTab) -> some View {
        let isActive = activeTab == tab

        return Button {
            switchToTab(tab)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 16, weight: .medium))
                Text(tab.title)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .foregroundStyle(isActive ? PopoverTheme.textPrimary : PopoverTheme.textMuted)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? PopoverTheme.bgCard : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isActive ? PopoverTheme.borderMedium : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var content: some View {
        ScrollView(showsIndicators: true) {
            Group {
                switch viewModel.screen {
                case .storageManagement:
                    storageManagementScreen
                case .ramPolicyManager:
                    policiesScreen
                case .storage:
                    storageOverviewScreen
                case .trends:
                    trendsOverviewScreen
                case .settings:
                    settingsOverviewScreen
                case .battery:
                    batteryOverviewScreen
                case .temperature, .ram:
                    memoryOverviewScreen
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    private var batteryOverviewScreen: some View {
        BatteryScreenView(
            battery: viewModel.snapshot?.battery,
            settings: settings,
            coordinator: batteryPolicyCoordinator,
            scheduleViewModel: batteryScheduleViewModel
        )
    }

    private var memoryOverviewScreen: some View {
        VStack(alignment: .leading, spacing: 16) {
            memorySummaryCard
            memoryProcessesCard
        }
        .onAppear {
            if viewModel.screen != .ram {
                viewModel.showRAM()
            }
            ramDetailsViewModel.setMode(.processes)
            ramDetailsViewModel.start()
            ramDetailsViewModel.refresh()
        }
    }

    @ViewBuilder
    private var memorySummaryCard: some View {
        if let memory = viewModel.snapshot?.memory {
            let segments = memorySegments(for: memory)

            panelCard {
                Text("Physical Memory")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PopoverTheme.textMuted)
                    .tracking(0.5)

                HStack {
                    Text("\(MetricFormatter.bytes(memory.totalBytes)) Total")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PopoverTheme.textSecondary)

                    Spacer(minLength: 8)

                    Text("\(MetricFormatter.bytes(memory.usedBytes)) Used")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PopoverTheme.textPrimary)
                }

                usageTrack(segments: segments)
                    .frame(height: 10)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(segments) { segment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(segment.color)
                                    .frame(width: 7, height: 7)

                                Text(segment.title)
                                    .font(.system(size: 11))
                                    .foregroundStyle(PopoverTheme.textMuted)
                                    .lineLimit(1)
                            }

                            Text(MetricFormatter.bytes(segment.bytes))
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(PopoverTheme.textPrimary)
                        }
                    }
                }
            }
        } else {
            panelCard {
                Text("Collecting memory metrics...")
                    .font(.system(size: 12))
                    .foregroundStyle(PopoverTheme.textMuted)
            }
        }
    }

    private var memoryProcessesCard: some View {
        panelCard {
            HStack {
                Text("Top Memory Processes")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PopoverTheme.textMuted)
                    .tracking(0.5)

                Spacer(minLength: 6)

                Button {
                    ramDetailsViewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PopoverTheme.textMuted)
                }
                .buttonStyle(.plain)
                .help("Refresh process list")
                .disabled(ramDetailsViewModel.isLoading)
            }

            HStack {
                Text("Process Name")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PopoverTheme.textMuted)
                Spacer(minLength: 8)
                Text("Memory")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PopoverTheme.textMuted)
            }
            .padding(.bottom, 4)

            let rows = Array(ramDetailsViewModel.processes.prefix(10))

            if rows.isEmpty {
                HStack(spacing: 8) {
                    if ramDetailsViewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Text(ramDetailsViewModel.isLoading ? "Loading processes..." : "No process data available yet.")
                        .font(.system(size: 12))
                        .foregroundStyle(PopoverTheme.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(rows) { process in
                        processRow(process)
                    }
                }
            }

            if let resultMessage = ramDetailsViewModel.resultMessage {
                Text(resultMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(PopoverTheme.green)
                    .lineLimit(2)
            }

            if let errorMessage = ramDetailsViewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(PopoverTheme.red)
                    .lineLimit(2)
            }

            Button {
                ramDetailsViewModel.requestTerminateSelected()
            } label: {
                Label(terminateButtonTitle, systemImage: "xmark.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundStyle(ramDetailsViewModel.canTerminateSelection ? PopoverTheme.red : PopoverTheme.textMuted)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(ramDetailsViewModel.canTerminateSelection ? PopoverTheme.redDim : PopoverTheme.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        ramDetailsViewModel.canTerminateSelection ? PopoverTheme.red.opacity(0.25) : PopoverTheme.borderSubtle,
                        lineWidth: 1
                    )
            )
            .disabled(!ramDetailsViewModel.canTerminateSelection)
            .help(ramDetailsViewModel.terminationInfoTooltip)
        }
    }

    private func processRow(_ process: ProcessMemoryItem) -> some View {
        let isSelected = ramDetailsViewModel.selectedProcessIDs.contains(process.pid)

        return Button {
            ramDetailsViewModel.toggleSelection(for: process.pid)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: checkboxSymbol(for: process, isSelected: isSelected))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(checkboxColor(for: process, isSelected: isSelected))

                VStack(alignment: .leading, spacing: 2) {
                    Text(process.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(process.isProtected ? PopoverTheme.textMuted : PopoverTheme.textPrimary)
                        .lineLimit(1)

                    Text(process.isProtected ? "Protected" : process.metricLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverTheme.textMuted)
                }

                Spacer(minLength: 8)

                Text(MetricFormatter.bytes(process.rankingBytes))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(PopoverTheme.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PopoverTheme.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(process.isProtected || ramDetailsViewModel.isTerminating)
        .opacity(process.isProtected ? 0.65 : 1.0)
    }

    private var storageOverviewScreen: some View {
        VStack(alignment: .leading, spacing: 16) {
            storageSummaryCard
            storageAutomationCard
            storageAppsCard

            if let resultMessage = storageManagementViewModel.resultMessage, !resultMessage.isEmpty {
                infoBanner(text: resultMessage, tint: PopoverTheme.green, background: PopoverTheme.greenDim)
            }

            if let errorMessage = storageManagementViewModel.errorMessage, !errorMessage.isEmpty {
                infoBanner(text: errorMessage, tint: PopoverTheme.red, background: PopoverTheme.redDim)
            }
        }
        .onAppear {
            if viewModel.screen != .storage {
                viewModel.showStorage()
            }
            storageManagementViewModel.loadIfNeeded()
        }
    }

    private var storageSummaryCard: some View {
        let segments = storageSegments()

        return panelCard {
            Label {
                Text("Macintosh HD")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PopoverTheme.textMuted)
                    .tracking(0.5)
            } icon: {
                Image(systemName: "internaldrive")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textMuted)
            }

            HStack {
                Text("\(MetricFormatter.bytes(storageManagementViewModel.currentTotalBytes)) Total")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PopoverTheme.textSecondary)

                Spacer(minLength: 8)

                Text("\(MetricFormatter.bytes(storageManagementViewModel.currentUsedBytes)) Used")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PopoverTheme.textPrimary)
            }

            usageTrack(segments: segments)
                .frame(height: 12)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 8
            ) {
                ForEach(segments) { segment in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(segment.color)
                                .frame(width: 7, height: 7)
                            Text(segment.title)
                                .font(.system(size: 10))
                                .foregroundStyle(PopoverTheme.textMuted)
                                .lineLimit(1)
                        }

                        Text(MetricFormatter.bytes(segment.bytes))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PopoverTheme.textPrimary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var storageAutomationCard: some View {
        panelCard {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cleanup Selection")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PopoverTheme.textPrimary)

                    Text(
                        storageManagementViewModel.selectedAllowedBytes > 0
                            ? "Ready to remove \(MetricFormatter.bytes(storageManagementViewModel.selectedAllowedBytes))."
                            : "Scan and select app data you want to move to Trash."
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(PopoverTheme.textMuted)
                }

                Spacer(minLength: 8)

                Button {
                    viewModel.showStorageManagement()
                } label: {
                    Text("Open")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PopoverTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(PopoverTheme.bgElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var storageAppsCard: some View {
        panelCard {
            HStack {
                Label {
                    Text("Installed Applications")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .tracking(0.5)
                } icon: {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PopoverTheme.textMuted)
                }

                Spacer(minLength: 8)

                Button {
                    storageManagementViewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PopoverTheme.textMuted)
                }
                .buttonStyle(.plain)
                .disabled(storageManagementViewModel.isScanning)
                .help("Refresh storage scan")
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PopoverTheme.textMuted)

                TextField("Search applications...", text: $storageManagementViewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(PopoverTheme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PopoverTheme.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
            )

            HStack {
                Text("Application")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PopoverTheme.textMuted)

                Spacer(minLength: 8)

                Text("Size")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PopoverTheme.textMuted)

                Spacer().frame(width: 52)
            }
            .padding(.horizontal, 2)

            let groups = Array(storageManagementViewModel.visibleAppGroups.prefix(8))

            if groups.isEmpty {
                HStack(spacing: 8) {
                    if storageManagementViewModel.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Text(storageManagementViewModel.isScanning ? "Scanning applications..." : "No apps found for this query.")
                        .font(.system(size: 12))
                        .foregroundStyle(PopoverTheme.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(groups) { group in
                        storageAppRow(group)
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    storageManagementViewModel.requestDeleteSelection()
                } label: {
                    Text(storageDeleteButtonTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .foregroundStyle(storageManagementViewModel.canDeleteSelection ? PopoverTheme.red : PopoverTheme.textMuted)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(storageManagementViewModel.canDeleteSelection ? PopoverTheme.redDim : PopoverTheme.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            storageManagementViewModel.canDeleteSelection ? PopoverTheme.red.opacity(0.24) : PopoverTheme.borderSubtle,
                            lineWidth: 1
                        )
                )
                .disabled(!storageManagementViewModel.canDeleteSelection)

                Button {
                    viewModel.showStorageManagement()
                } label: {
                    Text("Manage")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .foregroundStyle(PopoverTheme.textPrimary)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PopoverTheme.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
                )
            }
        }
    }

    private func storageAppRow(_ group: StorageAppGroup) -> some View {
        let selectionState = storageManagementViewModel.groupSelectionState(group)

        return HStack(spacing: 10) {
            Button {
                storageManagementViewModel.toggleGroupSelection(group.id)
            } label: {
                Image(systemName: selectionStateSymbol(selectionState))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(selectionStateColor(selectionState))
                    .frame(width: 18)
            }
            .buttonStyle(.plain)

            Image(systemName: "app.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PopoverTheme.blue)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PopoverTheme.textPrimary)
                    .lineLimit(1)

                Text(group.bundleIdentifier ?? "\(group.items.count) cleanup targets")
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(MetricFormatter.bytes(group.totalBytes))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(PopoverTheme.textSecondary)
                .frame(minWidth: 72, alignment: .trailing)

            Button {
                quickDelete(group)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PopoverTheme.red)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(PopoverTheme.redDim)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PopoverTheme.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var settingsOverviewScreen: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsMenuBarCard
            settingsAlertsCard
            settingsAdvancedBatteryCard
            settingsGeneralCard
            settingsDiagnosticsCard
            settingsAboutCard

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit MacMonitor", systemImage: "power")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundStyle(settingsTextMain)
            .background(settingsInputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(settingsCardBorder, lineWidth: 1)
            )
        }
        .onAppear {
            if viewModel.screen != .settings {
                viewModel.showSettings()
            }
            ramPolicyViewModel.refresh()
        }
    }

    private var settingsMenuBarCard: some View {
        settingsCard {
            settingsSectionHeader("Menu Bar Display Status", symbol: "rectangle.topthird.inset.filled")

            settingsPickerRow(
                title: "Display Metric",
                selection: $settings.menuBarDisplayMode,
                options: MenuBarDisplayMode.allCases
            ) { option in
                option.title
            }

            settingsDivider

            settingsPickerRow(
                title: "Memory Format",
                selection: $settings.menuBarMemoryFormat,
                options: MenuBarMetricDisplayFormat.allCases
            ) { option in
                option.title
            }

            settingsDivider

            settingsPickerRow(
                title: "Storage Format",
                selection: $settings.menuBarStorageFormat,
                options: MenuBarMetricDisplayFormat.allCases
            ) { option in
                option.title
            }
        }
    }

    private var settingsGeneralCard: some View {
        settingsCard {
            settingsSectionHeader("General", symbol: "slider.horizontal.3")

            settingsToggleRow(
                title: "Launch at Login",
                subtitle: settings.launchAtLoginError ?? "Start MacMonitor automatically after login.",
                subtitleColor: settings.launchAtLoginError == nil ? settingsTextMuted : PopoverTheme.red,
                isOn: $settings.launchAtLoginEnabled
            )
        }
    }

    private var settingsAlertsCard: some View {
        settingsCard {
            settingsSectionHeader("Alerts", symbol: "bell.badge")

            settingsToggleRow(
                title: "Thermal Alerts",
                subtitle: "Notify when thermal pressure reaches threshold.",
                isOn: Binding(
                    get: { settings.systemAlertSettings.thermalAlertEnabled },
                    set: { newValue in
                        var alertSettings = settings.systemAlertSettings
                        alertSettings.thermalAlertEnabled = newValue
                        settings.systemAlertSettings = alertSettings
                    }
                )
            )

            settingsDivider

            settingsPickerRow(
                title: "Thermal Threshold",
                selection: Binding(
                    get: { settings.systemAlertSettings.thermalThreshold },
                    set: { newValue in
                        var alertSettings = settings.systemAlertSettings
                        alertSettings.thermalThreshold = newValue
                        settings.systemAlertSettings = alertSettings
                    }
                ),
                options: [.fair, .serious, .critical]
            ) { option in
                option.title
            }

            settingsDivider

            settingsPickerRow(
                title: "Storage Threshold",
                selection: Binding(
                    get: { settings.systemAlertSettings.storageUsagePercentThreshold },
                    set: { newValue in
                        var alertSettings = settings.systemAlertSettings
                        alertSettings.storageUsagePercentThreshold = newValue
                        settings.systemAlertSettings = alertSettings
                    }
                ),
                options: [80, 85, 90, 95]
            ) { value in
                "\(value)%"
            }

            settingsDivider

            settingsPickerRow(
                title: "Alert Cooldown",
                selection: Binding(
                    get: { settings.systemAlertSettings.cooldownMinutes },
                    set: { newValue in
                        var alertSettings = settings.systemAlertSettings
                        alertSettings.cooldownMinutes = newValue
                        settings.systemAlertSettings = alertSettings
                    }
                ),
                options: [15, 30, 45, 60, 120]
            ) { value in
                "\(value)m"
            }
        }
    }

    private var settingsAdvancedBatteryCard: some View {
        settingsCard {
            settingsSectionHeader("Advanced Battery (Gated)", symbol: "shield.lefthalf.filled")

            settingsToggleRow(
                title: "Sleep-aware Stop Charging",
                subtitle: "Pause charging before system sleep transitions.",
                isOn: Binding(
                    get: { settings.batteryAdvancedControlFeatureFlags.sleepAwareStopChargingEnabled },
                    set: { value in
                        var flags = settings.batteryAdvancedControlFeatureFlags
                        flags.sleepAwareStopChargingEnabled = value
                        settings.batteryAdvancedControlFeatureFlags = flags
                    }
                )
            )

            settingsDivider

            settingsToggleRow(
                title: "Block Sleep Until Limit",
                subtitle: "Attempt limit recovery before sleep when below charge target.",
                isOn: Binding(
                    get: { settings.batteryAdvancedControlFeatureFlags.blockSleepUntilLimitEnabled },
                    set: { value in
                        var flags = settings.batteryAdvancedControlFeatureFlags
                        flags.blockSleepUntilLimitEnabled = value
                        settings.batteryAdvancedControlFeatureFlags = flags
                    }
                )
            )

            settingsDivider

            settingsToggleRow(
                title: "Calibration Workflow",
                subtitle: "Enable calibration lifecycle hooks (experimental).",
                isOn: Binding(
                    get: { settings.batteryAdvancedControlFeatureFlags.calibrationWorkflowEnabled },
                    set: { value in
                        var flags = settings.batteryAdvancedControlFeatureFlags
                        flags.calibrationWorkflowEnabled = value
                        settings.batteryAdvancedControlFeatureFlags = flags
                    }
                )
            )

            settingsDivider

            settingsToggleRow(
                title: "Hardware Percentage Refinement",
                subtitle: "Use refined fallback battery percentage parsing.",
                isOn: Binding(
                    get: { settings.batteryAdvancedControlFeatureFlags.hardwarePercentageRefinementEnabled },
                    set: { value in
                        var flags = settings.batteryAdvancedControlFeatureFlags
                        flags.hardwarePercentageRefinementEnabled = value
                        settings.batteryAdvancedControlFeatureFlags = flags
                    }
                )
            )

            settingsDivider

            settingsToggleRow(
                title: "MagSafe LED Control",
                subtitle: "Reserved for supported hardware paths.",
                isOn: Binding(
                    get: { settings.batteryAdvancedControlFeatureFlags.magsafeLEDControlEnabled },
                    set: { value in
                        var flags = settings.batteryAdvancedControlFeatureFlags
                        flags.magsafeLEDControlEnabled = value
                        settings.batteryAdvancedControlFeatureFlags = flags
                    }
                )
            )
        }
    }

    private var settingsDiagnosticsCard: some View {
        settingsCard {
            settingsSectionHeader("Diagnostics", symbol: "stethoscope")

            Text("Create a local support bundle with sanitized settings, snapshots, and battery lifecycle events.")
                .font(.system(size: 11))
                .foregroundStyle(settingsTextMuted)

            Button {
                exportDiagnostics()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Export Diagnostics")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(PopoverTheme.accentContrastText)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(PopoverTheme.accent)
                )
            }
            .buttonStyle(.plain)

            if let diagnosticsStatusMessage {
                Text(diagnosticsStatusMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(settingsTextMuted)
                    .lineLimit(2)
            }
        }
    }

    private var settingsAboutCard: some View {
        settingsCard {
            HStack(alignment: .center, spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(settingsCardBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.24), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 4) {
                    Text("MacMonitor")
                        .font(.system(size: 16.5, weight: .semibold))
                        .foregroundStyle(settingsTextMain)

                    Text("Version \(appSemanticVersion)")
                        .font(.system(size: 12))
                        .foregroundStyle(settingsTextMuted)

                    Text("Apple Silicon Optimized")
                        .font(.system(size: 11))
                        .foregroundStyle(settingsTextMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func settingsToggleRow(
        title: String,
        subtitle: String,
        subtitleColor: Color = PopoverTheme.textMuted,
        isOn: Binding<Bool>,
        isEnabled: Bool = true
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(settingsTextMain)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(settingsToggleTint)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1.0 : 0.6)
        }
    }

    private func settingsPickerRow<Option: Hashable>(
        title: String,
        selection: Binding<Option>,
        options: [Option],
        optionTitle: @escaping (Option) -> String
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(settingsTextMain)

            Spacer(minLength: 8)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection.wrappedValue = option
                    } label: {
                        Text(optionTitle(option))
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(optionTitle(selection.wrappedValue))
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(settingsTextMain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(width: settingsPickerWidth, alignment: .leading)
                .background(settingsInputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(settingsCardBorder, lineWidth: 1)
                )
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .frame(width: settingsPickerWidth, alignment: .trailing)
        }
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(settingsCardBorder)
            .frame(height: 1)
    }

    private var settingsTextMain: Color {
        settings.appTheme.isDark ? Color(hex: 0xF5F5F7) : Color(hex: 0x1D1D1F)
    }

    private var settingsTextMuted: Color {
        settings.appTheme.isDark ? Color(hex: 0xA1A1A6) : Color(hex: 0x86868B)
    }

    private var settingsCardFill: Color {
        settings.appTheme.isDark ? Color.white.opacity(0.04) : Color.white.opacity(0.62)
    }

    private var settingsCardBorder: Color {
        settings.appTheme.isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    private var settingsInputBackground: Color {
        settings.appTheme.isDark ? Color.black.opacity(0.26) : Color.black.opacity(0.04)
    }

    private var settingsToggleTint: Color {
        Color(hex: 0x32D74B)
    }

    private func settingsSectionHeader(_ title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.45)
        }
        .foregroundStyle(settingsTextMuted)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(settingsCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(settingsCardBorder, lineWidth: 1)
        )
    }

    private var settingsPickerWidth: CGFloat {
        96
    }

    private func infoBanner(text: String, tint: Color, background: Color) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(background.opacity(0.7))
            )
    }

    private var storageManagementScreen: some View {
        StorageManagementView(
            viewModel: storageManagementViewModel,
            onBack: viewModel.showStorage
        )
    }

    private var trendsOverviewScreen: some View {
        TrendsView(viewModel: viewModel)
            .onAppear {
                if viewModel.screen != .trends {
                    viewModel.showTrends()
                }
            }
    }

    private var policiesScreen: some View {
        RAMPolicySettingsView(
            viewModel: ramPolicyViewModel,
            onBack: viewModel.showSettings
        )
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if appUpdateController.canRestartToInstallUpdate {
                Button {
                    appUpdateController.restartToInstallUpdate()
                } label: {
                    Label("Restart to Update", systemImage: "arrow.clockwise.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(hex: 0x0A84FF))
                        )
                }
                .buttonStyle(.plain)
            } else {
                Label("Power Optimized", systemImage: "bolt.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PopoverTheme.textMuted)
            }

            Spacer(minLength: 8)

            Text(appVersionLabel)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(PopoverTheme.textMuted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(PopoverTheme.bgPanel.opacity(0.72))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PopoverTheme.borderSubtle)
                .frame(height: 1)
        }
    }

    private func panelCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func usageTrack(segments: [MemoryUsageSegment]) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(PopoverTheme.borderMedium)

                HStack(spacing: 0) {
                    ForEach(segments) { segment in
                        Rectangle()
                            .fill(segment.color)
                            .frame(width: geometry.size.width * max(0, min(segment.ratio, 1)))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    private func usageTrack(segments: [StorageUsageSegment]) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(PopoverTheme.borderMedium)

                HStack(spacing: 0) {
                    ForEach(segments) { segment in
                        Rectangle()
                            .fill(segment.color)
                            .frame(width: geometry.size.width * max(0, min(segment.ratio, 1)))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    private func memorySegments(for memory: MemorySnapshot) -> [MemoryUsageSegment] {
        let total = max(memory.totalBytes, 1)
        let usedBytes = min(memory.usedBytes, total)
        let compressedBytes = min(memory.compressedBytes ?? 0, total)
        let cachedBytes = min(memory.inactiveBytes ?? 0, total)
        let accountedBytes = min(total, usedBytes + compressedBytes + cachedBytes)
        let freeBytes = max(total - accountedBytes, 0)

        let rawSegments: [(id: String, title: String, bytes: UInt64, color: Color)] = [
            ("used", "Used", usedBytes, PopoverTheme.accent),
            ("compressed", "Compressed", compressedBytes, PopoverTheme.blue),
            ("cached", "Cached Files", cachedBytes, PopoverTheme.orange),
            ("free", "Free", freeBytes, PopoverTheme.textMuted)
        ]

        return rawSegments.map { segment in
            MemoryUsageSegment(
                id: segment.id,
                title: segment.title,
                bytes: segment.bytes,
                ratio: Double(segment.bytes) / Double(total),
                color: segment.color
            )
        }
    }

    private func storageSegments() -> [StorageUsageSegment] {
        let total = max(storageManagementViewModel.currentTotalBytes, 1)
        let used = storageManagementViewModel.currentUsedBytes

        let appBytes = min(storageManagementViewModel.appGroups.reduce(UInt64(0)) { $0 + $1.totalBytes }, used)
        let cacheCandidates = storageManagementViewModel.looseItems
            .filter { $0.category == .cache }
            .reduce(UInt64(0)) { $0 + $1.sizeBytes }
        let cacheBytes = min(cacheCandidates, max(used - appBytes, 0))
        let folderBytes = max(used - appBytes - cacheBytes, 0)

        let rawSegments: [(id: String, title: String, bytes: UInt64, color: Color)] = [
            ("apps", "Apps", appBytes, PopoverTheme.blue),
            ("folders", "Folders", folderBytes, PopoverTheme.purple),
            ("cache", "Cache", cacheBytes, PopoverTheme.green)
        ]

        return rawSegments.map { segment in
            StorageUsageSegment(
                id: segment.id,
                title: segment.title,
                bytes: segment.bytes,
                ratio: Double(segment.bytes) / Double(total),
                color: segment.color
            )
        }
    }

    private func selectionStateSymbol(_ state: StorageSelectionState) -> String {
        switch state {
        case .none:
            return "circle"
        case .partial:
            return "minus.circle.fill"
        case .all:
            return "checkmark.circle.fill"
        }
    }

    private func selectionStateColor(_ state: StorageSelectionState) -> Color {
        switch state {
        case .none:
            return PopoverTheme.textMuted
        case .partial:
            return PopoverTheme.orange
        case .all:
            return PopoverTheme.accent
        }
    }

    private func quickDelete(_ group: StorageAppGroup) {
        storageManagementViewModel.clearPresetSelection()
        if storageManagementViewModel.groupSelectionState(group) != .all {
            storageManagementViewModel.toggleGroupSelection(group.id)
        }
        storageManagementViewModel.requestDeleteSelection()
    }

    private var storageDeleteButtonTitle: String {
        let count = storageManagementViewModel.selectedAllowedCount
        if count > 0 {
            return "Move to Trash (\(count))"
        }
        return "Move to Trash"
    }

    private var terminateButtonTitle: String {
        let count = ramDetailsViewModel.selectedAllowedCount
        if count > 0 {
            return "Quit (\(count))"
        }
        return "Quit Selected Processes"
    }

    private func checkboxSymbol(for process: ProcessMemoryItem, isSelected: Bool) -> String {
        if process.isProtected {
            return "lock.fill"
        }
        return isSelected ? "checkmark.square.fill" : "square"
    }

    private func checkboxColor(for process: ProcessMemoryItem, isSelected: Bool) -> Color {
        if process.isProtected {
            return PopoverTheme.textMuted
        }
        return isSelected ? PopoverTheme.accent : PopoverTheme.textMuted
    }

    private var appSemanticVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private var appVersionLabel: String {
        "v\(appSemanticVersion)"
    }

    private var activeTab: MainPopoverTab {
        switch viewModel.screen {
        case .storage, .storageManagement:
            return .storageApps
        case .trends:
            return .trends
        case .settings, .ramPolicyManager:
            return .settings
        case .temperature, .battery, .ram:
            return .memory
        }
    }

    private func switchToTab(_ tab: MainPopoverTab) {
        switch tab {
        case .memory:
            viewModel.showRAM()
        case .storageApps:
            viewModel.showStorage()
        case .trends:
            viewModel.showTrends()
        case .settings:
            viewModel.showSettings()
        }
    }

    private func normalizeLegacyScreenIfNeeded() {
        guard !hasNormalizedLegacyScreen else { return }
        hasNormalizedLegacyScreen = true

        switch viewModel.screen {
        case .temperature:
            viewModel.showRAM()
        case .battery, .ram, .storage, .trends, .storageManagement, .settings, .ramPolicyManager:
            break
        }
    }

    private func exportDiagnostics() {
        do {
            let bundleURL = try diagnosticsExporter.exportDiagnosticsBundle(
                settings: settings,
                snapshot: viewModel.snapshot,
                history: viewModel.history,
                recentBatteryEvents: batteryPolicyCoordinator.recentEvents,
                updateStatusMessage: appUpdateController.statusMessage,
                helperAvailability: batteryPolicyCoordinator.helperAvailability
            )

            diagnosticsStatusMessage = "Saved: \(bundleURL.lastPathComponent)"
            NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
        } catch {
            diagnosticsStatusMessage = "Diagnostics export failed: \(error.localizedDescription)"
        }
    }

    private func toggleTheme() {
        withAnimation(.easeInOut(duration: 0.2)) {
            settings.appTheme = pairedTheme(for: settings.appTheme)
        }
    }

    private func pairedTheme(for theme: AppTheme) -> AppTheme {
        switch theme {
        case .lime:
            return .daylight
        case .midnight:
            return .arctic
        case .cyber:
            return .sand
        case .daylight:
            return .lime
        case .arctic:
            return .midnight
        case .sand:
            return .cyber
        }
    }

    private func thermalColor(for state: ThermalState) -> Color {
        switch state {
        case .nominal:
            return PopoverTheme.green
        case .fair:
            return PopoverTheme.yellow
        case .serious:
            return PopoverTheme.orange
        case .critical:
            return PopoverTheme.red
        case .unknown:
            return PopoverTheme.textMuted
        }
    }
}
// MARK: - Theme Palette

struct ThemePalette {
    let bgDeep: Color
    let bgPanel: Color
    let bgCard: Color
    let bgCardHover: Color
    let bgElevated: Color

    let borderSubtle: Color
    let borderMedium: Color
    let borderActive: Color

    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color

    let accent: Color
    let accentDim: Color

    let blue: Color
    let blueDim: Color
    let blueGlow: Color

    let green: Color
    let greenDim: Color

    let yellow: Color
    let yellowDim: Color

    let orange: Color
    let orangeDim: Color

    let red: Color
    let redDim: Color

    let mint: Color
    let mintDim: Color

    let purple: Color
    let purpleDim: Color

    /// Toggle knob and accent-on-accent text color
    let accentContrastText: Color

    /// Toggle track off state
    let toggleOffTrack: Color
    let toggleOffKnob: Color
}

// MARK: - PopoverTheme (dynamic)

enum PopoverTheme {
    nonisolated(unsafe) private(set) static var current: ThemePalette = palette(for: .lime)

    @MainActor
    static func applyTheme(_ theme: AppTheme) {
        current = palette(for: theme)
    }

    // ── Convenience accessors (keeps every call site unchanged) ──

    static var bgDeep: Color { current.bgDeep }
    static var bgPanel: Color { current.bgPanel }
    static var bgCard: Color { current.bgCard }
    static var bgCardHover: Color { current.bgCardHover }
    static var bgElevated: Color { current.bgElevated }

    static var borderSubtle: Color { current.borderSubtle }
    static var borderMedium: Color { current.borderMedium }
    static var borderActive: Color { current.borderActive }

    static var textPrimary: Color { current.textPrimary }
    static var textSecondary: Color { current.textSecondary }
    static var textMuted: Color { current.textMuted }

    static var accent: Color { current.accent }
    static var accentDim: Color { current.accentDim }

    static var blue: Color { current.blue }
    static var blueDim: Color { current.blueDim }
    static var blueGlow: Color { current.blueGlow }

    static var green: Color { current.green }
    static var greenDim: Color { current.greenDim }

    static var yellow: Color { current.yellow }
    static var yellowDim: Color { current.yellowDim }

    static var orange: Color { current.orange }
    static var orangeDim: Color { current.orangeDim }

    static var red: Color { current.red }
    static var redDim: Color { current.redDim }

    static var mint: Color { current.mint }
    static var mintDim: Color { current.mintDim }

    static var purple: Color { current.purple }
    static var purpleDim: Color { current.purpleDim }

    static var accentContrastText: Color { current.accentContrastText }
    static var toggleOffTrack: Color { current.toggleOffTrack }
    static var toggleOffKnob: Color { current.toggleOffKnob }

    // ── Palette factory ──

    static func palette(for theme: AppTheme) -> ThemePalette {
        switch theme {
        case .lime:     return limePalette
        case .midnight: return midnightPalette
        case .cyber:    return cyberPalette
        case .daylight: return daylightPalette
        case .arctic:   return arcticPalette
        case .sand:     return sandPalette
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // DARK THEMES
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private static let limePalette = ThemePalette(
        bgDeep:          Color(hex: 0x17171B),
        bgPanel:         Color(hex: 0x1D1D21),
        bgCard:          Color(hex: 0x232329),
        bgCardHover:     Color(hex: 0x2A2A30),
        bgElevated:      Color(hex: 0x202026),
        borderSubtle:    Color.white.opacity(0.09),
        borderMedium:    Color.white.opacity(0.14),
        borderActive:    Color(hex: 0x5E5CE6, opacity: 0.36),
        textPrimary:     Color(hex: 0xF5F5F7),
        textSecondary:   Color(hex: 0xC1C1C8),
        textMuted:       Color(hex: 0xA1A1A6),
        accent:          Color(hex: 0x5E5CE6),
        accentDim:       Color(hex: 0x5E5CE6, opacity: 0.12),
        blue:            Color(hex: 0x0A84FF),
        blueDim:         Color(hex: 0x0A84FF, opacity: 0.12),
        blueGlow:        Color(hex: 0x0A84FF, opacity: 0.18),
        green:           Color(hex: 0x32D74B),
        greenDim:        Color(hex: 0x32D74B, opacity: 0.12),
        yellow:          Color(hex: 0xFFD60A),
        yellowDim:       Color(hex: 0xFFD60A, opacity: 0.12),
        orange:          Color(hex: 0xFF9F0A),
        orangeDim:       Color(hex: 0xFF9F0A, opacity: 0.12),
        red:             Color(hex: 0xFF453A),
        redDim:          Color(hex: 0xFF453A, opacity: 0.12),
        mint:            Color(hex: 0x64D2FF),
        mintDim:         Color(hex: 0x64D2FF, opacity: 0.12),
        purple:          Color(hex: 0xBF5AF2),
        purpleDim:       Color(hex: 0xBF5AF2, opacity: 0.12),
        accentContrastText: .white,
        toggleOffTrack:  Color(hex: 0x787880, opacity: 0.35),
        toggleOffKnob:   .white
    )

    private static let midnightPalette = ThemePalette(
        bgDeep:          Color(hex: 0x000000),
        bgPanel:         Color(hex: 0x0a0a0a),
        bgCard:          Color(hex: 0x111111),
        bgCardHover:     Color(hex: 0x1a1a1a),
        bgElevated:      Color(hex: 0x0d0d0d),
        borderSubtle:    Color.white.opacity(0.06),
        borderMedium:    Color.white.opacity(0.10),
        borderActive:    Color(hex: 0x3b82f6, opacity: 0.40),
        textPrimary:     Color(hex: 0xf0f0f0),
        textSecondary:   Color(hex: 0x7a7a7a),
        textMuted:       Color(hex: 0x444444),
        accent:          Color(hex: 0x3b82f6),
        accentDim:       Color(hex: 0x3b82f6, opacity: 0.12),
        blue:            Color(hex: 0x3b82f6),
        blueDim:         Color(hex: 0x3b82f6, opacity: 0.12),
        blueGlow:        Color(hex: 0x3b82f6, opacity: 0.15),
        green:           Color(hex: 0x22c55e),
        greenDim:        Color(hex: 0x22c55e, opacity: 0.12),
        yellow:          Color(hex: 0xeab308),
        yellowDim:       Color(hex: 0xeab308, opacity: 0.12),
        orange:          Color(hex: 0xf97316),
        orangeDim:       Color(hex: 0xf97316, opacity: 0.12),
        red:             Color(hex: 0xef4444),
        redDim:          Color(hex: 0xef4444, opacity: 0.12),
        mint:            Color(hex: 0x06b6d4),
        mintDim:         Color(hex: 0x06b6d4, opacity: 0.12),
        purple:          Color(hex: 0x8b5cf6),
        purpleDim:       Color(hex: 0x8b5cf6, opacity: 0.12),
        accentContrastText: .white,
        toggleOffTrack:  Color.white.opacity(0.10),
        toggleOffKnob:   .white
    )

    private static let cyberPalette = ThemePalette(
        bgDeep:          Color(hex: 0x0a0a0f),
        bgPanel:         Color(hex: 0x0f0f18),
        bgCard:          Color(hex: 0x141420),
        bgCardHover:     Color(hex: 0x1a1a2e),
        bgElevated:      Color(hex: 0x121220),
        borderSubtle:    Color(hex: 0x00ffff, opacity: 0.10),
        borderMedium:    Color(hex: 0x00ffff, opacity: 0.16),
        borderActive:    Color(hex: 0x00ffcc, opacity: 0.40),
        textPrimary:     Color(hex: 0xe0ffe0),
        textSecondary:   Color(hex: 0x66cc99),
        textMuted:       Color(hex: 0x336655),
        accent:          Color(hex: 0x00ffcc),
        accentDim:       Color(hex: 0x00ffcc, opacity: 0.10),
        blue:            Color(hex: 0x00ccff),
        blueDim:         Color(hex: 0x00ccff, opacity: 0.12),
        blueGlow:        Color(hex: 0x00ccff, opacity: 0.15),
        green:           Color(hex: 0x00ff66),
        greenDim:        Color(hex: 0x00ff66, opacity: 0.12),
        yellow:          Color(hex: 0xffff00),
        yellowDim:       Color(hex: 0xffff00, opacity: 0.12),
        orange:          Color(hex: 0xff6600),
        orangeDim:       Color(hex: 0xff6600, opacity: 0.12),
        red:             Color(hex: 0xff0066),
        redDim:          Color(hex: 0xff0066, opacity: 0.12),
        mint:            Color(hex: 0x00ffff),
        mintDim:         Color(hex: 0x00ffff, opacity: 0.12),
        purple:          Color(hex: 0xcc00ff),
        purpleDim:       Color(hex: 0xcc00ff, opacity: 0.12),
        accentContrastText: .black,
        toggleOffTrack:  Color.white.opacity(0.10),
        toggleOffKnob:   .white
    )

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // LIGHT THEMES
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private static let daylightPalette = ThemePalette(
        bgDeep:          Color(hex: 0xF5F5F7),
        bgPanel:         Color.white,
        bgCard:          Color.white.opacity(0.62),
        bgCardHover:     Color.white.opacity(0.76),
        bgElevated:      Color.white.opacity(0.70),
        borderSubtle:    Color.black.opacity(0.05),
        borderMedium:    Color.black.opacity(0.10),
        borderActive:    Color(hex: 0x5E5CE6, opacity: 0.34),
        textPrimary:     Color(hex: 0x1D1D1F),
        textSecondary:   Color(hex: 0x4A4A50),
        textMuted:       Color(hex: 0x86868B),
        accent:          Color(hex: 0x5E5CE6),
        accentDim:       Color(hex: 0x5E5CE6, opacity: 0.10),
        blue:            Color(hex: 0x0A84FF),
        blueDim:         Color(hex: 0x0A84FF, opacity: 0.08),
        blueGlow:        Color(hex: 0x0A84FF, opacity: 0.12),
        green:           Color(hex: 0x32D74B),
        greenDim:        Color(hex: 0x32D74B, opacity: 0.08),
        yellow:          Color(hex: 0xFFD60A),
        yellowDim:       Color(hex: 0xFFD60A, opacity: 0.08),
        orange:          Color(hex: 0xFF9F0A),
        orangeDim:       Color(hex: 0xFF9F0A, opacity: 0.08),
        red:             Color(hex: 0xFF453A),
        redDim:          Color(hex: 0xFF453A, opacity: 0.08),
        mint:            Color(hex: 0x64D2FF),
        mintDim:         Color(hex: 0x64D2FF, opacity: 0.08),
        purple:          Color(hex: 0xBF5AF2),
        purpleDim:       Color(hex: 0xBF5AF2, opacity: 0.08),
        accentContrastText: .white,
        toggleOffTrack:  Color(hex: 0x787880, opacity: 0.32),
        toggleOffKnob:   .white
    )

    private static let arcticPalette = ThemePalette(
        bgDeep:          Color(hex: 0xf0f4f8),
        bgPanel:         Color(hex: 0xe2e8f0),
        bgCard:          Color(hex: 0xffffff),
        bgCardHover:     Color(hex: 0xf1f5f9),
        bgElevated:      Color(hex: 0xf8fafc),
        borderSubtle:    Color(hex: 0x0f172a, opacity: 0.08),
        borderMedium:    Color(hex: 0x0f172a, opacity: 0.13),
        borderActive:    Color(hex: 0x2563eb, opacity: 0.35),
        textPrimary:     Color(hex: 0x0f172a),
        textSecondary:   Color(hex: 0x475569),
        textMuted:       Color(hex: 0x94a3b8),
        accent:          Color(hex: 0x2563eb),
        accentDim:       Color(hex: 0x2563eb, opacity: 0.08),
        blue:            Color(hex: 0x2563eb),
        blueDim:         Color(hex: 0x2563eb, opacity: 0.08),
        blueGlow:        Color(hex: 0x2563eb, opacity: 0.12),
        green:           Color(hex: 0x059669),
        greenDim:        Color(hex: 0x059669, opacity: 0.08),
        yellow:          Color(hex: 0xca8a04),
        yellowDim:       Color(hex: 0xca8a04, opacity: 0.08),
        orange:          Color(hex: 0xea580c),
        orangeDim:       Color(hex: 0xea580c, opacity: 0.08),
        red:             Color(hex: 0xdc2626),
        redDim:          Color(hex: 0xdc2626, opacity: 0.08),
        mint:            Color(hex: 0x0891b2),
        mintDim:         Color(hex: 0x0891b2, opacity: 0.08),
        purple:          Color(hex: 0x7c3aed),
        purpleDim:       Color(hex: 0x7c3aed, opacity: 0.08),
        accentContrastText: .white,
        toggleOffTrack:  Color.black.opacity(0.10),
        toggleOffKnob:   Color(hex: 0xb0b0b0)
    )

    private static let sandPalette = ThemePalette(
        bgDeep:          Color(hex: 0xf5f0eb),
        bgPanel:         Color(hex: 0xe8e0d8),
        bgCard:          Color(hex: 0xfffefa),
        bgCardHover:     Color(hex: 0xf7f2ed),
        bgElevated:      Color(hex: 0xfaf7f4),
        borderSubtle:    Color(hex: 0x3c2814, opacity: 0.08),
        borderMedium:    Color(hex: 0x3c2814, opacity: 0.12),
        borderActive:    Color(hex: 0x0d9488, opacity: 0.35),
        textPrimary:     Color(hex: 0x1c1512),
        textSecondary:   Color(hex: 0x6b5c50),
        textMuted:       Color(hex: 0xa89888),
        accent:          Color(hex: 0x0d9488),
        accentDim:       Color(hex: 0x0d9488, opacity: 0.10),
        blue:            Color(hex: 0x2563eb),
        blueDim:         Color(hex: 0x2563eb, opacity: 0.08),
        blueGlow:        Color(hex: 0x2563eb, opacity: 0.12),
        green:           Color(hex: 0x15803d),
        greenDim:        Color(hex: 0x15803d, opacity: 0.08),
        yellow:          Color(hex: 0xa16207),
        yellowDim:       Color(hex: 0xa16207, opacity: 0.08),
        orange:          Color(hex: 0xc2410c),
        orangeDim:       Color(hex: 0xc2410c, opacity: 0.08),
        red:             Color(hex: 0xb91c1c),
        redDim:          Color(hex: 0xb91c1c, opacity: 0.08),
        mint:            Color(hex: 0x0d9488),
        mintDim:         Color(hex: 0x0d9488, opacity: 0.08),
        purple:          Color(hex: 0x6d28d9),
        purpleDim:       Color(hex: 0x6d28d9, opacity: 0.08),
        accentContrastText: .white,
        toggleOffTrack:  Color.black.opacity(0.10),
        toggleOffKnob:   Color(hex: 0xb0b0b0)
    )
}

struct PopoverToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isOn.toggle()
            }
        } label: {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isOn ? PopoverTheme.accent : PopoverTheme.toggleOffTrack)
                .frame(width: 36, height: 20)
                .overlay(alignment: .leading) {
                    Circle()
                        .fill(isOn ? PopoverTheme.accentContrastText : PopoverTheme.toggleOffKnob)
                        .frame(width: 16, height: 16)
                        .offset(x: isOn ? 18 : 2)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
