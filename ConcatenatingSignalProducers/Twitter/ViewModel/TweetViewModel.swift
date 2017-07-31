//
//  TweetViewModel.swift
//  ReactiveTwitterSearch
//
//  Created by Colin Eberhardt on 11/05/2015.
//  Copyright (c) 2015 Colin Eberhardt. All rights reserved.
//

import Foundation
import ReactiveCocoa
import ReactiveSwift

class TweetViewModel: NSObject {
    let status: Property<String>
    let username: Property<String>
    let profileImageUrl: Property<String>
    lazy var ageInSeconds: MutableProperty<Int> = {
        return MutableProperty(self.computeAge())
    }()

    private let tweet: Tweet

    init (tweet: Tweet) {
        self.tweet = tweet

        status = Property(value: tweet.username)
        username = Property(value: tweet.username)
        profileImageUrl = Property(value: tweet.profileImageUrl)
    }

    private func computeAge() -> Int {
        return Int(NSDate().timeIntervalSince(tweet.timestamp))
    }

    func updateTime() {
        ageInSeconds.value = computeAge()
    }
}
