//
//  File.swift
//  
//
//  Created by Andreas Loizides on 22/03/2023.
//

import Foundation
import OTModelSyncer
import ArgumentParser


struct Workload{
	var totalModelCount: Int
	let xSeed: UInt64
	let ySeed: UInt64
}
enum RunnerType: String, CaseIterable, ExpressibleByArgument{
	case mono, serverless
	
	static var allValueStrings: [String] {allCases.map(\.rawValue)}
	
	static var defaultCompletionKind: CompletionKind = .list(allValueStrings)
}
@main
struct Benchmark: AsyncParsableCommand{
//	public init(){
//
//	}
	
	
	@Argument(help: "The number of models to generate on the PS Server. Each model contains multiple items (ranging from 1 to 25).")
	var totalModelCount: Int
	
	@Option(name: .shortAndLong, help: "The increments to run the benchmark (if the multiple flag is specified)")
	var increments: Int = 500
	
	@Option(name: .long, help: "The starting value of the model count to run the benchmark (if the multiple flag is specified)")
	var minModelCount: Int = 100
	
	@Flag(name: .shortAndLong, help: "If true, will run the benchmark multiple times, for model count starting from \"minModelCount\" (minModelCount option) , with increments of \"increments\" (increments option) up to \"totalModelCount\" (the main argument)")
	var multiple: Bool = false
	
	@Flag(name: .shortAndLong, help: "Only setup the servers")
	var onlySetupServers: Bool = false
	
	@Option(name: .shortAndLong, help: "A 64bit unsigned integer used as a seed for generating the workload")
	var xSeed: UInt64 = 3199077918806463242
	
	@Option(name: .shortAndLong, help: "A 64bit unsigned integer used as a seed for generating the workload")
	var ySeed: UInt64 = 11403738689752549865
	
	@Argument(help: "URL of the PS (powersoft) Server", transform: urlTransformer)
	var psURL: URL
	
	@Argument(help: "URL of the SH (shopify) Server", transform: urlTransformer)
	var shURL: URL
		
	@Option(name: .shortAndLong, help: "The type of runners to use.", completion: .default)
	var runnerTypes: [RunnerType] = [.mono, .serverless]
	
	
	
	func parseRunners()->[WorkloadRunner]{
		return runnerTypes.map{
			switch $0{
			case .mono:
				return MonolithicRunner(psURL: psURL, shURL: shURL)
			case .serverless:
				return ServerlessRunner(psURL: psURL, shURL: shURL)
			}
		}
	}
	func initializeCSV(name: String)->CSVWriter{
		guard let writer = CSVWriter(name: name) else {fatalError("Error creating/opening file to write benchmark results to!")}
		let names = runnerTypes.map(\.rawValue)
		let headerValues = ["Models Count"] + names.map{"seconds(\($0))"} + names.map{"attoseconds(\($0))"} + names.map{"successes(\($0))"} + names.map{"fails(\($0))"}
		print("Writing header",headerValues.joined(separator: ","))
		writer.writeCSVLine(values: headerValues)
		return writer
	}
	func addResults(writer: CSVWriter, modelsCount: Int, times: [Duration], succ: [Int], fail: [Int]){
		let values = ["\(modelsCount)"] + times.map({"\($0.components.seconds)"}) + times.map({"\($0.components.attoseconds)"}) + succ.map{String($0)} + fail.map{String($0)}
		writer.writeCSVLine(values: values)
	}
	static func runOnce(workload: Workload, runner: WorkloadRunner)async throws -> (String, Duration, Int, Int){
		let name = type(of: runner).name
		print("Setting up servers for ",name)
		await runner.setUpServers(for: workload)
		print("Retrieving source data...")
		let source = await runner.getSourceData()
		print("Running..")
		var (successes, fails) = (0,0)
		let duration = try await SuspendingClock().measure {
			(successes, fails) = try await runner.runSync(sourceData: source)
		}
		print("\(name) took \(duration). Had \(fails) fails and \(successes) successes.")
		
		print("Resetting servers' state..")
		let _ = await runner.psClient.reset()
		let _ = await runner.shClient.reset()
		print("Reset both servers.")
		
		return (name, duration, successes, fails)
	}
	func runMultiple()async throws{
		guard minModelCount < totalModelCount else{
			fatalError("minModelCount must be less than totalModelCount! (\(minModelCount)<\(totalModelCount)")
		}
		guard increments>0 else {fatalError("Increments must be a positive integer! (not \(increments)")}
		print("Will benchmark generating from \(minModelCount) models up to \(totalModelCount) in increments of \(increments), using seed (\(xSeed),\(ySeed))")
		let g = stride(from: minModelCount, to: totalModelCount, by: increments)
		var workload = Workload(totalModelCount: 0, xSeed: xSeed, ySeed: ySeed)
		let runners = parseRunners()
		var times: [Duration] = .init()
		var successes: [Int] = .init()
		var fails: [Int] = .init()
		times.reserveCapacity(runners.count)
		successes.reserveCapacity(runners.count)
		fails.reserveCapacity(runners.count)
		let resultsFileName = "bench_\(workload.totalModelCount)_\(runners.map{type(of: $0).name}.joined(separator: ","))_\(workload.xSeed)_\(workload.ySeed)"
		let writer = initializeCSV(name: resultsFileName)
		for modelsCount in g{
			workload.totalModelCount = modelsCount
			times.removeAll(keepingCapacity: true)
			successes.removeAll(keepingCapacity: true)
			fails.removeAll(keepingCapacity: true)
			for runner in runners {
				let (name, time, succ, fail) = try await Self.runOnce(workload: workload, runner: runner)
				print(name,"took \(time)")
				times.append(time)
				successes.append(succ)
				fails.append(fail)
			}
			addResults(writer: writer, modelsCount: modelsCount, times: times, succ: successes, fail: fails)
		}
	}
	public func run() async throws {

//		let o = MonolithicRunner(psURL: psURL, shURL: shURL)
//		let modelCode = "model149"
//		let source = await o.getSourceData()
//		let model = source.psModelsByModelCode[modelCode]!
//		let psStock = source.psStocksByModelCode[modelCode]!
//		let shProd = source.shProdsByHandle[model.randomElement()!.getShHandle()]!
//		let invIDs = shProd.variants.map(\.inventoryItemID).compactMap{$0!}
//		let shStock = invIDs.map{source.shStocksByInvID[$0]!}
//		let input = SyncModelInput(clientsInfo: .init(psURL: psURL, shURL: shURL), modelCode: modelCode, model: model, psStocks: psStock, product: shProd, shInv: shStock)
//		let response = await syncModel(input: input)
//		guard let sync = response.1 else{
//			for (k,v) in response.0{
//				print(k,"\(v)")
//			}
//			return
//		}
//		print(sync.metadata)
//		print("Done")
		
//		let inp = SyncModelInput(clientsInfo: .init(psURL: psURL, shURL: shURL), modelCode: "model8", model: nil, psStocks: nil, product: nil, shInv: nil)
//		print(String(data: (try! JSONEncoder().encode(inp)), encoding: .utf8)!)
		
		
		guard !onlySetupServers else{
			let m = MonolithicRunner(psURL: psURL, shURL: shURL)
			await m.setUpServers(for: .init(totalModelCount: totalModelCount, xSeed: xSeed, ySeed: ySeed))
			return
		}
		guard !multiple else {try await runMultiple(); return}
		print("Will benchmark generating \(totalModelCount) models using seed (\(xSeed),\(ySeed))")
		let runners = parseRunners()
		let wl = Workload(totalModelCount: totalModelCount, xSeed: xSeed, ySeed: ySeed)
		for runner in runners {
			_ = try await Self.runOnce(workload: wl, runner: runner)
		}
	}
}
