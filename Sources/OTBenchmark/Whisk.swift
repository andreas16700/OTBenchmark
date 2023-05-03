/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import NIO
import NIOHTTP1
import NIOHTTP2
import NIOSSL
import Foundation
import AsyncHTTPClient
import NIOFoundationCompat

extension Encodable{
	func asJsonDict(encoder: JSONEncoder)throws -> [String: Any]?{
		let d = try encoder.encode(self)
		let o = try JSONSerialization.jsonObject(with: d) as? [String: Any]
		return o
	}
}
class Client {
	private let group: MultiThreadedEventLoopGroup
	let client: HTTPClient
	static let shared = Client()
	static let TIMEOUT: TimeAmount = .hours(2)
	static let CON_CONN_L = 500_000_000
	let tlsConfig: TLSConfiguration
	let headers: HTTPHeaders
	private init() {
		let numberOfThreads = System.coreCount
		self.group = MultiThreadedEventLoopGroup(numberOfThreads: numberOfThreads)
		var tlsConfig = TLSConfiguration.makeClientConfiguration()
		tlsConfig.certificateVerification = .none
		self.tlsConfig = tlsConfig
		let co: HTTPClient.Configuration = .init(tlsConfiguration: tlsConfig, timeout: .init(connect: Self.TIMEOUT, read: Self.TIMEOUT), connectionPool: .init(idleTimeout: Self.TIMEOUT, concurrentHTTP1ConnectionsPerHostSoftLimit: Self.CON_CONN_L), ignoreUncleanSSLShutdown: true)
		self.client = HTTPClient(eventLoopGroupProvider: .shared(self.group), configuration: co)
		var headers: HTTPHeaders = .init()
		let auth = ProcessInfo.processInfo.environment["__OW_API_KEY"]!
		let loginData: Data = auth.data(using: String.Encoding.utf8, allowLossyConversion: false)!
		let base64EncodedAuthKey  = loginData.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
		headers.add(name: "Authorization", value: "Basic \(base64EncodedAuthKey)")
		headers.add(name: "Content-Type", value: "application/json")
		self.headers = headers
	}
	func sendRequest(url: URL, method: HTTPMethod = .GET, body: HTTPClient.Body? = nil)async throws -> Data?{
		var h = headers
		if body == nil{
			//no body -> no json!
			h.remove(name: "Content-Type")
		}
		let r: HTTPClient.Request = try! .init(url: url, method: method, headers: h, body: body, tlsConfiguration: tlsConfig)
		let response = try await client.execute(request: r).get()
		guard let buffer = response.body else {
			print("Empty response for \(url): status: \(response.status)")
			return nil
		}
		return .init(buffer: buffer)
	}
	deinit {
		try! self.client.syncShutdown()
		try! self.group.syncShutdownGracefully()
	}

//	func sendRequests(url: String) async throws{
//		let g = try await client.
//		guard var buffer = try await client.get(url: url).get().body else {return}
//		let str = buffer.getString(at: 0, length: buffer.readableBytes)
//
//		guard let d = buffer.getData(at: 0, length: buffer.readableBytes, byteTransferStrategy: .automatic) else {return}
//		//let str = String(data: d, encoding: .utf8)
//
////		guard let data = buffer.readData(length: buffer.readableBytes) else {return}
//////		let data = Data(buffer: g)
////		let str = String(data: data, encoding: .utf8)
////		let f = String(buffer: s)
//		print(str ?? "empty!")
//	}
}
class Whisk {

	static var baseUrl = ProcessInfo.processInfo.environment["__OW_API_HOST"]
	static var apiKey = ProcessInfo.processInfo.environment["__OW_API_KEY"]
	// This will allow user to modify the default JSONDecoder and JSONEncoder used by epilogue
	static var jsonDecoder = JSONDecoder()
	static var jsonEncoder = JSONEncoder()
	class func invoke<T: Codable, T2: Codable>(actionNamed action : String, withParameters params : T?, blocking: Bool = true, expect: T2.Type) async -> ([String:Any], T2?){
		let o = await invoke(actionNamed: action, withParameters: params, blocking: blocking)
		guard let r = o["response"] as? [String: Any] else {
			return (["error":"no response! Got: \(o)"],nil)
		}
		
		guard let result = r["result"] as? [String: Any] else{
			return (["error":"no result! Got: \(o)"], nil)
		}
		do{
			let data = try JSONSerialization.data(withJSONObject: result)
			let decoded = try Self.jsonDecoder.decode(T2.self, from: data)
			return (o, decoded)
		}catch{
			let e = "Error decoding as \(T2.self)! Got \(error.localizedDescription). Result dict: \(result)"
			print(e)
			return (["error":e], nil)
		}
	}
	class func invoke<T: Codable>(actionNamed action : String, withParameters params : T?, blocking: Bool = true) async -> [String:Any] {
		let parsedAction = parseQualifiedName(name: action)
		let strBlocking = blocking ? "true" : "false"
		let path = "/api/v1/namespaces/\(parsedAction.namespace)/actions/\(parsedAction.name)?blocking=\(strBlocking)"
		guard let params else{
			return await sendWhiskRequest(uriPath: path, params: nil, method: .POST)
		}
		do{
			guard let o = try params.asJsonDict(encoder: Self.jsonEncoder)else{
				return ["error":"can't parse as [String: Any]! (is a json object but not a dictionary!)"]
			}
			return await sendWhiskRequest(uriPath: path, params: o, method: .POST)
		}catch{
			return ["error":"can't parse as [String: Any]! \(error.localizedDescription)"]
		}
		
	}
	
	class func invoke(actionNamed action : String, withParameters params : [String:Any]?, blocking: Bool = true) async -> [String:Any] {
		let parsedAction = parseQualifiedName(name: action)
		let strBlocking = blocking ? "true" : "false"
		let path = "/api/v1/namespaces/\(parsedAction.namespace)/actions/\(parsedAction.name)?blocking=\(strBlocking)"

		return await sendWhiskRequest(uriPath: path, params: params, method: .POST)
	}

	class func trigger(eventNamed event : String, withParameters params : [String:Any]) async -> [String:Any] {
		let parsedEvent = parseQualifiedName(name: event)
		let path = "/api/v1/namespaces/\(parsedEvent.namespace)/triggers/\(parsedEvent.name)?blocking=true"

		return await sendWhiskRequest(uriPath: path, params: params, method: .POST)
	}

	class func createTrigger(triggerNamed trigger: String, withParameters params : [String:Any]) async -> [String:Any] {
		let parsedTrigger = parseQualifiedName(name: trigger)
		let path = "/api/v1/namespaces/\(parsedTrigger.namespace)/triggers/\(parsedTrigger.name)"
		return await sendWhiskRequest(uriPath: path, params: params, method: .PUT)
	}

	class func createRule(ruleNamed ruleName: String, withTrigger triggerName: String, andAction actionName: String) async -> [String:Any] {
		let parsedRule = parseQualifiedName(name: ruleName)
		let path = "/api/v1/namespaces/\(parsedRule.namespace)/rules/\(parsedRule.name)"
		let params = ["trigger":triggerName, "action":actionName]
		return await sendWhiskRequest(uriPath: path, params: params, method: .PUT)
	}
	private class func sendWhiskRequest(uriPath: String, params : [String:Any]?, method: HTTPMethod) async -> [String:Any]{
		guard let encodedPath = uriPath.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) else {
			return ["error": "Error encoding uri path to make openwhisk REST call."]
		}

		let urlStr = "\(baseUrl!)\(encodedPath)"

		guard let url = URL(string: urlStr) else {
			return ["error": "Error constructing url with \(urlStr)"]
		}

		do {
			var body: HTTPClient.Body? = nil
			if let params{
				let data = try JSONSerialization.data(withJSONObject: params)
				body = .byteBuffer(.init(data: data))
			}

			
			guard let data = try await Client.shared.sendRequest(url: url, method: method, body: body) else {
				return ["error":"empty response!"]
			}
			do {
				//let outputStr  = String(data: data, encoding: String.Encoding.utf8) as String!
				//print(outputStr)
				let respJson = try JSONSerialization.jsonObject(with: data)
				if respJson is [String:Any] {
					return respJson as! [String:Any]
				} else {
					return ["error":" response from server is not a dictionary"]
				}
			} catch {
				if let str = String(data: data, encoding: .utf8){
					print("String response: ",str)
				}
				return ["error":"Error creating json from response: \(error)"]
			}
		} catch {
			return ["error":"Got error creating params body: \(error)"]
		}
	}


	// separate an OpenWhisk qualified name (e.g. "/whisk.system/samples/date")
	// into namespace and name components
	private class func parseQualifiedName(name qualifiedName : String) -> (namespace : String, name : String) {
		let defaultNamespace = "_"
		let delimiter = "/"

		let segments :[String] = qualifiedName.components(separatedBy: delimiter)

		if segments.count > 2 {
			return (segments[1], Array(segments[2..<segments.count]).joined(separator: delimiter))
		} else if segments.count == 2 {
			// case "/action" or "package/action"
			let name = qualifiedName.hasPrefix(delimiter) ? segments[1] : segments.joined(separator: delimiter)
			return (defaultNamespace, name)
		} else {
			return (defaultNamespace, segments[0])
		}
	}

}
