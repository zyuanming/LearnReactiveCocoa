//
//  TwitterSearchViewModel.swift
//  ReactiveTwitterSearch
//
//  Created by Colin Eberhardt on 10/05/2015.
//  Copyright (c) 2015 Colin Eberhardt. All rights reserved.
//

import Foundation
import CoreGraphics
import ReactiveCocoa
import ReactiveSwift

class TwitterSearchViewModel {

    struct Constants {
        static let SearchCharacterMinimum: Int = 3
        static let SearchThrottleTime: TimeInterval = 1.0
        static let TickIntervalLength: TimeInterval = 1.0
        static let DisabledTableAlpha: CGFloat = 0.5
        static let EnabledTableAlpha: CGFloat = 1.0
    }

    let searchText = MutableProperty<String>("")
    let queryExecutionTime = MutableProperty<String>("")
    let isSearching = MutableProperty<Bool>(false)
    let tweets = MutableProperty<[TweetViewModel]>([TweetViewModel]())
    let loadingAlpha = MutableProperty<CGFloat>(Constants.DisabledTableAlpha)

    private let searchService: TwitterSearchService

    init(searchService: TwitterSearchService) {

        self.searchService = searchService

        searchService.requestAccessToTwitterSignal()
            .then(searchText.producer.mapError({ _ in TwitterInstantError.NoError.toError() })
                .filter {
                    $0.characters.count > Constants.SearchCharacterMinimum
                }
                .throttle(Constants.SearchThrottleTime, on: QueueScheduler.main)
                .on(starting: {
                    _ in self.isSearching.value = true
                })
                .flatMap(.latest) { text in
                    self.searchService.signalForSearchWithText(text: text)
            })
            .on(failed: { error in
                print(error)
            })
            .observe(on: QueueScheduler.main)
            .startWithResult { (result) in
                self.isSearching.value = false

                switch result {
                case let .success(response):
                    self.queryExecutionTime.value = "Execution time: \(response.responseTime)"
                    self.tweets.value = (response.tweets.map { TweetViewModel(tweet: $0) })
                case .failure(_): break
                }

        }

        SignalProducer.timer(interval: .seconds(Int(Constants.TickIntervalLength)), on: QueueScheduler.main)
            .startWithValues { [weak self] _ in
            self?.tweets.value.forEach { $0.updateTime() }
        }

        loadingAlpha <~ isSearching.producer.map(enabledAlpha)
    }

    private func enabledAlpha(searching: Bool) -> CGFloat {
        return searching ? Constants.DisabledTableAlpha : Constants.EnabledTableAlpha
    }
}
