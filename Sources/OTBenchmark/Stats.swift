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
	let p95: UInt64
	let p99: UInt64
	let p99_9: UInt64
	
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
		
		// Calculate Percentiles
		p95 = Self.percentile(sortedArray, percentile: 0.95)
		p99 = Self.percentile(sortedArray, percentile: 0.99)
		p99_9 = Self.percentile(sortedArray, percentile: 0.999)
	}
	static func percentile(_ sortedArray: [UInt64], percentile: Double) -> UInt64 {
		let index = Int(ceil(Double(sortedArray.count) * percentile)) - 1
		return sortedArray[index]
	}
	
	var desc: String {
		return "avg=\(average) stdDev=\(stdDev) median=\(median) p95=\(p95) p99=\(p99)"
	}
}

