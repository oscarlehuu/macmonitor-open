import AppKit
import SwiftUI

struct StorageManagementView: View {
    @ObservedObject var viewModel: StorageManagementViewModel
    let onBack: () -> Void

    @State private var isLooseExpanded = true
    @State private var didHandleInitialAccess = false
    @State private var isSearchExpanded = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            actionHeader

            if viewModel.isScanning {
                scanningCard
            }

            projectionCard
            if !viewModel.ringBuckets.isEmpty {
                ringCard
            }
            selectionSummaryCard

            if !viewModel.trackedFolders.isEmpty {
                trackedFoldersCard
            }

            if let resultMessage = viewModel.resultMessage, !resultMessage.isEmpty {
                infoMessageCard(
                    text: resultMessage,
                    foreground: PopoverTheme.green,
                    background: PopoverTheme.greenDim
                )
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                infoMessageCard(
                    text: errorMessage,
                    foreground: PopoverTheme.red,
                    background: PopoverTheme.redDim
                )
            }

            groupsCard
        }
        .onAppear {
            if !didHandleInitialAccess {
                didHandleInitialAccess = true
                requestInitialAccessIfNeeded()
            }
            viewModel.loadIfNeeded()
        }
        .confirmationDialog(
            "Move selected items to Trash?",
            isPresented: $viewModel.showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                Task { await viewModel.deleteSelected() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selected: \(viewModel.selectedAllowedCount) • \(MetricFormatter.bytes(viewModel.selectedAllowedBytes))")
        }
        .confirmationDialog(
            "Force quit still-running apps?",
            isPresented: $viewModel.showingForceQuitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Force Quit and Move to Trash", role: .destructive) {
                Task { await viewModel.confirmForceQuitAndDelete() }
            }
            Button("Skip Running Apps") {
                Task { await viewModel.skipForceQuitAndDelete() }
            }
            Button("Cancel Cleanup", role: .cancel) {
                viewModel.cancelForceQuitPrompt()
            }
        } message: {
            Text(viewModel.forceQuitPromptMessage)
        }
    }

    private var actionHeader: some View {
        HStack(spacing: 8) {
            Button {
                onBack()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(PopoverTheme.textSecondary)

            Spacer(minLength: 0)

            if let lastUpdated = viewModel.lastUpdated {
                Text("Updated \(MetricFormatter.relativeTime(from: lastUpdated))")
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textMuted)
            }

            Button {
                viewModel.refresh()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(PopoverTheme.textSecondary)
            .disabled(viewModel.isScanning || viewModel.isDeleting)

            Button {
                addFoldersFromPanel()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Add Folder")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PopoverTheme.accentContrastText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(PopoverTheme.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isDeleting)
        }
    }

    private var scanningCard: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Scanning applications, caches, and folders...")
                .font(.system(size: 11))
                .foregroundStyle(PopoverTheme.textSecondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func requestInitialAccessIfNeeded() {
        guard viewModel.shouldRequestInitialAccess() else { return }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Allow Access"
        panel.message = "Choose your Home folder once to avoid repeated scan prompts."
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        if panel.runModal() == .OK, let selectedURL = panel.url {
            viewModel.grantInitialAccess(to: selectedURL)
        } else {
            viewModel.markInitialAccessPromptHandled()
        }
    }

    private var projectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Projection")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PopoverTheme.textPrimary)

            projectionRow(
                title: "Current",
                usedText: MetricFormatter.usage(used: viewModel.currentUsedBytes, total: viewModel.currentTotalBytes),
                ratio: viewModel.currentUsageRatio,
                color: PopoverTheme.mint
            )

            projectionRow(
                title: "After Cleanup",
                usedText: MetricFormatter.usage(used: viewModel.projectedUsedBytes, total: viewModel.currentTotalBytes),
                ratio: viewModel.projectedUsageRatio,
                color: PopoverTheme.blue
            )

            HStack {
                Text("Will Delete")
                    .font(.system(size: 10))
                    .foregroundStyle(PopoverTheme.textSecondary)
                Spacer(minLength: 0)
                Text(MetricFormatter.bytes(viewModel.willDeleteBytes))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(PopoverTheme.orange)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func projectionRow(
        title: String,
        usedText: String,
        ratio: Double,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textSecondary)
                Spacer(minLength: 0)
                Text(usedText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(PopoverTheme.textMuted)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(PopoverTheme.borderMedium)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color)
                        .frame(width: geometry.size.width * min(max(ratio, 0), 1))
                }
            }
            .frame(height: 6)
        }
    }

    private var ringCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Disk Distribution")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PopoverTheme.textPrimary)

            StorageRingChartView(
                buckets: viewModel.ringBuckets,
                totalBytes: viewModel.scannedTopLevelBytes
            )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var selectionSummaryCard: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("\(viewModel.selectedAllowedCount) selected")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)
                    .lineLimit(1)

                Text(MetricFormatter.bytes(viewModel.selectedAllowedBytes))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(PopoverTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: isSearchExpanded ? 96 : .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.22), value: isSearchExpanded)

            Menu {
                Button {
                    viewModel.clearPresetSelection()
                } label: {
                    if viewModel.activePreset == nil {
                        Label("All Targets", systemImage: "checkmark")
                    } else {
                        Text("All Targets")
                    }
                }

                Divider()

                ForEach(StorageCleanupPreset.allCases) { preset in
                    Button {
                        viewModel.applyPreset(preset)
                    } label: {
                        if viewModel.activePreset == preset {
                            Label(preset.title, systemImage: "checkmark")
                        } else {
                            Text(preset.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 11, weight: .medium))
                    Text(viewModel.activePreset?.title ?? "Filter")
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(PopoverTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(PopoverTheme.bgElevated)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize(horizontal: true, vertical: false)

            if isSearchExpanded {
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PopoverTheme.textMuted)

                    TextField("Search app", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10))
                        .focused($isSearchFieldFocused)

                    if !viewModel.searchQuery.isEmpty {
                        Button {
                            viewModel.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(PopoverTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSearchExpanded = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(PopoverTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(width: 152)
                .background(
                    Capsule(style: .continuous)
                        .fill(PopoverTheme.bgElevated)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                        isSearchExpanded = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        isSearchFieldFocused = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(PopoverTheme.textSecondary)
            }

            if viewModel.isDeleting {
                ProgressView()
                    .controlSize(.small)
            }

            Button(role: .destructive) {
                viewModel.requestDeleteSelection()
            } label: {
                Text("Move to Trash")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(viewModel.canDeleteSelection ? PopoverTheme.red : PopoverTheme.textMuted)
            .disabled(!viewModel.canDeleteSelection || viewModel.isScanning)
            .help(viewModel.deleteInfoTooltip)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.22), value: isSearchExpanded)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
        .onChange(of: isSearchExpanded) { _, expanded in
            if !expanded {
                viewModel.searchQuery = ""
                isSearchFieldFocused = false
            }
        }
        .onSubmit(of: .text) {
            if viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearchExpanded = false
                }
            }
        }
    }

    private var trackedFoldersCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tracked Folders")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PopoverTheme.textPrimary)

            ForEach(viewModel.trackedFolders, id: \.path) { folder in
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverTheme.blue)

                    Text(folder.path)
                        .font(.system(size: 10))
                        .foregroundStyle(PopoverTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 0)

                    Button {
                        viewModel.removeCustomFolder(folder)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(PopoverTheme.textMuted)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func infoMessageCard(text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(background.opacity(0.6))
            )
    }

    private var groupsCard: some View {
        let groups = viewModel.visibleAppGroups

        return VStack(spacing: 0) {
            if groups.isEmpty && !viewModel.hasLooseItems && !viewModel.isScanning {
                Text(
                    viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "No storage targets found. Add folders or refresh."
                        : "No matches for \"\(viewModel.searchQuery)\"."
                )
                    .font(.system(size: 11))
                    .foregroundStyle(PopoverTheme.textMuted)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    appGroupSection(group)
                    if index < groups.count - 1 || viewModel.hasLooseItems {
                        divider
                    }
                }

                if viewModel.hasLooseItems {
                    looseSection
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PopoverTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(PopoverTheme.borderSubtle, lineWidth: 1)
        )
    }

    private func appGroupSection(_ group: StorageAppGroup) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    viewModel.toggleGroupExpansion(group.id)
                } label: {
                    Image(systemName: viewModel.expandedGroupIDs.contains(group.id) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.toggleGroupSelection(group.id)
                } label: {
                    Image(systemName: selectionStateSymbol(viewModel.groupSelectionState(group)))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(selectionStateColor(viewModel.groupSelectionState(group)))
                }
                .buttonStyle(.plain)

                Image(systemName: "app.dashed")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PopoverTheme.blue)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PopoverTheme.textPrimary)
                        .lineLimit(1)

                    if let bundleIdentifier = group.bundleIdentifier {
                        Text(bundleIdentifier)
                            .font(.system(size: 9))
                            .foregroundStyle(PopoverTheme.textMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                Text(MetricFormatter.bytes(group.totalBytes))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(PopoverTheme.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            if viewModel.expandedGroupIDs.contains(group.id) {
                ForEach(viewModel.rows(for: group)) { row in
                    divider
                    itemRow(row)
                }
            }
        }
    }

    private var looseSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    isLooseExpanded.toggle()
                } label: {
                    Image(systemName: isLooseExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                Image(systemName: "tray.full")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PopoverTheme.mint)
                    .frame(width: 14)

                Text("Other Targets")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PopoverTheme.textPrimary)

                Spacer(minLength: 4)

                Text(MetricFormatter.bytes(viewModel.visibleLooseItems.reduce(0) { $0 + $1.sizeBytes }))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(PopoverTheme.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            if isLooseExpanded {
                ForEach(viewModel.looseRows()) { row in
                    divider
                    itemRow(row)
                }
            }
        }
    }

    private func itemRow(_ row: StorageListRow) -> some View {
        let item = row.item
        let isSelected = viewModel.selectedItemIDs.contains(item.id)
        let isExpanded = viewModel.isItemExpanded(item.id)
        let isLoading = viewModel.isLoadingChildren(for: item.id)

        return HStack(spacing: 8) {
            Spacer()
                .frame(width: CGFloat(row.depth) * 12)

            if item.isExpandable {
                Button {
                    viewModel.toggleItemExpansion(item.id)
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(PopoverTheme.textMuted)
                        .frame(width: 10)
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 10)
            }

            Button {
                viewModel.toggleSelection(for: item.id)
            } label: {
                Image(systemName: selectionSymbol(isSelected: isSelected, item: item))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(selectionColor(isSelected: isSelected, item: item))
            }
            .buttonStyle(.plain)
            .disabled(item.isProtected || viewModel.isDeleting)

            Image(systemName: icon(for: item))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color(for: item.category))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(PopoverTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(item.kind.title)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(color(for: item.category))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule(style: .continuous)
                                .fill(color(for: item.category).opacity(0.14))
                        )
                }

                Text(item.url.path)
                    .font(.system(size: 9))
                    .foregroundStyle(PopoverTheme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if item.isProtected, let protectionReason = item.protectionReason {
                    Text("Protected: \(protectionReason.description)")
                        .font(.system(size: 8))
                        .foregroundStyle(PopoverTheme.orange)
                } else if isExpanded && isLoading {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading children...")
                            .font(.system(size: 8))
                            .foregroundStyle(PopoverTheme.textMuted)
                    }
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                Text(MetricFormatter.bytes(item.sizeBytes))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PopoverTheme.textSecondary)

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 9, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(PopoverTheme.textMuted)
                .help("Reveal in Finder")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private var divider: some View {
        Rectangle()
            .fill(PopoverTheme.borderSubtle)
            .frame(height: 1)
            .padding(.leading, 10)
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

    private func selectionSymbol(isSelected: Bool, item: StorageManagedItem) -> String {
        if item.isProtected {
            return "lock.circle.fill"
        }
        return isSelected ? "checkmark.circle.fill" : "circle"
    }

    private func selectionColor(isSelected: Bool, item: StorageManagedItem) -> Color {
        if item.isProtected {
            return PopoverTheme.orange
        }
        return isSelected ? PopoverTheme.accent : PopoverTheme.textMuted
    }

    private func icon(for item: StorageManagedItem) -> String {
        switch item.kind {
        case .appBundle:
            return "app.dashed"
        case .appCache, .looseCache, .npmCache, .pnpmStore, .yarnCache:
            return "externaldrive.badge.timemachine"
        case .derivedData:
            return "hammer"
        case .xcodeArchives:
            return "archivebox"
        case .simulatorData:
            return "iphone.rear.camera"
        case .nodeModules:
            return "shippingbox"
        case .appSupport, .appContainer, .customFolder, .looseFolder, .drillDown:
            return item.category.symbolName
        case .appLogs:
            return "doc.text"
        case .appPreferences:
            return "slider.horizontal.3"
        }
    }

    private func color(for category: StorageManagedItemCategory) -> Color {
        switch category {
        case .application:
            return PopoverTheme.blue
        case .cache:
            return PopoverTheme.mint
        case .folder:
            return PopoverTheme.purple
        }
    }

    private func addFoldersFromPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Track"
        panel.message = "Choose folders to scan and manage."
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        if panel.runModal() == .OK {
            for selectedURL in panel.urls {
                viewModel.addCustomFolder(selectedURL)
            }
        }
    }
}
