import Foundation

import SwiftSignalKit


public func fetchHttpResource(url: String) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    if let url = URL(string: url) {
        let signal = MTHttpRequestOperation.data(forHttpUrl: url)!
        return Signal { subscriber in
            subscriber.putNext(.reset)
            let disposable = signal.start(next: { next in
                if let response = next as? MTHttpResponse {
                    let fetchResult: MediaResourceDataFetchResult = .dataPart(resourceOffset: 0, data: response.data, range: 0 ..< response.data.count, complete: true)
                    subscriber.putNext(fetchResult)
                    subscriber.putCompletion()
                } else {
                    subscriber.putError(.generic)
                }
            }, error: { _ in
                subscriber.putError(.generic)
            }, completed: {
            })
            
            return ActionDisposable {
                disposable?.dispose()
            }
        }
    } else {
        return .never()
    }
}
