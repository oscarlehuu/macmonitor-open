import Combine
import Foundation
import IOKit
import IOKit.ps
import IOKit.pwr_mgt

protocol BatteryCollecting {
    func collect() -> BatterySnapshot?
    var stateDidChangePublisher: AnyPublisher<Void, Never> { get }
}

final class BatteryCollector: BatteryCollecting {
    private struct SystemProfilerBatteryHealthInfo {
        let maximumCapacityPercent: Int?
        let healthLabel: String?
        let cycleCount: Int?
    }

    private struct CachedSystemProfilerBatteryHealth {
        let info: SystemProfilerBatteryHealthInfo?
        let fetchedAt: Date
    }

    private let notificationCenter: NotificationCenter
    private let powerEventSubject = PassthroughSubject<Void, Never>()
    private var cachedSystemProfilerBatteryHealth: CachedSystemProfilerBatteryHealth?
    private let systemProfilerHealthCacheInterval: TimeInterval = 30 * 60
    private var isRefreshingSystemProfiler = false

    private var powerSourceRunLoopSource: CFRunLoopSource?
    private lazy var lowPowerModePublisher: AnyPublisher<Void, Never> = {
        notificationCenter.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)
            .map { _ in () }
            .eraseToAnyPublisher()
    }()

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        installPowerSourceNotification()
    }

    deinit {
        uninstallPowerSourceNotification()
    }

    var stateDidChangePublisher: AnyPublisher<Void, Never> {
        powerEventSubject
            .merge(with: lowPowerModePublisher)
            .eraseToAnyPublisher()
    }

    func collect() -> BatterySnapshot? {
        guard let infoBlob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sourceList = IOPSCopyPowerSourcesList(infoBlob)?.takeRetainedValue() as? [AnyObject] else {
            return nil
        }

        let provider = IOPSGetProvidingPowerSourceType(infoBlob)?.takeUnretainedValue() as String?
        let providerSource = Self.mapPowerSource(provider)

        let sourceDescription = sourceList.lazy
            .compactMap { source -> [String: Any]? in
                guard let dictionary = IOPSGetPowerSourceDescription(infoBlob, source)?.takeUnretainedValue() as? [String: Any] else {
                    return nil
                }
                return dictionary
            }
            .first(where: { ($0[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType })
            ?? sourceList.lazy.compactMap { source -> [String: Any]? in
                IOPSGetPowerSourceDescription(infoBlob, source)?.takeUnretainedValue() as? [String: Any]
            }.first

        guard let sourceDescription else {
            return nil
        }

        let registryInfo = readAppleSmartBatteryRegistryInfo()
        let profilerHealthInfo = systemProfilerBatteryHealthInfo()

        let currentCapacity = Self.intValue(sourceDescription[kIOPSCurrentCapacityKey])
        let maxCapacity = Self.intValue(sourceDescription[kIOPSMaxCapacityKey])
        let isPresent = Self.boolValue(sourceDescription[kIOPSIsPresentKey]) ?? true
        let isCharging = Self.boolValue(sourceDescription[kIOPSIsChargingKey]) ?? false
        let isCharged = Self.boolValue(sourceDescription[kIOPSIsChargedKey]) ?? false

        let chargeStateSource = Self.mapPowerSource(sourceDescription[kIOPSPowerSourceStateKey] as? String)
        let powerSource = chargeStateSource == .unknown ? providerSource : chargeStateSource

        let timeToEmpty = Self.normalizedMinutes(Self.intValue(sourceDescription[kIOPSTimeToEmptyKey]))
        let timeToFull = Self.normalizedMinutes(Self.intValue(sourceDescription[kIOPSTimeToFullChargeKey]))

        let amperage = registryInfo.amperageMilliAmps ?? Self.intValue(sourceDescription[kIOPSCurrentKey])
        let voltage = registryInfo.voltageMilliVolts ?? Self.intValue(sourceDescription[kIOPSVoltageKey])

        let sourceTemperature = Self.intValue(sourceDescription[kIOPSTemperatureKey])
        let registryTemperature = registryInfo.temperatureCelsius
        let temperature = registryTemperature ?? sourceTemperature

        let cycleCount = profilerHealthInfo?.cycleCount ?? registryInfo.cycleCount
        let rawHealth = sourceDescription[kIOPSBatteryHealthKey] as? String
        let health = Self.resolveHealthLabel(
            sourceHealth: profilerHealthInfo?.healthLabel ?? rawHealth,
            preferredMaximumCapacityPercent: profilerHealthInfo?.maximumCapacityPercent,
            rawMaxCapacity: registryInfo.rawMaxCapacityMilliampHours,
            designCapacity: registryInfo.designCapacityMilliampHours
        )
        let healthCondition = (sourceDescription[kIOPSBatteryHealthConditionKey] as? String)
            ?? Self.resolveHealthConditionLabel(sourceHealth: profilerHealthInfo?.healthLabel)

        return BatterySnapshot(
            currentCapacity: currentCapacity,
            maxCapacity: maxCapacity,
            isPresent: isPresent,
            isCharging: isCharging,
            isCharged: isCharged,
            powerSource: powerSource,
            timeToEmptyMinutes: timeToEmpty,
            timeToFullChargeMinutes: timeToFull,
            amperageMilliAmps: amperage,
            voltageMilliVolts: voltage,
            temperatureCelsius: temperature,
            cycleCount: cycleCount,
            health: health,
            healthCondition: healthCondition,
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    private func installPowerSourceNotification() {
        guard powerSourceRunLoopSource == nil else { return }
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let unmanagedSource = IOPSNotificationCreateRunLoopSource(Self.powerSourceDidChange, context) else {
            return
        }
        let source = unmanagedSource.takeRetainedValue()
        powerSourceRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private func uninstallPowerSourceNotification() {
        guard let source = powerSourceRunLoopSource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        powerSourceRunLoopSource = nil
    }

    private static let powerSourceDidChange: IOPowerSourceCallbackType = { context in
        guard let context else { return }
        let collector = Unmanaged<BatteryCollector>.fromOpaque(context).takeUnretainedValue()
        collector.powerEventSubject.send(())
    }

    private static func mapPowerSource(_ rawValue: String?) -> BatteryPowerSource {
        switch rawValue {
        case kIOPSACPowerValue:
            return .ac
        case kIOPSBatteryPowerValue:
            return .battery
        case kIOPMUPSPowerKey:
            return .ups
        default:
            return .unknown
        }
    }

    private static func normalizedMinutes(_ rawValue: Int?) -> Int? {
        guard let rawValue, rawValue >= 0 else {
            return nil
        }
        return rawValue
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let boolean = value as? Bool {
            return boolean
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let string = value as? String {
            switch string.lowercased() {
            case "1", "true", "yes":
                return true
            case "0", "false", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }

    private struct AppleSmartBatteryRegistryInfo {
        let cycleCount: Int?
        let amperageMilliAmps: Int?
        let voltageMilliVolts: Int?
        let temperatureCelsius: Int?
        let rawMaxCapacityMilliampHours: Int?
        let designCapacityMilliampHours: Int?
    }

    private func readAppleSmartBatteryRegistryInfo() -> AppleSmartBatteryRegistryInfo {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else {
            return AppleSmartBatteryRegistryInfo(
                cycleCount: nil,
                amperageMilliAmps: nil,
                voltageMilliVolts: nil,
                temperatureCelsius: nil,
                rawMaxCapacityMilliampHours: nil,
                designCapacityMilliampHours: nil
            )
        }
        defer {
            IOObjectRelease(service)
        }

        let cycleCount = intRegistryProperty(service: service, key: "CycleCount")
        let amperage = intRegistryProperty(service: service, key: "Amperage")
        let voltage = intRegistryProperty(service: service, key: "Voltage")
        let rawTemperature = intRegistryProperty(service: service, key: "Temperature")
        let temperature = rawTemperature.map(Self.normalizeTemperature)
        let rawMaxCapacity = intRegistryProperty(service: service, key: "AppleRawMaxCapacity")
        let designCapacity = intRegistryProperty(service: service, key: "DesignCapacity")

        return AppleSmartBatteryRegistryInfo(
            cycleCount: cycleCount,
            amperageMilliAmps: amperage,
            voltageMilliVolts: voltage,
            temperatureCelsius: temperature,
            rawMaxCapacityMilliampHours: rawMaxCapacity,
            designCapacityMilliampHours: designCapacity
        )
    }

    private func intRegistryProperty(service: io_registry_entry_t, key: String) -> Int? {
        guard let property = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else {
            return nil
        }

        if let number = property as? NSNumber {
            return number.intValue
        }
        if let string = property as? String {
            return Int(string)
        }
        return nil
    }

    private static func normalizeTemperature(_ rawValue: Int) -> Int {
        // AppleSmartBattery temperature is typically reported in centi-degrees Celsius
        // (e.g. 2930 for 29.3°C), but some hardware uses deci-degrees Celsius
        // (e.g. 293 for 29.3°C).
        if rawValue >= 1000 {
            return Int((Double(rawValue) / 100.0).rounded())
        }
        if rawValue >= 100 {
            return Int((Double(rawValue) / 10.0).rounded())
        }
        return rawValue
    }

    private func systemProfilerBatteryHealthInfo(referenceDate: Date = Date()) -> SystemProfilerBatteryHealthInfo? {
        if let cached = cachedSystemProfilerBatteryHealth,
           referenceDate.timeIntervalSince(cached.fetchedAt) < systemProfilerHealthCacheInterval {
            return cached.info
        }

        // Return the stale cached value (or nil on first call) and refresh in the background
        // to avoid blocking the main thread while system_profiler runs.
        if !isRefreshingSystemProfiler {
            isRefreshingSystemProfiler = true
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let info = self?.readSystemProfilerBatteryHealthInfo()
                DispatchQueue.main.async {
                    self?.cachedSystemProfilerBatteryHealth = CachedSystemProfilerBatteryHealth(
                        info: info,
                        fetchedAt: referenceDate
                    )
                    self?.isRefreshingSystemProfiler = false
                }
            }
        }

        return cachedSystemProfilerBatteryHealth?.info
    }

    private func readSystemProfilerBatteryHealthInfo() -> SystemProfilerBatteryHealthInfo? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["-json", "SPPowerDataType"]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = Pipe()

        do {
            try task.run()
        } catch {
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            return nil
        }
        guard !data.isEmpty else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = json["SPPowerDataType"] as? [[String: Any]],
              let batterySection = sections.first(where: { ($0["_name"] as? String) == "spbattery_information" }) ?? sections.first,
              let healthInfo = batterySection["sppower_battery_health_info"] as? [String: Any] else {
            return nil
        }

        let maxCapacityPercent = Self.percentValue(healthInfo["sppower_battery_health_maximum_capacity"])
        let healthLabel = (healthInfo["sppower_battery_health"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cycleCount = Self.intValue(healthInfo["sppower_battery_cycle_count"])

        return SystemProfilerBatteryHealthInfo(
            maximumCapacityPercent: maxCapacityPercent,
            healthLabel: healthLabel,
            cycleCount: cycleCount
        )
    }

    private static func resolveHealthLabel(
        sourceHealth: String?,
        preferredMaximumCapacityPercent: Int?,
        rawMaxCapacity: Int?,
        designCapacity: Int?
    ) -> String? {
        if let preferredMaximumCapacityPercent {
            return "\(preferredMaximumCapacityPercent)%"
        }

        let source = sourceHealth?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSource = !(source?.isEmpty ?? true)
        let sourceIsGenericCheckBattery = source?.caseInsensitiveCompare("check battery") == .orderedSame
        let healthPercent = batteryHealthPercent(rawMaxCapacity: rawMaxCapacity, designCapacity: designCapacity)

        if hasSource, !sourceIsGenericCheckBattery, let source {
            if let healthPercent, !source.contains("%") {
                return "\(source) (\(healthPercent)%)"
            }
            return source
        }

        if let healthPercent {
            return "\(healthPercent)%"
        }

        return hasSource ? source : nil
    }

    private static func resolveHealthConditionLabel(sourceHealth: String?) -> String? {
        guard let sourceHealth = sourceHealth?.trimmingCharacters(in: .whitespacesAndNewlines),
              !sourceHealth.isEmpty else {
            return nil
        }

        if sourceHealth.caseInsensitiveCompare("good") == .orderedSame {
            return "Normal"
        }
        return sourceHealth
    }

    private static func batteryHealthPercent(rawMaxCapacity: Int?, designCapacity: Int?) -> Int? {
        guard let rawMaxCapacity, let designCapacity, rawMaxCapacity > 0, designCapacity > 0 else {
            return nil
        }

        let ratio = Double(rawMaxCapacity) / Double(designCapacity)
        guard ratio.isFinite else { return nil }
        return Int((ratio * 100.0).rounded())
    }

    private static func percentValue(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }

        guard let string = value as? String else {
            return nil
        }

        let digits = string.filter(\.isNumber)
        return Int(digits)
    }
}
