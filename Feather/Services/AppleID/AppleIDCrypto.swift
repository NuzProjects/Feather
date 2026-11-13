import Foundation
import CryptoKit
import CommonCrypto
import OpenSSL

enum AppleIDCryptoError: LocalizedError {
	case failed(String)

	var errorDescription: String? {
		switch self {
		case .failed(let step): String(format: .localized("A security step failed while talking to Apple (%@). Try again."), step)
		}
	}
}

enum AppleIDCrypto {
	static func sha256(_ data: Data) -> Data {
		Data(SHA256.hash(data: data))
	}

	static func hmac(key: Data, _ message: Data) -> Data {
		Data(HMAC<SHA256>.authenticationCode(for: message, using: SymmetricKey(data: key)))
	}

	static func pbkdf2(_ password: Data, salt: Data, rounds: Int) throws -> Data {
		var output = [UInt8](repeating: 0, count: 32)
		let passwordBytes = [Int8](password.map { Int8(bitPattern: $0) })
		let saltBytes = [UInt8](salt)
		let status = CCKeyDerivationPBKDF(
			CCPBKDFAlgorithm(kCCPBKDF2),
			passwordBytes, passwordBytes.count,
			saltBytes, saltBytes.count,
			CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
			UInt32(rounds),
			&output, output.count
		)
		guard status == Int32(kCCSuccess) else { throw AppleIDCryptoError.failed("PBKDF2") }
		return Data(output)
	}

	static func decryptCBC(_ data: Data, key: Data, iv: Data) throws -> Data {
		let input = [UInt8](data)
		let keyBytes = [UInt8](key)
		let ivBytes = [UInt8](iv.prefix(16))
		var output = [UInt8](repeating: 0, count: input.count + kCCBlockSizeAES128)
		var moved = 0
		let status = CCCrypt(
			CCOperation(kCCDecrypt),
			CCAlgorithm(kCCAlgorithmAES),
			CCOptions(kCCOptionPKCS7Padding),
			keyBytes, keyBytes.count,
			ivBytes,
			input, input.count,
			&output, output.count,
			&moved
		)
		guard status == Int32(kCCSuccess) else { throw AppleIDCryptoError.failed("CBC") }
		return Data(output.prefix(moved))
	}

	static func decryptGCM(_ data: Data, key: Data) throws -> Data {
		guard data.count > 35 else { throw AppleIDCryptoError.failed("GCM") }
		let bytes = [UInt8](data)
		let aad = Data(bytes[0..<3])
		let iv = Data(bytes[3..<19])
		let payload = Data(bytes[19..<(bytes.count - 16)])
		let tag = Data(bytes[(bytes.count - 16)...])
		let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: iv), ciphertext: payload, tag: tag)
		return try AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: aad)
	}
}

private final class BigNumber {
	let pointer: OpaquePointer

	init() {
		pointer = BN_new()
	}

	init(_ data: Data) {
		let bytes = [UInt8](data)
		pointer = BN_bin2bn(bytes, Int32(bytes.count), nil)
	}

	init(hex: String) {
		var created: OpaquePointer? = nil
		_ = BN_hex2bn(&created, hex)
		pointer = created ?? BN_new()
	}

	init(word: UInt) {
		pointer = BN_new()
		BN_set_word(pointer, word)
	}

	deinit {
		BN_clear_free(pointer)
	}

	var bytes: Data {
		let count = Int((BN_num_bits(pointer) + 7) / 8)
		guard count > 0 else { return Data() }
		var output = [UInt8](repeating: 0, count: count)
		BN_bn2bin(pointer, &output)
		return Data(output)
	}

	func padded(to count: Int) -> Data {
		let raw = bytes
		return raw.count >= count ? raw : Data(repeating: 0, count: count - raw.count) + raw
	}

	var isZero: Bool {
		BN_is_zero(pointer) == 1
	}
}

struct SRPClient {
	private static let primeHex = """
	AC6BDB41324A9A9BF166DE5E1389582FAF72B6651987EE07FC3192943DB56050A37329CBB4A099ED8193E0757767A13DD52312AB4B03310DCD7F48A9DA04FD50E8083969EDB767B0CF6095179A163AB3661A05FBD5FAAAE82918A9962F0B93B855F97993EC975EEAA80D740ADBF4FF747359D041D5C33EA71D281E446B14773BCA97B43A23FB801676BD207A436C6481F1D2B9078717461A5B9D32E688F87748544523B524B0D57D5EA77A2775D2ECFA032CFBDBF52FB3786160279004E57AE6AF874E7303CE53299CCC041C7BC308D82A5698F3A8D0C38271AE35F8E9DBFBB694B5C803D89F7AE435DE236D525F54759B65E372FCD68EF20FA7111F9E4AFF73
	"""
	private static let primeLength = 256

	private let _prime = BigNumber(hex: SRPClient.primeHex)
	private let _generator = BigNumber(word: 2)
	private let _privateKey: BigNumber
	private let _publicKey: BigNumber
	private(set) var sessionKey: Data?
	private(set) var expectedServerProof: Data?

	init() {
		var random = [UInt8](repeating: 0, count: 32)
		_ = SecRandomCopyBytes(kSecRandomDefault, random.count, &random)
		_privateKey = BigNumber(Data(random))
		_publicKey = BigNumber()
		let context = BN_CTX_new()
		BN_mod_exp(_publicKey.pointer, _generator.pointer, _privateKey.pointer, _prime.pointer, context)
		BN_CTX_free(context)
	}

	var publicKey: Data { _publicKey.bytes }

	mutating func clientProof(username: String, password: String, salt: Data, iterations: Int, legacy: Bool, serverPublicKey rawB: Data) throws -> Data {
		let serverKey = BigNumber(rawB)
		let context = BN_CTX_new()
		defer { BN_CTX_free(context) }

		let check = BigNumber()
		BN_nnmod(check.pointer, serverKey.pointer, _prime.pointer, context)
		guard !check.isZero else { throw AppleIDCryptoError.failed("SRP") }

		let hashedPassword = AppleIDCrypto.sha256(Data(password.utf8))
		let input = legacy ? Data(hashedPassword.map { String(format: "%02hhx", $0) }.joined().utf8) : hashedPassword
		let passkey = try AppleIDCrypto.pbkdf2(input, salt: salt, rounds: iterations)
		let x = BigNumber(AppleIDCrypto.sha256(salt + AppleIDCrypto.sha256(Data(":".utf8) + passkey)))

		let u = BigNumber(AppleIDCrypto.sha256(_publicKey.padded(to: Self.primeLength) + serverKey.padded(to: Self.primeLength)))
		let k = BigNumber(AppleIDCrypto.sha256(_prime.padded(to: Self.primeLength) + _generator.padded(to: Self.primeLength)))

		let gx = BigNumber()
		BN_mod_exp(gx.pointer, _generator.pointer, x.pointer, _prime.pointer, context)
		let kgx = BigNumber()
		BN_mod_mul(kgx.pointer, k.pointer, gx.pointer, _prime.pointer, context)
		let base = BigNumber()
		BN_mod_sub(base.pointer, serverKey.pointer, kgx.pointer, _prime.pointer, context)
		let ux = BigNumber()
		BN_mul(ux.pointer, u.pointer, x.pointer, context)
		let exponent = BigNumber()
		BN_add(exponent.pointer, _privateKey.pointer, ux.pointer)
		let shared = BigNumber()
		BN_mod_exp(shared.pointer, base.pointer, exponent.pointer, _prime.pointer, context)

		let key = AppleIDCrypto.sha256(shared.bytes)
		sessionKey = key

		let generatorHash = AppleIDCrypto.sha256(_generator.padded(to: Self.primeLength))
		let primeHash = AppleIDCrypto.sha256(_prime.bytes)
		let xorHash = Data(zip(generatorHash, primeHash).map { $0 ^ $1 })
		let userHash = AppleIDCrypto.sha256(Data(username.utf8))
		let publicBytes = _publicKey.bytes
		let proof = AppleIDCrypto.sha256(xorHash + userHash + salt + publicBytes + rawB + key)
		expectedServerProof = AppleIDCrypto.sha256(publicBytes + proof + key)
		return proof
	}

	func decrypt(_ data: Data) throws -> Data {
		guard let sessionKey else { throw AppleIDCryptoError.failed("SRP") }
		let key = AppleIDCrypto.hmac(key: sessionKey, Data("extra data key:".utf8))
		let iv = AppleIDCrypto.hmac(key: sessionKey, Data("extra data iv:".utf8))
		return try AppleIDCrypto.decryptCBC(data, key: key, iv: iv)
	}
}

final class SigningKeyPair {
	private let _key: OpaquePointer

	init() throws {
		guard let context = EVP_PKEY_CTX_new_id(NID_rsaEncryption, nil) else { throw AppleIDCryptoError.failed("RSA") }
		defer { EVP_PKEY_CTX_free(context) }
		guard EVP_PKEY_keygen_init(context) == 1, EVP_PKEY_CTX_set_rsa_keygen_bits(context, 2048) == 1 else { throw AppleIDCryptoError.failed("RSA") }
		var key: OpaquePointer? = nil
		guard EVP_PKEY_keygen(context, &key) == 1, let key else { throw AppleIDCryptoError.failed("RSA") }
		_key = key
	}

	deinit {
		EVP_PKEY_free(_key)
	}

	func certificateRequest(commonName: String) throws -> String {
		guard let request = X509_REQ_new() else { throw AppleIDCryptoError.failed("CSR") }
		defer { X509_REQ_free(request) }
		X509_REQ_set_version(request, 0)
		let name = X509_REQ_get_subject_name(request)
		let utf8String: Int32 = 0x1000 | 1
		X509_NAME_add_entry_by_txt(name, "C", utf8String, [UInt8]("US".utf8), -1, -1, 0)
		X509_NAME_add_entry_by_txt(name, "CN", utf8String, [UInt8](commonName.utf8), -1, -1, 0)
		guard
			X509_REQ_set_pubkey(request, _key) == 1,
			X509_REQ_sign(request, _key, EVP_sha256()) > 0
		else { throw AppleIDCryptoError.failed("CSR") }
		let bio = BIO_new(BIO_s_mem())
		defer { BIO_free(bio) }
		guard PEM_write_bio_X509_REQ(bio, request) == 1 else { throw AppleIDCryptoError.failed("CSR") }
		return String(decoding: Self._read(bio), as: UTF8.self)
	}

	func pkcs12(certificate: Data, password: String, name: String) throws -> Data {
		guard let x509 = SigningCertificateInfo.parse(certificate) else { throw AppleIDCryptoError.failed("P12") }
		defer { X509_free(x509) }
		guard let bundle = PKCS12_create(password, name, _key, x509, nil, NID_pbe_WithSHA1And3_Key_TripleDES_CBC, NID_pbe_WithSHA1And3_Key_TripleDES_CBC, 2048, 1, 0) else {
			throw AppleIDCryptoError.failed("P12")
		}
		defer { PKCS12_free(bundle) }
		let bio = BIO_new(BIO_s_mem())
		defer { BIO_free(bio) }
		guard i2d_PKCS12_bio(bio, bundle) == 1 else { throw AppleIDCryptoError.failed("P12") }
		return Self._read(bio)
	}

	fileprivate static func _read(_ bio: OpaquePointer?) -> Data {
		let pending = Int(BIO_ctrl_pending(bio))
		guard pending > 0 else { return Data() }
		var buffer = [UInt8](repeating: 0, count: pending)
		let read = BIO_read(bio, &buffer, Int32(pending))
		return Data(buffer.prefix(Int(max(0, read))))
	}
}

enum SigningCertificateInfo {
	fileprivate static func parse(_ der: Data) -> OpaquePointer? {
		let bytes = [UInt8](der)
		return bytes.withUnsafeBufferPointer { buffer -> OpaquePointer? in
			var cursor: UnsafePointer<UInt8>? = buffer.baseAddress
			return d2i_X509(nil, &cursor, buffer.count)
		}
	}

	static func serialNumber(of der: Data) -> String? {
		guard let x509 = parse(der) else { return nil }
		defer { X509_free(x509) }
		guard let serial = X509_get_serialNumber(x509), let number = ASN1_INTEGER_to_BN(serial, nil) else { return nil }
		defer { BN_free(number) }
		guard let hex = BN_bn2hex(number) else { return nil }
		defer { CRYPTO_free(hex, nil, 0) }
		return normalizedSerial(String(cString: hex))
	}

	static func expiration(of der: Data) -> Date? {
		guard let x509 = parse(der) else { return nil }
		defer { X509_free(x509) }
		guard let notAfter = X509_get0_notAfter(x509) else { return nil }
		var time = tm()
		guard ASN1_TIME_to_tm(notAfter, &time) == 1 else { return nil }
		return Date(timeIntervalSince1970: TimeInterval(timegm(&time)))
	}

	static func normalizedSerial(_ serial: String) -> String {
		let trimmed = serial.uppercased().drop { $0 == "0" }
		return trimmed.isEmpty ? "0" : String(trimmed)
	}
}
