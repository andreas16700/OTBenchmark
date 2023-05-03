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
	
	static let name: String = "Monolithic"
	var psClient: MockPsClient
	var shClient: MockShClient
	init(psURL: URL, shURL: URL) {
		self.psClient = MockPsClient(baseURL: psURL)
		self.shClient = MockShClient(baseURL: shURL)
	}
	func runSync(sourceData source: SourceData) async throws{
		print("[I] Starting syncers... [M]")
		await withTaskGroup(of: SingleModelSync?.self){group in
			for (modelCode, model) in source.psModelsByModelCode{
				let refItem = model.first!
				let stocks = source.psStocksByModelCode[modelCode] ?? []
				
				let product = source.shProdsByHandle[refItem.getShHandle()]
				let shStocks = product?.appropriateStocks(from: source.shStocksByInvID)
				let shData = product == nil ? nil : (product!,shStocks!)
				let syncer = SingleModelSyncer(modelCode: modelCode, ps: psClient, sh: shClient, psDataToUse: (model,stocks), shDataToUse: shData, saveMethod: nil)
				group.addTask{
					let s = await syncer.sync(savePeriodically: false)
					if s == nil{
						print("[I] Failed for \(modelCode) [M]")
					}
					return s
				}
			}
			await group.waitForAll()
		}
	}
}
