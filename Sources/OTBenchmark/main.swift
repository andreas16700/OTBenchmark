import OTModelSyncer
import Foundation

let workload: Workload = .readFromCommandLine()
func getEnvVar<T>(_ name: String, hint: String, transforming: (String)->T?)->T{
	guard let str = ProcessInfo.processInfo.environment[name] else {
		fatalError("Environment variable \(name) is not set! Hint: \(hint)")
	}
	guard let t = transforming(str) else{
		fatalError("Environment variable \(name) is not a valid \(T.self)! Hint: \(hint)")
	}
	return t
}
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
