//
//  File.swift
//  
//
//  Created by Andreas Loizides on 02/05/2023.
//

import Foundation

func getSource()async{
	let name = "GetSourceData"
	let s = await Whisk.invoke(actionNamed: name, withParameters: nil, blocking: true)
	for (k,v) in s{
		print(s,"\(v)")
	}
}
func syncModel()async{
	let name = "syncModel"
	let s = await Whisk.invoke(actionNamed: name, withParameters: nil, blocking: true)
	for (k,v) in s{
		print(s,"\(v)")
	}
}
