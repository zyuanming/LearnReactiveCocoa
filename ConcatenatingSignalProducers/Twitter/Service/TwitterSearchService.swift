//
//  TwitterSearchService.swift
//  ReactiveTwitterSearch
//
//  Created by Colin Eberhardt on 10/05/2015.
//  Copyright (c) 2015 Colin Eberhardt. All rights reserved.
//

import Foundation
import Accounts
import Social
import ReactiveCocoa
import ReactiveSwift

class TwitterSearchService {

    private let accountStore: ACAccountStore
    private let twitterAccountType: ACAccountType

    init() {
        accountStore = ACAccountStore()
        twitterAccountType = accountStore.accountType(withAccountTypeIdentifier: ACAccountTypeIdentifierTwitter)
    }

    func requestAccessToTwitterSignal() -> SignalProducer<Int, NSError> {
        return SignalProducer {
            (observer: Signal<Int, NSError>.Observer, _) in
            self.accountStore.requestAccessToAccounts(with: self.twitterAccountType, options: nil) {
                (granted, _) in
                if granted {
                    observer.sendCompleted()
                } else {
                    observer.send(error: TwitterInstantError.AccessDenied.toError())
                }
            }
        }
    }

    func signalForSearchWithText(text: String) -> SignalProducer<TwitterResponse, NSError> {

        func requestforSearchText(_ text: String) -> SLRequest {
            let url = URL(string: "https://api.twitter.com/1.1/search/tweets.json")
            let params = [
                "q" : text,
                "count": "100",
                "lang" : "en"
            ]
            return SLRequest(forServiceType: SLServiceTypeTwitter, requestMethod: .GET, url: url, parameters: params)
        }

        return SignalProducer { sink, disposable in
            let request = requestforSearchText(text)
            let maybeTwitterAccount = self.getTwitterAccount()

            if let twitterAccount = maybeTwitterAccount {
                request.account = twitterAccount
                print("performing request")
                request.perform { (data, response, _) in
                    print("response received")
                    if response != nil && response!.statusCode == 200 {
                        do {
                            let timelineData = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! NSDictionary
                            sink.send(value: TwitterResponse(tweetsDictionary: timelineData))
                            sink.sendCompleted()
                        } catch _ {
                            sink.send(error: TwitterInstantError.InvalidResponse.toError())
                        }
                    } else {
                        sink.send(error: TwitterInstantError.InvalidResponse.toError())
                    }
                }
            } else {
                sink.send(error: TwitterInstantError.NoTwitterAccounts.toError())
            }
        }
    }
    
    private func getTwitterAccount() -> ACAccount? {
        return self.accountStore.accounts(with: self.twitterAccountType).first as? ACAccount ?? nil
    }
}
