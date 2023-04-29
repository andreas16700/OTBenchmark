//
//  File.swift
//  
//
//  Created by Andreas Loizides on 23/03/2023.
//

import Foundation
import PowersoftKit
import ShopifyKit
import MockShopifyClient
import MockPowersoftClient
import OTModelSyncer

struct MonolithicRunner: WorkloadRunner{
	
	var psClient: MockPsClient
	var shClient: MockShClient
	var workload: Workload
	init(using: Workload, psURL: URL, shURL: URL) {
		self.psClient = MockPsClient(baseURL: psURL)
		self.shClient = MockShClient(baseURL: shURL)
		self.workload = using
	}
	func getSourceData()async->SourceData{
		async let psItems = psClient.getAllItems(type: .eCommerceOnly)
		async let shProds = shClient.getAllProducts()
		async let psStocks = psClient.getAllStocks(type: .eCommerceOnly)
		async let shStocks = shClient.getAllInventories()
		guard
		let psItems = await psItems,
		let psStocks = await psStocks,
		let shProds = await shProds,
		let shStocks = await shStocks
		else{
			fatalError("[ERROR] failed to fetch source data!")
		}
		print("converting to dictionaries...")
		let models = Dictionary(grouping: psItems, by: {($0.modelCode365 == "") ? $0.getShHandle() : $0.modelCode365})
		
		async let prods = shProds.toDictionary(usingKP: \.handle)
		async let shStockByInvID = shStocks.toDictionary(usingKP: \.inventoryItemID)
		async let psStocksByModelCode = psStocks.toDictionaryArray(usingKP: \.modelCode365)
		
		return await .init(psModelsByModelCode: models, psStocksByModelCode: psStocksByModelCode, shProdsByHandle: prods, shStocksByInvID: shStockByInvID)
	}
	func run() async throws {
		print("retrieving source data...")
		let source = await getSourceData()
		print("Starting syncers...")
		await withTaskGroup(of: SingleModelSync?.self){group in
			for (modelCode, model) in source.psModelsByModelCode{
				let refItem = model.first!
				let stocks = source.psStocksByModelCode[modelCode] ?? []
				
				let product = source.shProdsByHandle[refItem.getShHandle()]
				let shStocks = product?.appropriateStocks(from: source.shStocksByInvID)
				let shData = product == nil ? nil : (product!,shStocks!)
				let syncer = SingleModelSyncer(modelCode: modelCode, ps: psClient, sh: shClient, psDataToUse: (model,stocks), shDataToUse: shData, saveMethod: nil)
				group.addTask{
					return await syncer.sync(savePeriodically: false)
				}
			}
			await group.waitForAll()
		}
	}
}
