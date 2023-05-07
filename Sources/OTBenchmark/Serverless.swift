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
func syncModel(input: SyncModelInput)async -> SyncModelResult{
	let name = "syncModel"
	let param = input
	
	
	let (nanos, r) = await measureInNanos{
		await Whisk.invoke(actionNamed: name, withParameters: param)
	}
	
	let g = Whisk.wasSuccessful(o: r)
	
	let success = g["error"] == nil
	
	return .init(input: input, dictOutput: r, succ: success ? g : nil, nanos: nanos)
}

struct ServerlessRunner: WorkloadRunner{
	
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
	func runSync(sourceData source: SourceData) async throws -> (Int, Int, [UInt64]){
		print("[I] Starting syncers... [S]")
		let clientsInfo: ClientsInfo = .init(psURL: psURL, shURL: shURL)
		return await withTaskGroup(of: ([String: Any]?, UInt64).self, returning: (Int, Int, [UInt64]).self){group in
			for (modelCode, model) in source.psModelsByModelCode{
				let refItem = model.first!
				let stocks = source.psStocksByModelCode[modelCode] ?? []
				
				let product = source.shProdsByHandle[refItem.getShHandle()]
				let shStocks = product?.appropriateStocks(from: source.shStocksByInvID)
				let input = SyncModelInput(clientsInfo: clientsInfo, modelCode: modelCode, model: model, psStocks: stocks, product: product, shInv: shStocks)
				group.addTask{
					if let rl{
						let result = try! await rl.sendRequest{
							let (duration, s) = await measureInNanos{
								await syncModel(input: input)
							}
							
							if s.succ == nil{
								print("[I] Failed for \(modelCode) [S]")
								print(s.dictOutput)
							}
	//						saveQ.async {
	//							try! s.save()
	//						}
							return (s.succ, duration)
						}
						return result
					}else{
						let (duration, s) = await measureInNanos{
							await syncModel(input: input)
						}
						
						if s.succ == nil{
							print("[I] Failed for \(modelCode) [S]")
							print(s.dictOutput)
						}
//						saveQ.async {
//							try! s.save()
//						}
						return (s.succ, duration)
					}
					
				}
			}
			
			var fails = 0
			var successes = 0
			var durations: [UInt64] = .init(repeating: 0, count: source.psModelsByModelCode.count)
			var i=0
			for await syncResult in group{
				
				if syncResult.0 == nil{
					fails+=1
				}else{
					successes+=1
				}
				durations[i]=syncResult.1
				i+=1
			}
			if i != source.psModelsByModelCode.count{
				print("i should be \(source.psModelsByModelCode.count) but is \(i)!")
			}
			return (successes, fails, durations)
		}
	}
}
