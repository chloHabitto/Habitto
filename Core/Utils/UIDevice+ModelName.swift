import UIKit

extension UIDevice {
    /// Returns the specific device model name (e.g., "iPhone 12 Pro", "iPad Air")
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return mapToModelName(identifier: identifier)
    }
    
    private func mapToModelName(identifier: String) -> String {
        switch identifier {
        // iPhone 16 series
        case "iPhone17,1": return "iPhone 16 Pro"
        case "iPhone17,2": return "iPhone 16 Pro Max"
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"
        
        // iPhone 15 series
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        
        // iPhone 14 series
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        
        // iPhone 13 series
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        
        // iPhone 12 series
        case "iPhone13,1": return "iPhone 12 mini"
        case "iPhone13,2": return "iPhone 12"
        case "iPhone13,3": return "iPhone 12 Pro"
        case "iPhone13,4": return "iPhone 12 Pro Max"
        
        // iPhone 11 series
        case "iPhone12,1": return "iPhone 11"
        case "iPhone12,3": return "iPhone 11 Pro"
        case "iPhone12,5": return "iPhone 11 Pro Max"
        
        // iPhone SE
        case "iPhone14,6": return "iPhone SE (3rd gen)"
        case "iPhone12,8": return "iPhone SE (2nd gen)"
        
        // iPad Pro
        case "iPad16,3", "iPad16,4": return "iPad Pro 13-inch (M4)"
        case "iPad16,5", "iPad16,6": return "iPad Pro 11-inch (M4)"
        case "iPad14,5", "iPad14,6": return "iPad Pro 12.9-inch (6th gen)"
        case "iPad14,3", "iPad14,4": return "iPad Pro 11-inch (4th gen)"
        
        // iPad Air
        case "iPad14,8", "iPad14,9": return "iPad Air 13-inch (M2)"
        case "iPad14,10", "iPad14,11": return "iPad Air 11-inch (M2)"
        case "iPad13,16", "iPad13,17": return "iPad Air (5th gen)"
        
        // iPad
        case "iPad14,12": return "iPad (11th gen)"
        case "iPad13,18", "iPad13,19": return "iPad (10th gen)"
        
        // iPad mini
        case "iPad14,1", "iPad14,2": return "iPad mini (6th gen)"
        
        // Simulators
        case "i386", "x86_64", "arm64":
            return "Simulator (\(model))"
        
        default:
            return identifier // Return identifier if unknown
        }
    }
}
