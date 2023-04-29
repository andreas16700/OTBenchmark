//
//  Extensions.swift
//  
//
//  Created by Andreas Loizides on 23/03/2023.
//

import Foundation
import ShopifyKit
extension Collection{
	@inlinable
	func toDictionaryArray<K: Hashable>(usingKP kp: KeyPath<Element,K>)-> [K:[Element]]{
		return reduce(into: [K:[Element]](minimumCapacity: count)){
			$0[$1[keyPath: kp], default: .init()].append($1)
		}
	}
	@inlinable
	func toDictionary<K: Hashable>(usingKP kp: KeyPath<Element,K>) -> [K:Element]{
		return reduce(into: [K:Element](minimumCapacity: count)){
			$0[$1[keyPath: kp]]=$1
		}
	}
}
extension SHProduct{
	func appropriateStocks(from: [Int: InventoryLevel])->[InventoryLevel]{
		return variants.compactMap(\.inventoryItemID).compactMap{invItemID in
			from[invItemID]
		}
	}
}
