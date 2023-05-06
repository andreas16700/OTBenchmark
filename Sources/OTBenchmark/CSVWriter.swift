//
//  CSVWriter.swift
//  
//
//  Created by Andreas Loizides on 01/05/2023.
//

import Foundation
let encoder = JSONEncoder()
extension Encodable{
	func write(fileURL: URL)throws{
		assert(type(of: self) != Data.self)
		let data = try encoder.encode(self)
		
		let strPath = fileURL.path()
		guard FileManager.default.fileExists(atPath: strPath) else {
			FileManager.default.createFile(atPath: strPath, contents: data)
			return
		}
		try data.write(to: fileURL)
	}
}
class CSVWriter{
	init?(name: String) {
		self.filename = "\(name).csv"
		let fileURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(self.filename)
		if !FileManager.default.fileExists(atPath: fileURL.path) {
					FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
				}
		do{
			let h = try FileHandle(forWritingTo: fileURL)
			self.handle=h
		}catch{
			print("Error opening file \(self.filename) for write: \(error.localizedDescription)")
			return nil
		}
	}
	deinit{
		try! handle.close()
		print("Closed the file at",filename)
	}
	
	let filename: String
	private var handle: FileHandle
	
	func writeCSVLine(values: [String]){
		let csvString = values.joined(separator: ",")+"\n"
		do {
			guard let data = csvString.data(using: .utf8) else {
				print("Did not save file! String \"",csvString, "\" could not be converted to utf8 data!")
				return
			}
			try handle.seekToEnd()
			try handle.write(contentsOf: data)
			try handle.synchronize()
			print("Successfully wrote to file")
		} catch {
			print("Error writing to \(filename): \(error.localizedDescription)")
		}
	}
}
