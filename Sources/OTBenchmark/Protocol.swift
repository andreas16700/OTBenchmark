//
//  File.swift
//  
//
//  Created by Andreas Loizides on 23/03/2023.
//

import Foundation
import PowersoftKit
import ShopifyKit
import OTModelSyncer
import MockShopifyClient
import MockPowersoftClient

protocol WorkloadRunner{
	init(using: Workload, psURL: URL, shURL: URL)
	var workload: Workload					{get}
	var psClient: MockPsClient				{get}
	var shClient: MockShClient				{get}
	func run()async throws
}

struct SourceData{
	let psModelsByModelCode: [String: [PSItem]]
	let psStocksByModelCode: [String: [PSListStockStoresItem]]
	let shProdsByHandle: [String: SHProduct]
	let shStocksByInvID: [Int: InventoryLevel]
}
func unwrapOrFail<T>(_ failMessage: String, _ op: @autoclosure ()async->T?)async->T{
	guard let thing = await op() else{fatalError(failMessage)}
	return thing
}
func succeeds(_ failMessage: String, _ op: @autoclosure ()async->Bool?)async{
	guard await unwrapOrFail(failMessage, await op()) else {fatalError(failMessage)}
}
extension WorkloadRunner{
	func setUpServers()async{
		var gen: RandomNumberGenerator = Xorshift128Plus(xSeed: self.workload.xSeed, ySeed: self.workload.ySeed)
		let psClient = self.psClient
		let shClient = self.shClient
		let modelCount = self.workload.totalModelCount
		
		await succeeds("Could not intialize ps server!", await psClient.generateModels(modelCount: modelCount, xSeed: self.workload.xSeed, ySeed: self.workload.ySeed))
		
		let pNum = Int.random(in: 0...modelCount, using: &gen)
		let fNum = Int.random(in: 0..<modelCount, using: &gen)
		print("\(pNum) and \(fNum) models shall be partially and fully synced on the SH server respectively")
		print("Retrieving \(pNum+fNum) models from the PS server")
		
		let allModels = await unwrapOrFail("Failed getting first \(pNum+fNum) models from ps server!", await psClient.getFirstModelsAndTheirStocks(count: pNum+fNum))
		
		print("Converting \(pNum) models into partially synced products")
		let pProducts = allModels[0..<pNum].map{
			var stocks = $0.stocks
			let product = SHProduct.partiallySynced(with: $0.model, stocksByItemCode: &stocks, using: &gen)
			return ProductAndItsStocks(product: product, stocksBySKU: stocks)
		}
		print("Converting \(fNum) models into partially synced products")
		let fModels = allModels[pNum...]
		let fProducts = fModels.map{modelAndStocks in
			let product = try! modelAndStocks.model.getAsNewProduct()
			return ProductAndItsStocks(product: product, stocksBySKU: modelAndStocks.stocks)
		}
		let pfProducts = pProducts + fProducts
		print("Uploading \(pfProducts.count) products and their stocks to the SH server")
		await succeeds("Failed creating \(pfProducts.count) new products!", await shClient.createNewProductsWithStocks(stuff: pfProducts))
	}
}
