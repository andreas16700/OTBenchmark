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
func syncModel(input: SyncModelInput)async -> ( [String: Any], [String: Any]?){
	let name = "syncModel"
	let param = input
//	let s = await Whisk.invoke(actionNamed: name, withParameters: param, blocking: true)
//	for (k,v) in s{
//		print(k,"\(v)")
//	}
	let r = await Whisk.invoke(actionNamed: name, withParameters: param)
	let g = Whisk.wasSuccessful(o: r)
	let success = g["error"] == nil
	return (r, success ? g : nil)
}

struct ServerlessRunner: WorkloadRunner{
	init(psURL: URL, shURL: URL) {
		psClient = .init(baseURL: psURL)
		shClient = .init(baseURL: shURL)
		self.psURL=psURL
		self.shURL=shURL
	}
	
	static var name: String = "Serverless"
	let psURL: URL
	var psClient: MockPowersoftClient.MockPsClient
	let shURL: URL
	var shClient: MockShopifyClient.MockShClient
	
	func runSync(sourceData source: SourceData) async throws -> (Int, Int){
		print("[I] Starting syncers... [S]")
		let clientsInfo: ClientsInfo = .init(psURL: psURL, shURL: shURL)
		return await withTaskGroup(of: [String: Any]?.self, returning: (Int, Int).self){group in
			for (modelCode, model) in source.psModelsByModelCode{
				let refItem = model.first!
				let stocks = source.psStocksByModelCode[modelCode] ?? []
				
				let product = source.shProdsByHandle[refItem.getShHandle()]
				let shStocks = product?.appropriateStocks(from: source.shStocksByInvID)
				let input = SyncModelInput(clientsInfo: clientsInfo, modelCode: modelCode, model: model, psStocks: stocks, product: product, shInv: shStocks)
				group.addTask{
					let s = await syncModel(input: input)
					if s.1 == nil{
						print("[I] Failed for \(modelCode) [S]")
						print(s.0)
					}
					return s.1
				}
			}
//			await group.waitForAll()
			var fails = 0
			var successes = 0
			for await sync in group{
				if sync == nil{
					fails+=1
				}else{
					successes+=1
				}
			}
			return (successes, fails)
		}
	}
}
