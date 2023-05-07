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
import RateLimitingCommunicator

struct MonolithicRunner: WorkloadRunner{
	
	static let name: String = "Monolithic"
	var psClient: MockPsClient
	var shClient: MockShClient
	let rl: RLCommunicator?
	init(psURL: URL, shURL: URL, msDelay: Int?) {
		self.psClient = MockPsClient(baseURL: psURL)
		self.shClient = MockShClient(baseURL: shURL)
		if let msDelay{
			self.rl = RLCommunicator(minDelay: .milliseconds(msDelay))
		}else{
			self.rl = nil
		}
		
	}
	func runSync(sourceData source: SourceData) async throws -> (Int,Int,[UInt64]){
		print("[I] Starting syncers... [M]")
		let g = await withTaskGroup(of: (SingleModelSync?, UInt64).self, returning: (Int, Int, [UInt64]).self){group in
			for (modelCode, model) in source.psModelsByModelCode{
				let refItem = model.first!
				let stocks = source.psStocksByModelCode[modelCode] ?? []
				
				let product = source.shProdsByHandle[refItem.getShHandle()]
				let shStocks = product?.appropriateStocks(from: source.shStocksByInvID)
				let shData = product == nil ? nil : (product!,shStocks!)
				let syncer = SingleModelSyncer(modelCode: modelCode, ps: psClient, sh: shClient, psDataToUse: (model,stocks), shDataToUse: shData, saveMethod: nil)
				group.addTask{
					if let rl{
						let result = try! await rl.sendRequest{
							let (nanos, s) = await measureInNanos{
								await syncer.sync(savePeriodically: false)
							}
							if s == nil{
								print("[I] Failed for \(modelCode) [M]")
							}
							return (s,nanos)
						}
						return result
					}else{
						let (nanos, s) = await measureInNanos{
							await syncer.sync(savePeriodically: false)
						}
						if s == nil{
							print("[I] Failed for \(modelCode) [M]")
						}
						return (s,nanos)
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
			return (successes,fails,durations)
		}
		return g
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
