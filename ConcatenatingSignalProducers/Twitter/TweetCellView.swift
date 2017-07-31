//
//  TweetCell.swift
//  ReactiveTwitterSearch
//
//  Created by Colin Eberhardt on 11/05/2015.
//  Copyright (c) 2015 Colin Eberhardt. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import Result

class TweetCellView: UITableViewCell, ReactiveView {

    @IBOutlet weak var usernameText: UILabel!
    @IBOutlet weak var statusText: UILabel!
    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var ageText: UILabel!

    lazy var scheduler: QueueScheduler = {
        let queue = DispatchQueue.global(qos: .background)
//        return QueueScheduler(queue: queue)
        return QueueScheduler(qos: .background, name: "hello", targeting: queue)
    }()

    func bindViewModel(_ viewModel: AnyObject) {
        if let tweetViewModel = viewModel as? TweetViewModel {

            //FIXME: how to lift this to signal producer for takeUntil?
            //      _ = toVoidSignal(self.rac_prepareForReuseSignal.asSignal())


            statusText.rac_text <~ tweetViewModel.status

            usernameText.rac_text <~ tweetViewModel.username.producer.map { "@\($0)" }

            // because the ageInSeconds property is mutable, we need to ensure that we 'complete'
            // the signal that the rac_text property is bound to. Hence the use of takeUntil.
            ageText.rac_text <~ tweetViewModel.ageInSeconds.producer
                .map { "\($0) secs" }
            //          .takeUntil(triggerSignal)


            avatarImageView.image = nil
            avatarImageSignalProducer(tweetViewModel.profileImageUrl.value)
                .start(on: scheduler)
                //        .takeUntil(triggerSignal)
                .observe(on: QueueScheduler.main)
                .startWithValues {
                    self.avatarImageView.image = $0
            }
        }
    }

    private func avatarImageSignalProducer(_ imageUrl: String) -> SignalProducer<UIImage?, NoError> {
        guard let url = URL(string: imageUrl),
            let data = try? Data(contentsOf: url) else {
            print("App Transport Security rejected URL: \(imageUrl)")
            return SignalProducer(value: nil)
        }
        return SignalProducer(value: UIImage(data: data))
    }
}
