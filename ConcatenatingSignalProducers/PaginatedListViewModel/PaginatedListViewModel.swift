//
//  PaginatedListViewModel.swift
//  PaginatedListViewModel
//
//  Created by Sergey Gavrilyuk on 2016-03-17.
//  Copyright © 2016 Sergey Gavrilyuk. All rights reserved.
//
import Foundation
import ReactiveSwift
import Result

public class RecusrsivePageSignalPayload<T> {
    let page: [T]
    let nextPageSignal: SignalProducer<RecusrsivePageSignalPayload<T>, NSError>?

    public init(currentPage: [T], nextPageSignal: SignalProducer<RecusrsivePageSignalPayload<T>, NSError>?) {
        self.page = currentPage
        self.nextPageSignal = nextPageSignal
    }
}

public protocol PaginatedListViewModelDependency {
    associatedtype ListItemType
    func intialPageSignal() -> SignalProducer<RecusrsivePageSignalPayload<ListItemType>, NSError>
}

public class PaginatedListViewModel<T> {

    private let loadNextPageTrigger = Signal<(),NoError>.pipe()
    private let resetTrigger = Signal<(), NoError>.pipe()

    public let exhausted: Property<Bool>
    public let loading: Property<Bool>
    public let lastError: Property<NSError?>
    public let items: Property<[T]>

    public init<C: PaginatedListViewModelDependency>(dependency: C) where C.ListItemType == T {

        let __exhausted = MutableProperty(false)
        let __loading = MutableProperty(false)
        let __nextPage = MutableProperty<SignalProducer<RecusrsivePageSignalPayload<T>, NSError>?>(nil)

        let (lastErrorSignal, lastErrorSink) = Signal<NSError?, NoError>.pipe()

        let loadnextPageSignal = self.loadNextPageTrigger.0.producer
        let loadNextPageTrigger = SignalProducer.combineLatest(__exhausted.producer, __loading.producer)
            .map { !$0 && !$1 }
            .flatMap(.latest) {
                return $0 ? loadnextPageSignal : .never
        }

        let itemsSignal = self.resetTrigger.0.flatMap(.latest) {_ -> SignalProducer<[T], NoError> in
            __nextPage.value = dependency.intialPageSignal()
            __exhausted.value = false
            lastErrorSink.send(value: nil)

            let loadedPagesSignal = loadNextPageTrigger.flatMap(.merge) { _ -> SignalProducer<[T], NoError> in
                if let nextPageSignalProducer = __nextPage.value {
                    return nextPageSignalProducer
                        .observe(on: UIScheduler())
                        .on(started: { lastErrorSink.send(value: nil) }) //reset any error
                        .on(started: { __loading.value = true },
                            terminated: { __loading.value = false })
                        .redirectErrors(lastErrorSink)
                        .on { payload in
                            if let nextPage = payload.nextPageSignal {
                                __nextPage.value = nextPage
                            } else {
                                __nextPage.value = nil
                                __exhausted.value = true
                            }
                        }
                        .map { return $0.page }
                } else {
                    return .empty
                }
            }


            let pagesSignal = SignalProducer<[T], NoError>(value: []).concat(loadedPagesSignal)
            return pagesSignal.scan([], {( all, current) in
                return all + current
            })
        }

        self.lastError = Property(initial: nil, then: lastErrorSignal)
        self.exhausted = Property(__exhausted)
        self.loading = Property(__loading)
        self.items = Property(initial: [], then: itemsSignal)

        self.reset() // initialization state
    }

    public func loadNextPage() {
        self.loadNextPageTrigger.input.send(value: ())
    }

    public func reset() {
        self.resetTrigger.input.send(value: ())
    }

    public func reload() {
        self.reset()
        self.loadNextPage()
    }
}



