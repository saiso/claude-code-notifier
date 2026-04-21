// claude-code-notifier
// macOS の UserNotifications framework を使って通知を発行する。
// Claude Code の hook から呼ばれることを想定しつつ、一般の macOS CLI としても使える。
//
// 使い方:
//   claude-code-notifier "メッセージ" ["タイトル"] ["サウンド名 or ラベル"] ["activate する bundle ID"]
//
// 設定ファイル: ~/.config/claude-code-notifier/config.json
// CLI 引数 > 設定ファイル > コード内デフォルト の優先順位で解決する。

import Foundation
import AppKit
import UserNotifications

// MARK: - 設定

struct NotifierConfig: Codable {
	var defaultTitle: String
	var activateBundleID: String
	var sounds: [String: String]

	static let `default` = NotifierConfig(
		defaultTitle: "Claude Code",
		activateBundleID: "com.microsoft.VSCode",
		sounds: [
			"default": "Glass",
			"permission": "Purr",
			"idle": "Glass"
		]
	)
}

// 入力サニタイズ用のマジックナンバー
let maxBodyLength = 500
let maxBundleIDLength = 255
let terminationDelay: TimeInterval = 0.3

// MARK: - ログ（デバッグ時のみ）

let debugEnabled = ProcessInfo.processInfo.environment["CLAUDE_CODE_NOTIFIER_DEBUG"] == "1"
let logPath = FileManager.default.homeDirectoryForCurrentUser
	.appendingPathComponent(".claude/apps/notifier.log")

func logMsg(_ message: String) {
	guard debugEnabled else { return }
	let entry = "\(Date()) \(message)\n"
	guard let data = entry.data(using: .utf8) else { return }
	// ログディレクトリが存在しなければ作る
	let logDir = logPath.deletingLastPathComponent()
	try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
	if FileManager.default.fileExists(atPath: logPath.path) {
		if let fh = try? FileHandle(forWritingTo: logPath) {
			fh.seekToEndOfFile()
			fh.write(data)
			try? fh.close()
		}
	} else {
		try? data.write(to: logPath)
	}
}

func writeStderr(_ message: String) {
	if let data = (message + "\n").data(using: .utf8) {
		FileHandle.standardError.write(data)
	}
}

// MARK: - 設定の読み込み

func loadConfig() -> NotifierConfig {
	let configDir = FileManager.default.homeDirectoryForCurrentUser
		.appendingPathComponent(".config/claude-code-notifier")
	let configPath = configDir.appendingPathComponent("config.json")

	if !FileManager.default.fileExists(atPath: configPath.path) {
		try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		if let data = try? encoder.encode(NotifierConfig.default) {
			try? data.write(to: configPath)
			logMsg("デフォルト設定を書き出し: \(configPath.path)")
		}
		return NotifierConfig.default
	}

	do {
		let data = try Data(contentsOf: configPath)
		return try JSONDecoder().decode(NotifierConfig.self, from: data)
	} catch {
		writeStderr("claude-code-notifier: 設定ファイルが読み込めない (\(error.localizedDescription))、デフォルトを使用する")
		return NotifierConfig.default
	}
}

// MARK: - 入力検証

func isValidSoundName(_ name: String) -> Bool {
	// macOS 標準のサウンド名（Glass, Purr, Hero 等）は英数字のみ。
	// パス区切り文字やサフィックスを含む値は拒否する。
	let pattern = "^[A-Za-z0-9_]+$"
	return name.range(of: pattern, options: .regularExpression) != nil
		&& name.count <= 64
}

func isValidBundleID(_ id: String) -> Bool {
	// Bundle ID の一般的な文字（英数字 + ピリオド + ハイフン）に制限。
	let pattern = "^[a-zA-Z0-9.\\-]+$"
	return id.range(of: pattern, options: .regularExpression) != nil
		&& id.count <= maxBundleIDLength
}

func sanitizeBody(_ body: String) -> String {
	// 制御文字を除去し、最大長で切り詰める。
	let filtered = body.unicodeScalars.filter { scalar in
		// ASCII 制御文字 (0x00〜0x1F) と DEL (0x7F) を除外。改行だけは許可する。
		if scalar == "\n" || scalar == "\t" { return true }
		return !(scalar.value < 0x20 || scalar.value == 0x7F)
	}
	let cleaned = String(String.UnicodeScalarView(filtered))
	if cleaned.count > maxBodyLength {
		return String(cleaned.prefix(maxBodyLength))
	}
	return cleaned
}

func resolveSound(_ argument: String?, config: NotifierConfig) -> String {
	let fallback = config.sounds["default"] ?? "Glass"
	guard let arg = argument, !arg.isEmpty else { return fallback }

	// ラベル解決（config.sounds のキー）
	if let mapped = config.sounds[arg] {
		return isValidSoundName(mapped) ? mapped : fallback
	}
	// 直接のサウンド名として扱う
	return isValidSoundName(arg) ? arg : fallback
}

func resolveBundleID(_ argument: String?, config: NotifierConfig) -> String {
	if let arg = argument, !arg.isEmpty, isValidBundleID(arg) {
		return arg
	}
	return isValidBundleID(config.activateBundleID) ? config.activateBundleID : "com.microsoft.VSCode"
}

// MARK: - アプリ本体

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
	var message: String = ""
	var title: String = ""
	var soundName: String = ""
	var activateBundleID: String = ""

	func applicationDidFinishLaunching(_ notification: Notification) {
		let center = UNUserNotificationCenter.current()
		center.delegate = self

		// 引数なし or message 空 = 通知クリック時 → activate 対象を前面に
		if message.isEmpty {
			logMsg("空メッセージ分岐: activate \(activateBundleID)")
			activateTargetApp { [weak self] in
				DispatchQueue.main.asyncAfter(deadline: .now() + terminationDelay) {
					_ = self
					NSApp.terminate(nil)
				}
			}
			return
		}

		center.getNotificationSettings { [weak self] settings in
			guard let self = self else { return }
			logMsg("authorizationStatus: \(settings.authorizationStatus.rawValue)")

			switch settings.authorizationStatus {
			case .denied:
				writeStderr("claude-code-notifier: 通知権限が拒否されている。システム設定 → 通知 で許可してください。")
				DispatchQueue.main.async { NSApp.terminate(nil) }
				return
			case .authorized, .provisional, .ephemeral:
				DispatchQueue.main.async { self.fireNotification() }
			case .notDetermined:
				center.requestAuthorization(options: [.alert, .sound]) { granted, error in
					if let error = error {
						logMsg("requestAuthorization エラー: \(error.localizedDescription)")
					}
					logMsg("requestAuthorization granted=\(granted)")
					DispatchQueue.main.async {
						if granted {
							self.fireNotification()
						} else {
							writeStderr("claude-code-notifier: 通知権限が許可されなかった")
							NSApp.terminate(nil)
						}
					}
				}
			@unknown default:
				DispatchQueue.main.async { NSApp.terminate(nil) }
			}
		}
	}

	func activateTargetApp(completion: @escaping () -> Void = {}) {
		guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: activateBundleID) else {
			logMsg("activate 対象アプリが見つからない: \(activateBundleID)")
			completion()
			return
		}
		let config = NSWorkspace.OpenConfiguration()
		config.activates = true
		NSWorkspace.shared.openApplication(at: url, configuration: config) { _, err in
			if let err = err {
				logMsg("activate エラー: \(err)")
			} else {
				logMsg("activate 成功: \(self.activateBundleID)")
			}
			completion()
		}
	}

	func fireNotification() {
		let content = UNMutableNotificationContent()
		content.title = title
		content.body = message
		content.sound = UNNotificationSound(named: UNNotificationSoundName("\(soundName).aiff"))
		content.userInfo = ["activateBundleID": activateBundleID]

		let request = UNNotificationRequest(
			identifier: UUID().uuidString,
			content: content,
			trigger: nil
		)

		let center = UNUserNotificationCenter.current()
		center.add(request) { error in
			if let error = error {
				logMsg("通知追加エラー: \(error.localizedDescription)")
				writeStderr("claude-code-notifier: 通知追加に失敗 (\(error.localizedDescription))")
			} else {
				logMsg("通知追加成功: \(self.title) / \(self.message)")
			}
			DispatchQueue.main.asyncAfter(deadline: .now() + terminationDelay) {
				NSApp.terminate(nil)
			}
		}
	}

	func userNotificationCenter(_ center: UNUserNotificationCenter,
	                            willPresent notification: UNNotification,
	                            withCompletionHandler completionHandler:
	                            @escaping (UNNotificationPresentationOptions) -> Void) {
		completionHandler([.banner, .sound])
	}

	func userNotificationCenter(_ center: UNUserNotificationCenter,
	                            didReceive response: UNNotificationResponse,
	                            withCompletionHandler completionHandler: @escaping () -> Void) {
		guard let raw = response.notification.request.content.userInfo["activateBundleID"] as? String,
		      isValidBundleID(raw),
		      let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: raw) else {
			completionHandler()
			return
		}
		let config = NSWorkspace.OpenConfiguration()
		config.activates = true
		NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
			completionHandler()
		}
	}
}

// MARK: - エントリポイント

let args = CommandLine.arguments
logMsg("起動 args=\(args)")

let config = loadConfig()

let rawMessage = args.count > 1 ? args[1] : ""
let message = sanitizeBody(rawMessage)
let title = args.count > 2 && !args[2].isEmpty ? sanitizeBody(args[2]) : config.defaultTitle
let rawSoundArg = args.count > 3 ? args[3] : nil
let soundName = resolveSound(rawSoundArg, config: config)
let rawBundleArg = args.count > 4 ? args[4] : nil
let activateBundleID = resolveBundleID(rawBundleArg, config: config)

let app = NSApplication.shared
let delegate = AppDelegate()
delegate.message = message
delegate.title = title
delegate.soundName = soundName
delegate.activateBundleID = activateBundleID
app.delegate = delegate

app.setActivationPolicy(.accessory)
app.run()
