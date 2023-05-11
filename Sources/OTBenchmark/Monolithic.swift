//
//  File.swift
//  
//
//  Created by Andreas Loizides on 23/03/2023.
//

import NIO
import NIOHTTP1
import NIOHTTP2
import NIOSSL
import Foundation
import AsyncHTTPClient
import NIOFoundationCompat
import PowersoftKit
import ShopifyKit
import MockPowersoftClient
import MockShopifyClient
import OTModelSyncer
import RateLimitingCommunicator

struct MonolithicRunner: WorkloadRunner{
	static var shortIdentifier: String = "M"
	
	let psClient: MockPowersoftClient.MockPsClient
	
	let shClient: MockShopifyClient.MockShClient
	
	
	static let name: String = "Monolithic"
	let psURL: URL
	let shURL: URL
	let rl: RLCommunicator?
	init(psURL: URL, shURL: URL, msDelay: Int?) {
		self.psURL = psURL
		self.shURL = shURL
		self.psClient = .init(baseURL: psURL)
		self.shClient = .init(baseURL: shURL)
		if let msDelay{
			self.rl = RLCommunicator(minDelay: .milliseconds(msDelay))
		}else{
			self.rl = nil
		}
		
	}
	func runSync(input: SyncModelInput) async -> SyncModelResult {
		let param = input
		
		
		let (nanos, r) = await measureInNanos{
			await MonoClient.sendRequest(withParameters: param)
		}
		
		let g = MonoClient.wasSuccessful(o: r)
		
		let success = g["error"] == nil
		
		return .init(input: input, dictOutput: r, succ: success ? g : nil, nanos: nanos)
	}
}
//
/*
											panic: runtime error: slice bounds out of range [:7105] with capacity 4096",
		 ",
		 goroutine 86 [running]:",
		 bufio.(*Reader).ReadSlice(0xc000136540, 0x0?)",
		 \t/usr/local/go/src/bufio/bufio.go:346 +0x22d",
		 bufio.(*Reader).collectFragments(0x0?, 0x0?)",
		 \t/usr/local/go/src/bufio/bufio.go:446 +0x74",
		 bufio.(*Reader).ReadBytes(0x0?, 0x0?)",
		 \t/usr/local/go/src/bufio/bufio.go:474 +0x1d",
		 "2023-05-04T12:39:51.45178178Z  stdout: github.com/apache/openwhisk-runtime-go/openwhisk.(*Executor)
 */
class MonoClient{
	static let encoder = JSONEncoder()
	static let decoder = JSONDecoder()
	static var monoURL: URL?
	class func wasSuccessful(o: [String: Any])->[String: Any]{
		
		guard let _ = o["source"] as? [String: Any] else {
			return ["error":"no source! Got: \(o)"]
		}
		
		guard let _ = o["metadata"] as? [String: Any] else{
			return ["error":"no metadata! Got: \(o)"]
		}
		return o
	}
	class func sendRequest<T: Codable, T2: Codable>(withParameters params : T?, expect: T2.Type) async -> ([String:Any], T2?){
		let o = await sendRequest(withParameters: params)

		guard let r = o["response"] as? [String: Any] else {
			return (["error":"no response! Got: \(o)"],nil)
		}
		
		guard let result = r["result"] as? [String: Any] else{
			return (["error":"no result! Got: \(o)"], nil)
		}
		do{
			let data = try JSONSerialization.data(withJSONObject: result)
			let decoded = try Self.decoder.decode(T2.self, from: data)
			return (o, decoded)
		}catch{
			let e = "Error decoding as \(T2.self)! Got \(error.localizedDescription). Result dict: \(result)"
			print(e)
			return (["error":e], nil)
		}
	}
	class func sendRequest<T: Codable>(withParameters params : T?) async -> [String:Any] {
		guard let params else{
			return await sendRequest(params: nil)
		}
		do{
			guard let o = try params.asJsonDict(encoder: Self.encoder)else{
				return ["error":"can't parse as [String: Any]! (is a json object but not a dictionary!)"]
			}
			return await sendRequest(params: o)
		}catch{
			return ["error":"can't parse as [String: Any]! \(error.localizedDescription)"]
		}
	}
	class func sendRequest(params: [String: Any]?)async->[String:Any]{
		let url = Self.monoURL!.customAppendingPath2(path: "syncModel")

		do {
			var body: HTTPClient.Body? = nil
			if let params{
				let data = try JSONSerialization.data(withJSONObject: params)
				body = .byteBuffer(.init(data: data))
			}

			
			guard let data = try await Client.shared.sendRequest(url: url, method: .POST, body: body) else {
				return ["error":"empty response!"]
			}
			do {
				//let outputStr  = String(data: data, encoding: String.Encoding.utf8) as String!
				//print(outputStr)
				let respJson = try JSONSerialization.jsonObject(with: data)
				if respJson is [String:Any] {
					return respJson as! [String:Any]
				} else {
					return ["error":" response from server is not a dictionary"]
				}
			} catch {
				if let str = String(data: data, encoding: .utf8){
					print("String response: ",str)
				}
				return ["error":"Error creating json from response: \(error)"]
			}
		} catch {
			return ["error":"Got error creating params body: \(error)"]
		}
	}
}
extension URL{
	func customAppendingPath2(path: String)->Self{
		let u: URL = .init(string: path)!
		var s = self
		for p in u.pathComponents{
			s = s.appendingPathComponent(p)
		}
		return s
	}
}
