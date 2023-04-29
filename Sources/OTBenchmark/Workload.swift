//
//  File.swift
//  
//
//  Created by Andreas Loizides on 22/03/2023.
//

import Foundation
import OTModelSyncer

public struct Workload{
	let totalModelCount: Int
	let xSeed: UInt64
	let ySeed: UInt64
	
	static func readFromCommandLine()-> Self{
		func failAndPrintUsage(_ withMessage: String)->Never{
			print("Usage:")
			print("./otBench numOfModels")
			print("./otBench numOfModels xSeed ySeed")
			print("Where numOfModels is the number of models to be generated"
			," and xSeed, ySeed unsigned 64bit numbers to use for the pseudo-random number generator (PRNG). "
			,"If no seeds are provided, the default will be used:"
			,"\n ./otBench \(defaultXseed) \(defaultYseed)")
			fatalError(withMessage)
		}

		let defaultXseed:UInt64 = 3199077918806463242
		let defaultYseed:UInt64 = 11403738689752549865
		let argumentCount = CommandLine.arguments.count
		guard argumentCount > 1 else{failAndPrintUsage("No arguments given!")}
		let numOfModelsStr = CommandLine.arguments[1]
		guard let numOfModels = Int(numOfModelsStr) else {failAndPrintUsage("\(numOfModelsStr) is not a number!")}
		guard argumentCount == 2 || argumentCount == 4 else {failAndPrintUsage("Unexpected number of arguments given!")}
		
		if argumentCount == 4{
			guard let xSeed = UInt64(CommandLine.arguments[2])
					, let ySeed = UInt64(CommandLine.arguments[3]) else{
				failAndPrintUsage("Seeds given are not numbers!")
			}
			return .init(totalModelCount: numOfModels, xSeed: xSeed, ySeed: ySeed)
		}
		return .init(totalModelCount: numOfModels, xSeed: defaultXseed, ySeed: defaultYseed)
	}
}
