//
//  File.swift
//  
//
//  Created by Andreas Loizides on 02/05/2023.
//

import Foundation
import OTModelSyncer
import ShopifyKit
import PowersoftKit
import MockShopifyClient
import MockPowersoftClient
import RateLimitingCommunicator

struct Wrapped<T: Codable>: Codable{
	let value: T
}
func getSource()async{
	let name = "GetSourceData"
	let s = await Whisk.invoke(actionNamed: name, withParameters: nil, blocking: true)
	for (k,v) in s{
		print(k,"\(v)")
	}
}
struct ClientsInfo: Codable{
	let psURL: URL
	let shURL: URL
}
struct SyncModelInput: Codable{
	let clientsInfo: ClientsInfo
	let modelCode: String
	let model: [PSItem]?
	let psStocks: [PSListStockStoresItem]?
	let product: SHProduct?
	let shInv: [InventoryLevel]?
}
extension JSONSerialization{
	static func writeObject(object: Any, to fileURL: URL)throws{
		let data = try data(withJSONObject: object)
		try data.write(to: fileURL)
	}
}
let saveQ = DispatchQueue(label: "save queue")

struct SyncModelResult{
	let input: SyncModelInput
	let dictOutput: [String: Any]
	let succ: [String: Any]?
	let nanos: UInt64
	
//	func save()throws{
//		let fm = FileManager.default
//		let resultDesc = succ == nil ? "_fail" : "_succ"
//		let baseFileName = input.modelCode + resultDesc
//		let basePath = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent(baseFileName)
//		try fm.createDirectory(at: basePath, withIntermediateDirectories: true)
//		let inpURL = basePath.appending(path: "input.json")
//		try input.write(fileURL: inpURL)
//		let dicURL = basePath.appending(path: "dicOutput.json")
//		try JSONSerialization.writeObject(object: dictOutput, to: dicURL)
//		if let succ{
//			let succURL = basePath.appending(path: "success.json")
//			try JSONSerialization.writeObject(object: succ, to: succURL)
//		}
//	}
}
func measureInNanos<T>(_ work: ()async throws->T)async rethrows -> (UInt64, T){
	let s: DispatchTime
	let e: DispatchTime
	let r: T
	s = .now()
	r = try await work()
	e = .now()
	let duration = e.uptimeNanoseconds - s.uptimeNanoseconds
	return (duration, r)
}


struct ServerlessRunner: WorkloadRunner{
	func runSync(input: SyncModelInput) async -> SyncModelResult {
		let name = "syncModel"
		let param = input
		
		
		let (nanos, r) = await measureInNanos{
			await Whisk.invoke(actionNamed: name, withParameters: param)
		}
		
		let g = Whisk.wasSuccessful(o: r)
		
		let success = g["error"] == nil
		
		return .init(input: input, dictOutput: r, succ: success ? g : nil, nanos: nanos)
	}
	
	static var shortIdentifier: String = "S"
	
	
	init(psURL: URL, shURL: URL, msDelay: Int?) {
		psClient = .init(baseURL: psURL)
		shClient = .init(baseURL: shURL)
		self.psURL=psURL
		self.shURL=shURL
		if let msDelay{
			self.rl = .init(minDelay: .milliseconds(msDelay))
		}else{
			self.rl = nil
		}
	}
	
	static var name: String = "Serverless"
	let psURL: URL
	var psClient: MockPowersoftClient.MockPsClient
	let shURL: URL
	var shClient: MockShopifyClient.MockShClient
	let rl: RLCommunicator?
}
