//
//  PaginatedListViewModelTests.swift
//  PaginatedListViewModelTests
//
//  Created by Sergii Gavryliuk on 2016-03-17.
//  Copyright © 2016 Sergey Gavrilyuk. All rights reserved.
//
import XCTest
import ReactiveSwift

typealias TestSignalPayload = RecusrsivePageSignalPayload<String>
typealias TestSignal = Signal<TestSignalPayload, NSError>
typealias TestSignalProducer = SignalProducer<TestSignalPayload, NSError>
typealias TestSink = Signal<TestSignalPayload, NSError>.Observer

enum PageSignalResolveType {
    case Success
    case Fail(NSError)
}

class PaginatedListViewModelTests: XCTestCase {


    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func generatePageSignals(_ pages: [[String]]) -> (TestSignalProducer, (_ resolveType: PageSignalResolveType) -> Void ) {
        guard pages.count > 0 else {
            fatalError("Cannot create sequence of 0 signals")
        }

        var localPages = pages

        var sendNextStack: [(_ resolveType: PageSignalResolveType) -> ()] = []

        func sendNext(resolveType: PageSignalResolveType) {
            sendNextStack.popLast()?(resolveType)
        }

        let lastPage = localPages.popLast()!
        var runningPageProducer = TestSignalProducer() {
            sink, _ in
            let(lastPageSignal, lastPageSink) = TestSignal.pipe()
            lastPageSignal.observe(sink)

            sendNextStack.append({ (resolveType: PageSignalResolveType) in
                switch resolveType {
                case .Success:
                    lastPageSink.send(value: TestSignalPayload(currentPage:lastPage , nextPageSignal: nil))
                    lastPageSink.sendCompleted()
                case .Fail(let error):
                    lastPageSink.send(error: error)
                }
            })
        }

        while let page = localPages.popLast() {

            let scopedPageProducer = runningPageProducer
            runningPageProducer = TestSignalProducer() {
                sink, disposables in
                let (prevPageSignal, prevSink) = TestSignal.pipe()
                prevPageSignal.observe(sink)
                sendNextStack.append({ (resolveType: PageSignalResolveType) in
                    switch resolveType {
                    case .Success:
                        prevSink.send(value: TestSignalPayload(currentPage: page, nextPageSignal: scopedPageProducer))
                        prevSink.sendCompleted()
                    case .Fail(let error):
                        prevSink.send(error: error)
                    }
                })
            }
        }

        return (runningPageProducer, sendNext)
    }

    func testInitialLoadingProperty() {

        let (producer, _) = generatePageSignals([[""]])

        let dep = DynamicPaginatedListViewModelDep(firstPageSignal: producer)
        let viewModel = PaginatedListViewModel(dependency: dep)


        XCTAssertEqual(viewModel.loading.value, false, "loading should be false before initial `loadNextPage` called")
        viewModel.loadNextPage()

        XCTAssertEqual(viewModel.loading.value, true, "loading should be true when `loadNextPage` called")
    }

    func testLoadingProperty() {

        let (firstPageSignal, deliverNextPage) = generatePageSignals([["1"], ["2"]])

        let dep = DynamicPaginatedListViewModelDep(firstPageSignal: firstPageSignal)

        let viewModel = PaginatedListViewModel(dependency: dep)
        viewModel.loadNextPage()

        deliverNextPage(.Success)

        XCTAssertEqual(viewModel.loading.value, false, "loading should be false after signall page signal completed with result")

        viewModel.loadNextPage()

        XCTAssertEqual(viewModel.loading.value, true, "loading should be true when `loadNextPage` called")

        deliverNextPage(.Success)

        XCTAssertEqual(viewModel.loading.value, false, "loading should be false after signall page signal completed with result")

    }

    func testExchaustedProperty() {

        let (firstPageSignal, deliverNextPage) = generatePageSignals([["1"], ["2"]])

        let dep = DynamicPaginatedListViewModelDep(firstPageSignal: firstPageSignal)

        let viewModel = PaginatedListViewModel(dependency: dep)

        XCTAssertEqual(viewModel.exhausted.value, false, "exhausted should be false initially")

        viewModel.loadNextPage()

        XCTAssertEqual(viewModel.exhausted.value, false, "exhausted should be false until page loaded")

        deliverNextPage(.Success)

        XCTAssertEqual(viewModel.exhausted.value, false, "exhausted should be false since next page available")

        viewModel.loadNextPage()

        XCTAssertEqual(viewModel.exhausted.value, false, "exhausted should be false until page is loaded")

        deliverNextPage(.Success)

        XCTAssertEqual(viewModel.exhausted.value, true, "exhausted should be true since no next page available")

        viewModel.reset()

        XCTAssertEqual(viewModel.exhausted.value, false, "exhausted should be false after reset()")
    }

    func testLastError() {

        let (firstPageSignal, deliverNextPage) = generatePageSignals([["1"], ["2"], ["3"]])

        let dep = DynamicPaginatedListViewModelDep(firstPageSignal: firstPageSignal)

        let viewModel = PaginatedListViewModel(dependency: dep)

        XCTAssertEqual(viewModel.lastError.value, nil, "lastError should be nil initially")

        viewModel.loadNextPage()

        XCTAssertEqual(viewModel.lastError.value, nil, "lastError should be nil before page is delivered")

        deliverNextPage(.Success)

        XCTAssertEqual(viewModel.lastError.value, nil, "lastError should be nil since page was delivered successfully")

        viewModel.loadNextPage()

        let error = NSError(domain: "SampleDomain", code: 0, userInfo: nil)
        deliverNextPage(.Fail(error))

        XCTAssertEqual(viewModel.lastError.value, error, "lastError should be equal to error delivered by pageSignal")

        viewModel.loadNextPage()

        XCTAssertEqual(viewModel.lastError.value, nil, "lastError should be reset to nil when new `loadNextPage` called")

        deliverNextPage(.Success)

        XCTAssertEqual(viewModel.lastError.value, nil, "lastError should be nil when new page delivered successfully")

        viewModel.loadNextPage()
        deliverNextPage(.Fail(error))

        XCTAssertEqual(viewModel.lastError.value, error, "lastError should be equal to error delivered by pageSignal")

        viewModel.reset()

        XCTAssertEqual(viewModel.lastError.value, nil, "lastError should be nil after `reset`")

    }


    func testPagesConsistency() {

        let (firstPageSignal, deliverNextPage) = generatePageSignals([["1", "2"], ["3", "4"]])

        let dep = DynamicPaginatedListViewModelDep(firstPageSignal: firstPageSignal)

        let viewModel = PaginatedListViewModel(dependency: dep)


        XCTAssertEqual(viewModel.items.value, [], "item should be empty initially")

        viewModel.loadNextPage()

        deliverNextPage(.Success)

        XCTAssertEqual(viewModel.items.value, ["1", "2"], "item should match first page")

        viewModel.loadNextPage()
        deliverNextPage(.Success)

        XCTAssertEqual(viewModel.items.value, ["1", "2", "3", "4"], "item should match first + second page")

        viewModel.reset()

        XCTAssertEqual(viewModel.items.value, [], "item should empty after `reset`")

    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}

struct DynamicPaginatedListViewModelDep: PaginatedListViewModelDependency {
    typealias ListItemType = String
    let firstPageSignal: SignalProducer<RecusrsivePageSignalPayload<String>, NSError>

    func intialPageSignal() -> SignalProducer<RecusrsivePageSignalPayload<String>, NSError> {
        return self.firstPageSignal
    }

    init(firstPageSignal: SignalProducer<RecusrsivePageSignalPayload<String>, NSError>) {
        self.firstPageSignal = firstPageSignal
    }
}

struct SamplePaginatedListViewModelDependency: PaginatedListViewModelDependency {
    typealias ListItemType = String

    func intialPageSignal() -> SignalProducer<RecusrsivePageSignalPayload<ListItemType>, NSError> {

        let count = 10

        func makeNextPageSignal(_ skip: Int) -> SignalProducer<RecusrsivePageSignalPayload<ListItemType>, NSError> {
            return SignalProducer() {
                sink, _ in
                // make page a list of Ints turned into String
                let page = (skip...(skip + count)).map{ "\($0)"}

                let payload = RecusrsivePageSignalPayload(
                    currentPage: page,
                    nextPageSignal: makeNextPageSignal(skip + count)
                )

                sink.send(value: payload)
                sink.sendCompleted()
            }
        }

        return makeNextPageSignal(0)
    }
}




