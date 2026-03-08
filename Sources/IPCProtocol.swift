import Foundation

// MARK: - Incoming Commands (App → Daemon)

struct IPCCommand: Codable {
  let type: String
  var contactName: String?
  var contactPhone: String?
  var message: String?
}

// MARK: - Outgoing Messages (Daemon → App)

struct IPCMessage: Codable {
  let type: String
  var success: Bool?
  var version: String?
  var pmset: Bool?
  var lockScreen: Bool?
  var powerButton: Bool?
  var accessibilityGranted: Bool?
  var message: String?

  static func authResult(_ success: Bool, version: String? = nil) -> IPCMessage {
    IPCMessage(type: "auth_result", success: success, version: version)
  }

  static func status(
    pmset: Bool, lockScreen: Bool, powerButton: Bool, accessibilityGranted: Bool
  ) -> IPCMessage {
    IPCMessage(
      type: "status", pmset: pmset, lockScreen: lockScreen,
      powerButton: powerButton, accessibilityGranted: accessibilityGranted
    )
  }

  static func powerButtonPressed() -> IPCMessage {
    IPCMessage(type: "power_button_pressed")
  }

  static func error(_ msg: String) -> IPCMessage {
    IPCMessage(type: "error", message: msg)
  }
}
