//
//  Server+TLS.swift
//  feather
//
//  Created by samara on 22.08.2024.
//  Copyright © 2024 Lakr Aream. All Rights Reserved.
//  ORIGINALLY LICENSED UNDER GPL-3.0, MODIFIED FOR USE FOR FEATHER
//

import Foundation
import NIOSSL
import NIOTLS
import Vapor
import SystemConfiguration.CaptiveNetwork

// MARK: - Class extension: TLS/Setup
extension ServerInstaller {
	// MARK: Setup
	static let env: Environment = {
		var env = try! Environment.detect()
		try! LoggingSystem.bootstrap(from: &env)
		return env
	}()
	
	func setupApp(port: Int) throws -> Application {
		let app = Application(Self.env)
		app.threadPool = .init(numberOfThreads: 1)
		
		if getServerMethod() != 1 {
			if let tls = try tls() {
				app.http.server.configuration.tlsConfiguration = tls
			}
		}
		
		app.http.server.configuration.hostname = sni()
		app.http.server.configuration.tcpNoDelay = true
		// Only listen on the network when Semi Local hands iOS this device's network address.
		let loopbackOnly = getServerMethod() == 0 || getIPFix()
		app.http.server.configuration.address = .hostname(loopbackOnly ? "127.0.0.1" : "0.0.0.0", port: port)
		app.http.server.configuration.port = port
		app.routes.defaultMaxBodySize = "128mb"
		app.routes.caseInsensitive = false
		
		return app
	}
	
	// MARK: Files/IP
	func sni() -> String {
		let localhost = "127.0.0.1"
		
		if getServerMethod() == 1 {
			return !self.getIPFix()
				? (Self.getLocalAddress() ?? localhost)
				: localhost
		} else {
			return readCommonName() ?? localhost
		}
	}
	
	func tls() throws -> TLSConfiguration? {
		guard
			let crt = Self.getUrl("server", ext: "crt"),
			let pem = Self.getUrl("server", ext: "pem")
		else {
			return nil
		}
		
		return try TLSConfiguration.makeServerConfiguration(
			certificateChain: NIOSSLCertificate.fromPEMFile(crt.path).map {
				NIOSSLCertificateSource.certificate($0)
			},
			privateKey: .privateKey(
				try NIOSSLPrivateKey(file: pem.path, format: .pem)
			)
		)
	}
	
	static func isCertificateTrusted() -> Bool {
		guard let url = getUrl("server", ext: "crt"), let pem = try? String(contentsOf: url, encoding: .utf8) else { return false }
		return isTrusted(pem: pem)
	}

	static func isTrusted(pem: String) -> Bool {
		let certificates = pem.components(separatedBy: "-----END CERTIFICATE-----").compactMap { block -> SecCertificate? in
			let body = block.components(separatedBy: "\n").filter { !$0.isEmpty && !$0.hasPrefix("-----") }.joined()
			guard let der = Data(base64Encoded: body) else { return nil }
			return SecCertificateCreateWithData(nil, der as CFData)
		}
		guard !certificates.isEmpty else { return false }
		var trust: SecTrust?
		guard SecTrustCreateWithCertificates(certificates as CFArray, SecPolicyCreateSSL(true, nil), &trust) == errSecSuccess, let trust else { return false }
		return SecTrustEvaluateWithError(trust, nil)
	}

	/// True when the host's DNS answer is 127.0.0.1. Some routers and DNS filters drop
	/// public names that point at loopback, which breaks Fully Local.
	static func resolvesToThisDevice(_ host: String) -> Bool {
		if host == "127.0.0.1" || host == "localhost" { return true }
		var hints = addrinfo()
		hints.ai_family = AF_INET
		hints.ai_socktype = SOCK_STREAM
		var result: UnsafeMutablePointer<addrinfo>?
		guard getaddrinfo(host, nil, &hints, &result) == 0 else { return false }
		defer { freeaddrinfo(result) }
		var pointer = result
		while let info = pointer {
			if info.pointee.ai_family == AF_INET, let address = info.pointee.ai_addr {
				let ipv4 = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
				if UInt32(bigEndian: ipv4) == 0x7F000001 { return true }
			}
			pointer = info.pointee.ai_next
		}
		return false
	}

	func readCommonName() -> String? {
		guard let url = Self.getUrl("commonName", ext: "txt") else {
			return nil
		}
		
		return try? String(contentsOf: url, encoding: .utf8)
			.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}

extension ServerInstaller {
	static func getUrl(_ name: String, ext: String) -> URL? {
		let fileManager = FileManager.default
		
		let documentsURL = URL.documentsDirectory.appendingPathComponent("\(name).\(ext)")
		let bundlesURL = Bundle.main.url(forResource: name, withExtension: ext)
		
		if fileManager.fileExists(atPath: documentsURL.path) {
			return documentsURL
		}
		
		if let bundlesURL, fileManager.fileExists(atPath: bundlesURL.path) {
			return bundlesURL
		}
		
		return nil
	}
	
	static func getLocalAddress() -> String? {
		var address: String?
		var ifaddr: UnsafeMutablePointer<ifaddrs>?
		
		if getifaddrs(&ifaddr) == 0 {
			var ptr = ifaddr
			while ptr != nil {
				let interface = ptr!.pointee
				let addrFamily = interface.ifa_addr.pointee.sa_family
				
				if addrFamily == UInt8(AF_INET) {
					
					let name = String(cString: interface.ifa_name)
					if name == "en0" || name == "pdp_ip0" {
						
						var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
						if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
						               &hostname, socklen_t(hostname.count),
						               nil, socklen_t(0), NI_NUMERICHOST) == 0 {
							address = String(cString: hostname)
						}
						
					}
				}
				ptr = ptr!.pointee.ifa_next
			}
			freeifaddrs(ifaddr)
		}
		
		return address
	}
}
