/*

 HTTPPingApp.swift

 Author: Andrew Cowley

 */

import Foundation
import ArgumentParser
import Reachability
import SequenceStats

@main
struct HTTPPingApp: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: """
        
        This is a small command-line tool that “pings” an HTTP/HTTPS URL, analogous to the Unix ping command but using HTTP instead of ICMP.
        It:
        • Validates and normalizes a URL (auto-adds https:// if a valid http scheme is missing ).
        • Sends a lightweight HTTP request (prefer HEAD, switching to GET if HEAD isn’t supported).
        • Follows redirects while preserving the HTTP method.
        • Repeats the check a specified number of times (or continuously).
        • Prints succinct or verbose output and exits with a shell-friendly exit code.
        """,
        usage: """
            httpping URL [<options>]
            Example usage:
            httpping apple.co.uk --verbose -c 5
            """,
        discussion: """
            Displays a printed "success" or "fail" message, or a detailed reponse with the verbose option.
            The exit code of the program follows unix conventions, with 0 indicating success.
            """,
        aliases: ["web-ping", "httpping"]
    )

    @Flag(name: .shortAndLong, help: "Show the exact URL that responded and the time taken for the response")
    var verbose = false

    @Option(name: [.customShort("c"), .customLong("count")], help: "Number of times to repeat the check ( 0 for continuous, Ctrl-C to interrupt)")
    var repeatCount = 1

    @Option(name: [.customShort("i")], help: """
            -i wait
            Number of seconds between sending each request. Has no affect unless used with 
            the --count option The default is to wait for one second between requests.
            """)
            var wait: Double = 1.0

    @Option( name: .shortAndLong, help: "Number of bytes to ask for from the url **Only for a GET request**" )
    var bytes = 64
    @Option( name: .shortAndLong, help: "Timeout in seconds to wait for each reply" )
    var timeout: Double = 2.5

    @Argument(help: ArgumentHelp(
        "The url to be checked.",
        discussion: "If no url is provided, the tool will prompt you to enter one.",
        valueName: "url"))
    var urlStringArg: String = ""

    /// Place for any additional, UI facing, validation of the input.
    mutating func validate() async throws {
        guard repeatCount > 0 else { throw ValidationError("The repeat count should be a positrve number") }
        guard wait > 0 else { throw ValidationError("The wait time should be a positive number") }
        guard bytes > 0 else { throw ValidationError("The specified number of bytes to request should be a positive number. Default is 64.") }
    }

    /// run()
    /// Description: Check if the supplied urlstring is reachable over HTTP, mimicing the unix 'ping' command for web addresses
    ///
    /// it first sets up a trap for Ctrl-C interrupts, and exits gracefully if encounted.
    /// the checkReachable() function does the heavy lifting, while this function controls looping and display of messages.
    mutating func run() async throws {
        // Attempt to interrupt the program if CTRL-C detected
        let dispatchSourceSignal = handleInterrupt() // need to maintain the reference to the dispatchSourceSignal to keep it alive
        defer { dispatchSourceSignal.cancel() }

        let reachability = await Reachability() //declaration here, instead of within the `run` function, as that apparently requires Decodability

        var urlString: String // Separate string from input so that the program will continue to prompt for input from stdin until empty
        var counter = repeatCount
        var successCount: Int = 0
        var timings: [Double] = []
        repeat {
            // Read stdin if no urlstring provided
            if urlStringArg.isEmpty {
//                print("Hello, What url would you like to test? (press enter to exit)")
                urlString = try getInput()
            } else { urlString = urlStringArg }
            guard !urlString.isEmpty else { throw ExitCode.success }
            let result = await reachability.checkReachable(urlString, verbose: verbose, bytes: bytes, timeout: timeout)
            if result.reachable {
                successCount += 1
                let urlfinal = (result.finalURL ?? "unknown").components( separatedBy: "?").first!.components(separatedBy: "#").first!
                if verbose {
                    print("\(result.size) bytes from \(urlfinal) http_seq=\(repeatCount+1-counter) type=\(result.httpMethod) time=\(result.responseTime!.decimalString) ms")
                } else {
                    print("Response received from \(urlfinal) in \(result.responseTime!.decimalString) ms")
                }
            } else {
                print(result)
            }
            if let responseTime = result.responseTime {
                timings.append(responseTime)
            }

            counter -= 1

            /// Sleep between each attempt except the last
            if counter != 0 {
                try await Task.sleep(for: .seconds(wait))
            }
        } while counter != 0

        if repeatCount > 1 {
            /// print summary
            let summaryStats = timings.stats
            let min = summaryStats.min!.decimalString
            let avg = summaryStats.mean.decimalString
            let max = summaryStats.max!.decimalString
            let stddev = summaryStats.standardDeviation.decimalString
            print("\n--- \(urlString) httpping statistics ---")
            print("\(repeatCount) requests sent, with \(successCount) successful. min/avg/max/stddev = \(min)/\(avg)/\(max)/\(stddev) ms")
        }

        throw successCount > 0 ? ExitCode.success : ExitCode.failure
    }


    /// Handle SIGINT (Ctrl-C) gracefully inside async main
    func handleInterrupt() -> DispatchSourceSignal {

        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        source.setEventHandler {
            print("\nProgram interrupted. Exiting.")
            Foundation._exit(SIGINT)
        }
        source.resume()
        return source // return the source to the callsite so it can be kept alive.

        //Alternate C based handler
        //        signal(SIGINT, SIG_IGN)
        //
        //        let signalCallback: sig_t = { signal in
        //            print("\nProgram interrupted. Exiting.")
        //            Foundation._exit(signal)
        //        }
        //        signal(SIGINT, signalCallback)

    }

    func getInput() throws -> String {
        guard let input = readLine(strippingNewline: true)?.trimmingCharacters(in: .whitespaces), !input.isEmpty
        else {
            throw CleanExit.message("No input received. Exiting.")
        }
        return input
    }
}



