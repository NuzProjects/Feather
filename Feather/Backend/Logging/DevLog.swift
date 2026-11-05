import Foundation
import OSLog
import UIKit
import MetricKit

/// Developer logs: one file per launch, crash reports and MetricKit diagnostics.
/// Everything lives in Library/Application Support/Logs and never leaves the device unless the user exports it.
final class DevLog: NSObject, @unchecked Sendable {
	static let shared = DevLog()

	enum Level: String { case info = "INFO", warning = "WARN", error = "ERROR" }

	private static let maxSessions = 10
	private static let maxCrashes = 20

	let root: URL
	let sessionsDirectory: URL
	let crashesDirectory: URL
	private let pendingCrashURL: URL
	private(set) var sessionURL: URL
	private(set) var didCrashLastLaunch = false
	private var crashPromptShown = false
	private let launchDate = Date()
	private let queue = DispatchQueue(label: "Feather.DevLog", qos: .utility)
	private var handle: FileHandle?
	private var started = false

	private static let fileStamp: DateFormatter = {
		let f = DateFormatter()
		f.locale = Locale(identifier: "en_US_POSIX")
		f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
		return f
	}()
	private static let lineStamp: DateFormatter = {
		let f = DateFormatter()
		f.locale = Locale(identifier: "en_US_POSIX")
		f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
		return f
	}()

	private override init() {
		let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
		root = base.appendingPathComponent("Logs", isDirectory: true)
		sessionsDirectory = root.appendingPathComponent("Sessions", isDirectory: true)
		crashesDirectory = root.appendingPathComponent("Crashes", isDirectory: true)
		pendingCrashURL = root.appendingPathComponent("pending-crash.log")
		sessionURL = sessionsDirectory.appendingPathComponent("session-\(Self.fileStamp.string(from: Date())).log")
		super.init()
	}

	// MARK: Start

	/// Call once, as early as possible in `didFinishLaunching`.
	func start() {
		guard !started else { return }
		started = true
		let fm = FileManager.default
		try? fm.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
		try? fm.createDirectory(at: crashesDirectory, withIntermediateDirectories: true)

		_collectPendingCrash()
		_prune(sessionsDirectory, keep: Self.maxSessions - 1)
		_prune(crashesDirectory, keep: Self.maxCrashes)

		fm.createFile(atPath: sessionURL.path, contents: Data(Self.deviceSummary.utf8))
		handle = try? FileHandle(forWritingTo: sessionURL)
		handle?.seekToEndOfFile()

		CrashTrap.install(at: pendingCrashURL, header: Self.deviceSummary + "Session: \(sessionURL.lastPathComponent)\n")
		MXMetricManager.shared.add(self)

		log(.info, "Launched", category: "App")
		NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
			self?.log(.info, "Entered background", category: "App")
			self?.snapshotSystemLog()
		}
		NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
			self?.log(.info, "Entered foreground", category: "App")
		}
		NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil) { [weak self] _ in
			self?.log(.warning, "Memory warning", category: "App")
		}
	}

	/// True once per launch when the previous launch crashed, so the prompt never shows twice.
	func takeCrashPrompt() -> Bool {
		guard didCrashLastLaunch, !crashPromptShown else { return false }
		crashPromptShown = true
		return true
	}

	// MARK: Logging

	func log(_ level: Level, _ message: String, category: String = "App") {
		let line = "[\(Self.lineStamp.string(from: Date()))] [\(level.rawValue)] [\(category)] \(message)\n"
		queue.async { [weak self] in
			self?.handle?.write(Data(line.utf8))
		}
	}

	func error(_ error: Error, while action: String, category: String = "App") {
		let ns = error as NSError
		log(.error, "\(action) failed: \(error.localizedDescription) (\(ns.domain) \(ns.code))", category: category)
	}

	// MARK: System log

	private var systemLogURL: URL {
		sessionURL.deletingPathExtension().appendingPathExtension("oslog")
	}

	/// Copies this process's `os_log` entries (the existing `Logger.misc` / `Logger.signing` calls) next to the session file.
	func snapshotSystemLog() {
		queue.async { [self] in
			guard let store = try? OSLogStore(scope: .currentProcessIdentifier) else { return }
			let subsystem = Bundle.main.bundleIdentifier ?? ""
			let position = store.position(date: launchDate)
			guard let entries = try? store.getEntries(at: position) else { return }
			var text = ""
			for case let entry as OSLogEntryLog in entries where entry.subsystem == subsystem {
				text += "[\(Self.lineStamp.string(from: entry.date))] [\(Self._name(entry.level))] [\(entry.category)] \(entry.composedMessage)\n"
			}
			try? Data(text.utf8).write(to: systemLogURL, options: .atomic)
		}
	}

	private static func _name(_ level: OSLogEntryLog.Level) -> String {
		switch level {
		case .debug: return "DEBUG"
		case .info: return "INFO"
		case .notice: return "NOTICE"
		case .error: return "ERROR"
		case .fault: return "FAULT"
		default: return "LOG"
		}
	}

	// MARK: Files

	var sessions: [URL] { _files(in: sessionsDirectory, extensions: ["log"]) }
	var crashes: [URL] { _files(in: crashesDirectory, extensions: ["log", "json"]) }

	func systemLog(for session: URL) -> URL? {
		let url = session.deletingPathExtension().appendingPathExtension("oslog")
		return FileManager.default.fileExists(atPath: url.path) ? url : nil
	}

	/// Writes one readable text file with device info, crashes and every session, ready to share.
	func exportBundle() async -> URL? {
		snapshotSystemLog()
		return await withCheckedContinuation { continuation in
			queue.async { [self] in
				handle?.synchronizeFile()
				var text = "Feather Developer Logs\n" + Self.deviceSummary + "Exported: \(Self.lineStamp.string(from: Date()))\n"
				let crashes = crashes
				text += "\n==================== CRASHES (\(crashes.count)) ====================\n"
				if crashes.isEmpty { text += "No crashes recorded.\n" }
				for url in crashes { text += "\n----- \(url.lastPathComponent) -----\n" + ((try? String(contentsOf: url, encoding: .utf8)) ?? "") + "\n" }
				for (index, url) in sessions.enumerated() {
					text += "\n==================== \(index == 0 ? "CURRENT SESSION" : "SESSION") \(url.lastPathComponent) ====================\n"
					text += (try? String(contentsOf: url, encoding: .utf8)) ?? ""
					if let system = systemLog(for: url), let body = try? String(contentsOf: system, encoding: .utf8), !body.isEmpty {
						text += "\n----- System log -----\n" + body
					}
				}
				let out = FileManager.default.temporaryDirectory.appendingPathComponent("Feather-Logs-\(Self.fileStamp.string(from: Date())).txt")
				do {
					try Data(text.utf8).write(to: out, options: .atomic)
					continuation.resume(returning: out)
				} catch {
					continuation.resume(returning: nil)
				}
			}
		}
	}

	/// Removes crashes and previous sessions. The current session is emptied, not deleted.
	func clear() {
		queue.sync {
			let fm = FileManager.default
			for url in crashes { try? fm.removeItem(at: url) }
			for url in sessions where url != sessionURL {
				try? fm.removeItem(at: url)
				if let system = systemLog(for: url) { try? fm.removeItem(at: system) }
			}
			handle?.truncateFile(atOffset: 0)
			handle?.write(Data(Self.deviceSummary.utf8))
			try? fm.removeItem(at: systemLogURL)
			didCrashLastLaunch = false
		}
	}

	private func _files(in directory: URL, extensions: [String]) -> [URL] {
		let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)) ?? []
		func date(_ url: URL) -> Date { (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast }
		return urls
			.filter { extensions.contains($0.pathExtension) }
			.sorted { date($0) > date($1) }
	}

	private func _prune(_ directory: URL, keep: Int) {
		let all = directory == sessionsDirectory ? sessions : crashes
		for url in all.dropFirst(max(keep, 0)) {
			try? FileManager.default.removeItem(at: url)
			if directory == sessionsDirectory, let system = systemLog(for: url) { try? FileManager.default.removeItem(at: system) }
		}
	}

	private func _collectPendingCrash() {
		guard
			let data = FileManager.default.contents(atPath: pendingCrashURL.path),
			let text = String(data: data, encoding: .utf8),
			text.contains(CrashTrap.marker)
		else { return }
		let destination = crashesDirectory.appendingPathComponent("crash-\(Self.fileStamp.string(from: Date())).log")
		try? data.write(to: destination, options: .atomic)
		didCrashLastLaunch = true
	}

	// MARK: Device

	static let deviceSummary: String = {
		var system = utsname()
		uname(&system)
		let model = withUnsafeBytes(of: &system.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
		let info = Bundle.main.infoDictionary
		let label = info?["FeatherVersionLabel"] as? String ?? ""
		let version = info?["CFBundleShortVersionString"] as? String ?? "?"
		let build = info?["CFBundleVersion"] as? String ?? "?"
		return """
		App: Feather \(label.isEmpty ? version : label) (\(version), build \(build))
		Bundle: \(Bundle.main.bundleIdentifier ?? "?")
		Device: \(model), \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)
		Locale: \(Locale.current.identifier)

		"""
	}()
}

// MARK: - MetricKit

extension DevLog: MXMetricManagerSubscriber {
	func didReceive(_ payloads: [MXDiagnosticPayload]) {
		for payload in payloads {
			let name = "diagnostic-\(Self.fileStamp.string(from: payload.timeStampEnd)).json"
			try? payload.jsonRepresentation().write(to: crashesDirectory.appendingPathComponent(name), options: .atomic)
		}
		log(.warning, "Received \(payloads.count) diagnostic report(s) from iOS", category: "MetricKit")
	}
}

// MARK: - Crash trap

/// Writes a crash report to a pre-opened file from inside the signal handler,
/// using only `write` and `backtrace_symbols_fd`, so it doesn't allocate after a crash.
enum CrashTrap {
	static let marker = "*** CRASH"
	fileprivate static var fd: Int32 = -1
	fileprivate static var frames = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: 128)
	private static var previousExceptionHandler: NSUncaughtExceptionHandler?

	static func install(at url: URL, header: String) {
		fd = open(url.path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
		guard fd >= 0 else { return }
		_ = frames
		_write(header)

		previousExceptionHandler = NSGetUncaughtExceptionHandler()
		NSSetUncaughtExceptionHandler { exception in
			let text = "\n\(CrashTrap.marker): uncaught exception ***\nName: \(exception.name.rawValue)\nReason: \(exception.reason ?? "none")\n\n"
				+ exception.callStackSymbols.joined(separator: "\n") + "\n"
			CrashTrap._write(text)
			CrashTrap.previousExceptionHandler?(exception)
		}

		for signal in [SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGTRAP] {
			Darwin.signal(signal, crashTrapSignalHandler)
		}
	}

	fileprivate static func _write(_ text: String) {
		guard fd >= 0 else { return }
		var text = text
		text.withUTF8 { _ = Darwin.write(fd, $0.baseAddress, $0.count) }
	}
}

private func crashTrapSignalHandler(_ signal: Int32) {
	let fd = CrashTrap.fd
	if fd >= 0 {
		let name: StaticString
		switch signal {
		case SIGABRT: name = "\n*** CRASH: SIGABRT (abort) ***\n"
		case SIGSEGV: name = "\n*** CRASH: SIGSEGV (bad memory access) ***\n"
		case SIGBUS: name = "\n*** CRASH: SIGBUS (bus error) ***\n"
		case SIGILL: name = "\n*** CRASH: SIGILL (illegal instruction) ***\n"
		case SIGFPE: name = "\n*** CRASH: SIGFPE (arithmetic error) ***\n"
		case SIGTRAP: name = "\n*** CRASH: SIGTRAP (Swift runtime error) ***\n"
		default: name = "\n*** CRASH: signal ***\n"
		}
		_ = write(fd, name.utf8Start, name.utf8CodeUnitCount)
		let count = backtrace(CrashTrap.frames, 128)
		backtrace_symbols_fd(CrashTrap.frames, count, fd)
		fsync(fd)
	}
	Darwin.signal(signal, SIG_DFL)
	raise(signal)
}
