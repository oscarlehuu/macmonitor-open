import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let viewModel: SystemSummaryViewModel
    private let ramDetailsViewModel: RAMDetailsViewModel
    private let ramPolicyViewModel: RAMPolicySettingsViewModel
    private let storageManagementViewModel: StorageManagementViewModel
    private let batteryPolicyCoordinator: BatteryPolicyCoordinator
    private let batteryScheduleViewModel: BatteryScheduleViewModel
    private let appUpdateController: AppUpdateController
    private let diagnosticsExporter: DiagnosticsExporter
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private var appearanceObserver: NSObjectProtocol?

    init(
        viewModel: SystemSummaryViewModel,
        ramDetailsViewModel: RAMDetailsViewModel,
        ramPolicyViewModel: RAMPolicySettingsViewModel,
        storageManagementViewModel: StorageManagementViewModel,
        batteryPolicyCoordinator: BatteryPolicyCoordinator,
        batteryScheduleViewModel: BatteryScheduleViewModel,
        appUpdateController: AppUpdateController,
        diagnosticsExporter: DiagnosticsExporter
    ) {
        self.viewModel = viewModel
        self.ramDetailsViewModel = ramDetailsViewModel
        self.ramPolicyViewModel = ramPolicyViewModel
        self.storageManagementViewModel = storageManagementViewModel
        self.batteryPolicyCoordinator = batteryPolicyCoordinator
        self.batteryScheduleViewModel = batteryScheduleViewModel
        self.appUpdateController = appUpdateController
        self.diagnosticsExporter = diagnosticsExporter
        super.init()
    }

    func install() {
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopoverRootView(
                viewModel: viewModel,
                ramDetailsViewModel: ramDetailsViewModel,
                ramPolicyViewModel: ramPolicyViewModel,
                storageManagementViewModel: storageManagementViewModel,
                batteryPolicyCoordinator: batteryPolicyCoordinator,
                batteryScheduleViewModel: batteryScheduleViewModel,
                settings: viewModel.settings,
                appUpdateController: appUpdateController,
                diagnosticsExporter: diagnosticsExporter
            )
        )

        guard let button = statusItem.button else { return }
        button.action = #selector(togglePopover(_:))
        button.target = self
        button.sendAction(on: [.leftMouseDown])

        installAppearanceObserver()
        bindViewModel()
        renderStatusItem()
    }

    func uninstall() {
        cancellables.removeAll()
        if let appearanceObserver {
            DistributedNotificationCenter.default().removeObserver(appearanceObserver)
            self.appearanceObserver = nil
        }
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        renderStatusItem()
    }

    private func bindViewModel() {
        viewModel.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                statusItem.button?.toolTip = viewModel.statusTooltip
                renderStatusItem()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(
            viewModel.settings.$menuBarDisplayMode,
            viewModel.settings.$menuBarMemoryFormat,
            viewModel.settings.$menuBarStorageFormat
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _, _, _ in
            self?.renderStatusItem()
        }
        .store(in: &cancellables)
    }

    private func renderStatusItem() {
        guard let button = statusItem.button else { return }
        let settings = viewModel.settings

        switch settings.menuBarDisplayMode {
        case .icon:
            statusItem.length = NSStatusItem.squareLength
            button.title = ""
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.image = iconOnlySymbol()
        case .memory, .storage, .cpu, .network, .both:
            statusItem.length = NSStatusItem.variableLength
            button.imagePosition = .imageLeft
            button.imageScaling = .scaleProportionallyDown
            button.image = metricPrefixIcon()
            button.font = NSFont.monospacedDigitSystemFont(
                ofSize: NSFont.systemFontSize(for: .small),
                weight: .semibold
            )
            button.title = MenuBarDisplayFormatter.valueText(
                for: viewModel.snapshot,
                mode: settings.menuBarDisplayMode,
                memoryFormat: settings.menuBarMemoryFormat,
                storageFormat: settings.menuBarStorageFormat
            ) ?? ""
        }

        applyBackgroundStyle(to: button, mode: settings.menuBarDisplayMode)
        button.contentTintColor = nil
    }

    private func metricPrefixIcon() -> NSImage? {
        guard let symbolImage = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: nil) else {
            return nil
        }

        let configured = symbolImage.withSymbolConfiguration(
            NSImage.SymbolConfiguration(
                pointSize: 11,
                weight: .medium,
                scale: .small
            )
        )
        let image = configured ?? symbolImage
        image.isTemplate = true
        return image
    }

    private func iconOnlySymbol() -> NSImage? {
        guard let symbolImage = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: nil) else {
            return nil
        }

        let configured = symbolImage.withSymbolConfiguration(
            NSImage.SymbolConfiguration(
                pointSize: 10,
                weight: .medium,
                scale: .small
            )
        )
        let image = configured ?? symbolImage
        image.isTemplate = true
        return image
    }

    private func applyBackgroundStyle(to button: NSStatusBarButton, mode: MenuBarDisplayMode) {
        switch mode {
        case .icon:
            button.wantsLayer = true
            guard let layer = button.layer else { return }

            let bestAppearance = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            if bestAppearance == .darkAqua {
                layer.backgroundColor = NSColor.white.withAlphaComponent(0.10).cgColor
                layer.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
            } else {
                layer.backgroundColor = NSColor.black.withAlphaComponent(0.06).cgColor
                layer.borderColor = NSColor.black.withAlphaComponent(0.10).cgColor
            }
            layer.borderWidth = 0.5
            layer.cornerRadius = 6
            layer.masksToBounds = true
        case .memory, .storage, .cpu, .network, .both:
            button.wantsLayer = true
            guard let layer = button.layer else { return }

            let bestAppearance = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            let fillColor: NSColor
            let borderColor: NSColor
            if bestAppearance == .darkAqua {
                fillColor = NSColor.white.withAlphaComponent(0.14)
                borderColor = NSColor.white.withAlphaComponent(0.24)
            } else {
                fillColor = NSColor.black.withAlphaComponent(0.10)
                borderColor = NSColor.black.withAlphaComponent(0.16)
            }

            layer.backgroundColor = fillColor.cgColor
            layer.borderColor = borderColor.cgColor
            layer.borderWidth = 0.5
            layer.cornerRadius = 6
            layer.masksToBounds = true
        }
    }

    private func installAppearanceObserver() {
        if let appearanceObserver {
            DistributedNotificationCenter.default().removeObserver(appearanceObserver)
            self.appearanceObserver = nil
        }

        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.renderStatusItem()
            }
        }
    }
}

extension MenuBarController: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        renderStatusItem()
    }

    func popoverDidClose(_ notification: Notification) {
        renderStatusItem()
    }
}
