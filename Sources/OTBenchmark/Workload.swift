//
//  File.swift
//  
//
//  Created by Andreas Loizides on 22/03/2023.
//

import Foundation
import OTModelSyncer
import ArgumentParser

@main
struct Workload: AsyncParsableCommand{
//	public init(){
//
//	}
	@Argument(help: "The number of models to generate on the PS Server. Each model contains multiple items (ranging from 1 to 25).")
	var totalModelCount: Int
	
	@Option(name: .shortAndLong, help: "A 64bit unsigned integer used as a seed for generating the workload")
	var xSeed: UInt64 = 3199077918806463242
	
	@Option(name: .shortAndLong, help: "A 64bit unsigned integer used as a seed for generating the workload")
	var ySeed: UInt64 = 11403738689752549865
	
	public func run() async throws {
		let workload = self
		print("Will benchmark generating \(workload.totalModelCount) models using seed (\(workload.xSeed),\(workload.ySeed))")

		let urlMaker = {URL(string: $0)}
		let psURL = getEnvVar("PSURL", hint: "url of a powersoft server", transforming: urlMaker)
		let shURL = getEnvVar("SHURL", hint: "url of a powersoft server", transforming: urlMaker)
		enum RunnerType: String, CaseIterable{
			case mono, serverless
		}
		let type:RunnerType = getEnvVar("OTTYPE", hint: "options: \(RunnerType.allCases.map(\.rawValue).joined(separator: ", "))", transforming: {.init(rawValue: $0)})

		let runner: WorkloadRunner

		switch type{
		case .mono:
			runner = MonolithicRunner(using: workload, psURL: psURL, shURL: shURL)
		case .serverless:
			fatalError("unimplemented!")
		}
		print("Setting up the servers...")
		await runner.setUpServers()
		print("Running...")

		let duration = try await SuspendingClock().measure {
			try await runner.run()
		}
		print("\(type.rawValue) took \(duration)")

		let _ = await runner.psClient.reset()
		let _ = await runner.shClient.reset()
	}
	
//	static func readFromCommandLine()-> Self{
//		func failAndPrintUsage(_ withMessage: String)->Never{
//			print("Usage:")
//			print("./otBench numOfModels")
//			print("./otBench numOfModels xSeed ySeed")
//			print("Where numOfModels is the number of models to be generated"
//			," and xSeed, ySeed unsigned 64bit numbers to use for the pseudo-random number generator (PRNG). "
//			,"If no seeds are provided, the default will be used:"
//			,"\n ./otBench \(defaultXseed) \(defaultYseed)")
//			fatalError(withMessage)
//		}
//
//		let defaultXseed:UInt64 = 3199077918806463242
//		let defaultYseed:UInt64 = 11403738689752549865
//		let argumentCount = CommandLine.arguments.count
//		guard argumentCount > 1 else{failAndPrintUsage("No arguments given!")}
//		let numOfModelsStr = CommandLine.arguments[1]
//		guard let numOfModels = Int(numOfModelsStr) else {failAndPrintUsage("\(numOfModelsStr) is not a number!")}
//		guard argumentCount == 2 || argumentCount == 4 else {failAndPrintUsage("Unexpected number of arguments given!")}
//
//		if argumentCount == 4{
//			guard let xSeed = UInt64(CommandLine.arguments[2])
//					, let ySeed = UInt64(CommandLine.arguments[3]) else{
//				failAndPrintUsage("Seeds given are not numbers!")
//			}
//			return .init(totalModelCount: numOfModels, xSeed: xSeed, ySeed: ySeed)
//		}
//		return .init(totalModelCount: numOfModels, xSeed: defaultXseed, ySeed: defaultYseed)
//	}
}
