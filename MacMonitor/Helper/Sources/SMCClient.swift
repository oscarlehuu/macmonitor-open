import Foundation
import IOKit

// Minimal AppleSMC client adapted from MIT-licensed SMCKit:
// https://github.com/beltex/SMCKit
typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

private struct SMCParamStruct {
    struct SMCVersion {
        var major: CUnsignedChar = 0
        var minor: CUnsignedChar = 0
        var build: CUnsignedChar = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }

    struct SMCPLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct SMCKeyInfoData {
        var dataSize: IOByteCount32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    )
}

private enum SMCSelector: UInt8 {
    case handleYPCEvent = 2
    case readKey = 5
    case writeKey = 6
    case getKeyInfo = 9
}

private enum SMCResult: UInt8 {
    case success = 0
    case keyNotFound = 132
}

enum SMCClientError: LocalizedError {
    case invalidKey(String)
    case driverNotFound
    case openFailed(kern_return_t)
    case keyNotFound(String)
    case notPrivileged
    case valueTooLarge(key: String, expected: Int, got: Int)
    case callFailed(kern_return_t, UInt8)

    var errorDescription: String? {
        switch self {
        case .invalidKey(let key):
            return "SMC key '\(key)' is invalid."
        case .driverNotFound:
            return "AppleSMC driver not found."
        case .openFailed(let code):
            return "Failed to open AppleSMC connection (\(code))."
        case .keyNotFound(let key):
            return "SMC key '\(key)' is not available on this Mac."
        case .notPrivileged:
            return "SMC write requires a privileged helper running as root."
        case .valueTooLarge(let key, let expected, let got):
            return "SMC write '\(key)' expected <= \(expected) bytes, got \(got)."
        case .callFailed(let ioResult, let smcResult):
            return "SMC call failed (IOKit: \(ioResult), SMC: \(smcResult))."
        }
    }
}

final class SMCClient {
    private var connection: io_connect_t = 0
    private var open = false

    deinit {
        close()
    }

    func withConnection<T>(_ block: (SMCClient) throws -> T) throws -> T {
        try openConnectionIfNeeded()
        defer { close() }
        return try block(self)
    }

    func keyExists(_ key: String) throws -> Bool {
        do {
            _ = try read(key: key)
            return true
        } catch SMCClientError.keyNotFound {
            return false
        }
    }

    func read(key: String) throws -> [UInt8] {
        let keyCode = try fourCharCode(from: key)
        let keyInfo = try readKeyInfo(keyCode: keyCode, keyString: key)

        var input = SMCParamStruct()
        input.key = keyCode
        input.keyInfo.dataSize = keyInfo.dataSize
        input.data8 = SMCSelector.readKey.rawValue

        let output = try callDriver(&input, keyString: key)
        return bytesArray(from: output.bytes, count: Int(keyInfo.dataSize))
    }

    func write(key: String, bytes: [UInt8]) throws {
        let keyCode = try fourCharCode(from: key)
        let keyInfo = try readKeyInfo(keyCode: keyCode, keyString: key)
        let expectedSize = Int(keyInfo.dataSize)

        guard bytes.count <= expectedSize else {
            throw SMCClientError.valueTooLarge(key: key, expected: expectedSize, got: bytes.count)
        }

        let paddedBytes = bytes + Array(repeating: 0, count: max(0, expectedSize - bytes.count))
        var input = SMCParamStruct()
        input.key = keyCode
        input.keyInfo.dataSize = keyInfo.dataSize
        input.data8 = SMCSelector.writeKey.rawValue
        input.bytes = bytesTuple(from: paddedBytes)

        _ = try callDriver(&input, keyString: key)
    }

    private func openConnectionIfNeeded() throws {
        guard !open else { return }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            throw SMCClientError.driverNotFound
        }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)

        guard result == kIOReturnSuccess else {
            throw SMCClientError.openFailed(result)
        }

        open = true
    }

    private func close() {
        guard open else { return }
        IOServiceClose(connection)
        connection = 0
        open = false
    }

    private func readKeyInfo(keyCode: UInt32, keyString: String) throws -> SMCParamStruct.SMCKeyInfoData {
        var input = SMCParamStruct()
        input.key = keyCode
        input.data8 = SMCSelector.getKeyInfo.rawValue
        let output = try callDriver(&input, keyString: keyString)
        return output.keyInfo
    }

    private func callDriver(_ input: inout SMCParamStruct, keyString: String) throws -> SMCParamStruct {
        precondition(
            MemoryLayout<SMCParamStruct>.stride == 80,
            "SMCParamStruct size mismatch (\(MemoryLayout<SMCParamStruct>.stride))."
        )

        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.stride

        let ioResult = IOConnectCallStructMethod(
            connection,
            UInt32(SMCSelector.handleYPCEvent.rawValue),
            &input,
            MemoryLayout<SMCParamStruct>.stride,
            &output,
            &outputSize
        )

        if ioResult == kIOReturnSuccess, output.result == SMCResult.success.rawValue {
            return output
        }

        if ioResult == kIOReturnNotPrivileged {
            throw SMCClientError.notPrivileged
        }

        if ioResult == kIOReturnSuccess, output.result == SMCResult.keyNotFound.rawValue {
            throw SMCClientError.keyNotFound(keyString)
        }

        throw SMCClientError.callFailed(ioResult, output.result)
    }

    private func fourCharCode(from key: String) throws -> UInt32 {
        guard key.utf8.count == 4 else {
            throw SMCClientError.invalidKey(key)
        }

        var value: UInt32 = 0
        for byte in key.utf8 {
            value = (value << 8) | UInt32(byte)
        }
        return value
    }

    private func bytesArray(from tuple: SMCBytes, count: Int) -> [UInt8] {
        withUnsafeBytes(of: tuple) { rawBuffer in
            Array(rawBuffer.prefix(max(0, min(count, 32))))
        }
    }

    private func bytesTuple(from bytes: [UInt8]) -> SMCBytes {
        var tuple: SMCBytes = (
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        )

        withUnsafeMutableBytes(of: &tuple) { rawBuffer in
            rawBuffer.copyBytes(from: bytes.prefix(32))
        }
        return tuple
    }
}
