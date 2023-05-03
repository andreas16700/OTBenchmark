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
	init(psURL: URL, shURL: URL)
	static var name: String					{get}
	var psClient: MockPsClient				{get}
	var shClient: MockShClient				{get}
	func runSync(sourceData: SourceData) async throws -> (Int,Int)
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
	func setUpServers(for workload: Workload)async{
		var gen: RandomNumberGenerator = Xorshift128Plus(xSeed: workload.xSeed, ySeed: workload.ySeed)
		let psClient = self.psClient
		let shClient = self.shClient
		print("Making sure both servers are reset first..")
		let _ = await psClient.reset()
		let _ = await shClient.reset()
		let modelCount = workload.totalModelCount
		
		await succeeds("Could not intialize ps server!", await psClient.generateModels(modelCount: modelCount, xSeed: workload.xSeed, ySeed: workload.ySeed))
		
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
		print("Converting \(fNum) models into fully synced products")
		let fModels = allModels[pNum...]
		let fProducts = fModels.map{modelAndStocks in
			let product = try! modelAndStocks.model.getAsNewProduct()
			return ProductAndItsStocks(product: product, stocksBySKU: modelAndStocks.stocks)
		}
		
		let pfProducts = pProducts + fProducts
		print("Uploading \(pfProducts.count) products and their stocks to the SH server")
		await succeeds("Failed creating \(pfProducts.count) new products!", await shClient.createNewProductsWithStocks(stuff: pfProducts))
		printRandomModel(from: allModels[0..<pNum])
		printRandomModel(from: allModels[0..<pNum])
			}
}
func printRandomModel<T: Collection>(from: T) where T.Element == ModelAndItsStocks{
	let randomPmodel = from.randomElement()!.model
	print("model \(randomPmodel.randomElement()!.modelCode365) is partially synced (items \(randomPmodel.map(\.itemCode365).joined(separator: ",")))")
}
