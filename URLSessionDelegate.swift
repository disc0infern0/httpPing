//
//  RedirectPreservingDelegate.swift
//  httpPing
//
//  Created by Andrew on 07/10/2025.
//



import Foundation
extension Reachability  {
    // Follows HTTP redirects while preserving the original HTTP method (e.g., HEAD or GET)
    final class RedirectPreservingDelegate: NSObject, URLSessionTaskDelegate {
        private let originalMethod: String
        private let maxRedirects: Int
        private var redirectCounts: [Int: Int] = [:]

        init(originalMethod: String, maxRedirects: Int = 10) {
            self.originalMethod = originalMethod
            self.maxRedirects = maxRedirects
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            let current = redirectCounts[task.taskIdentifier, default: 0]
            guard current < maxRedirects else {
                // Stop following redirects after hitting the limit
                completionHandler(nil)
                return
            }
            redirectCounts[task.taskIdentifier] = current + 1

            var req = request
            // Ensure we keep using the original method across redirects (e.g., stay on HEAD)
            req.httpMethod = originalMethod
            //            print("redirected to \(req.url?.absoluteString ?? "n/a")")
            completionHandler(req)
        }
    }

}
