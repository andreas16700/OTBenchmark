//
//  File.swift
//  
//
//  Created by Andreas Loizides on 06/05/2023.
//

import Foundation

struct Stats {
	let median: UInt64
	let average: Double
	let stdDev: Double
	let min: UInt64
	let max: UInt64
	
	init?(from array: [UInt64]) {
		guard !array.isEmpty else { return nil }
		
		let sortedArray = array.sorted()
		
		// Calculate Median
		if sortedArray.count % 2 == 0 {
			median = (sortedArray[sortedArray.count / 2] + sortedArray[sortedArray.count / 2 - 1]) / 2
		} else {
			median = sortedArray[sortedArray.count / 2]
		}
		
		// Calculate Average
		let sum: UInt64 = sortedArray.reduce(0, +)
		average = Double(sum) / Double(sortedArray.count)
		
		// Calculate Standard Deviation
		let mean = average
		let variance = Double(sortedArray.map { pow(Double($0) - mean, 2) }.reduce(0, +)) / Double(sortedArray.count)
		stdDev = sqrt(variance)
		
		// Calculate Min and Max
		min = sortedArray.first!
		max = sortedArray.last!
	}
	var desc: String{
		return "avg=\(average) stdDev=\(stdDev) median=\(median) min=\(min) max=\(max)"
	}
}
