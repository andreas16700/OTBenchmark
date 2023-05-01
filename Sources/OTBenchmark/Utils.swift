import OTModelSyncer
import Foundation

//let workload: Workload = .readFromCommandLine()
func getEnvVar<T>(_ name: String, hint: String, transforming: (String)->T?)->T{
	guard let str = ProcessInfo.processInfo.environment[name] else {
		fatalError("Environment variable \(name) is not set! Hint: \(hint)")
	}
	guard let t = transforming(str) else{
		fatalError("Environment variable \(name) is not a valid \(T.self)! Hint: \(hint)")
	}
	return t
}
let urlTransformer: (String)->URL = {str in
	guard let url = URL(string: str) else {
		fatalError("\(str) is not a valid URL!")
	}
	return url
}

