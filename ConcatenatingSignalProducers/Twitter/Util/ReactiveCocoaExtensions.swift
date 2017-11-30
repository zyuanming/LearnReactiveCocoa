//
//  ReactiveCocoaExtensions.swift
//  ReactiveTwitterSearch
//
//  Created by Colin Eberhardt on 12/05/2015.
//  Copyright (c) 2015 Colin Eberhardt. All rights reserved.
//

import Foundation
import ReactiveCocoa
import ReactiveSwift
import Result

/*
 extension RACSignal {
 func asSignal() -> Signal<AnyObject?, NSError> {
 return Signal {
 (observer: Observer<Value, Error>) in
 self.subscribeNext({
 (any: AnyObject!) -> Void in
 observer.sendNext(any)
 }, error: {
 error in
 observer.sendFailed(error)
 }, completed: {
 observer.sendCompleted()
 })
 }
 }
 }
 */

public func toVoidSignal<T, E>(signal: Signal<T, E>) -> Signal<(), NoError> {
    return Signal({ (observer, lifetime) in
        signal.observe({
            event in
            switch event {
            case .value(_):
                observer.send(value: ())
            default:
                break
            }
        })
    })
}
