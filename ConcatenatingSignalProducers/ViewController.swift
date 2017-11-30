//
//  ViewController.swift
//  ConcatenatingSignalProducers
//
//  Created by Alex on 05/12/16.
//  www.jarroo.com
//

import UIKit
import ReactiveSwift
import ReactiveCocoa
import Result

extension SignalProducer {
    
    static func flatten(_ strategy: FlattenStrategy, producers:[SignalProducer<Value,Error>]) -> SignalProducer<Value,Error> {
        let p = SignalProducer<SignalProducer<Value,Error>,Error>(producers)
        return p.flatten(strategy)
    }
}

struct User {
    let name:String
    let avatarUrl:String
}

class APIClient {
    
    enum APIError : Error {
    }
    
    func getAvatar(url:String) -> SignalProducer<UIImage,APIError> {
//        return SignalProducer(value: #imageLiteral(resourceName: "trumpsticker"))
        return SignalProducer { observer, disposable in
            DispatchQueue.global().async {
                let data = try! Data(contentsOf: URL(string: url)!)
                let image = UIImage(data: data)
                observer.send(value: image!)
                observer.sendCompleted()
            }
        }
    }
}

class ViewController: UIViewController {

    let test = TestThen()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Test strategy concate
//        let test = TestConcate()
//        test.testPropertyToSignalProducer()
//
//        var a: TestSignalDeinit?
//        a = TestSignalDeinit()
//        a = nil
//
        test.test()
    }



}


class TestDownload {
    func test() {
        let client = APIClient()

        let users = [
            User(name: "User 1", avatarUrl: "https://ss1.bdstatic.com/70cFvXSh_Q1YnxGkpoWK1HF6hhy/it/u=1794894692,1423685501&fm=116&gp=0.jpg"),
            User(name: "User 2", avatarUrl: "https://ss3.bdstatic.com/70cFv8Sh_Q1YnxGkpoWK1HF6hhy/it/u=17572568,2472534097&fm=116&gp=0.jpg"),
            User(name: "User 3", avatarUrl: "https://ss3.bdstatic.com/70cFv8Sh_Q1YnxGkpoWK1HF6hhy/it/u=1303680113,133301350&fm=116&gp=0.jpg"),
            User(name: "User 4", avatarUrl: "https://ss1.bdstatic.com/70cFuXSh_Q1YnxGkpoWK1HF6hhy/it/u=1425317030,4113620941&fm=116&gp=0.jpg"),
            User(name: "User 5", avatarUrl: "https://ss0.bdstatic.com/70cFvHSh_Q1YnxGkpoWK1HF6hhy/it/u=1237679276,3516486176&fm=116&gp=0.jpg"),
            ]

        let getAvatars = users.map { client.getAvatar(url: $0.avatarUrl) }

        // Flatten strategy: concate, latest, merge
        SignalProducer
            .flatten(.concat, producers: getAvatars)
            .on(starting: {
                print("starting")
            }, started: {
                print("started")
            }, event: { event in
                print("event is \(event)")
            }, completed: {
                print("completed")
            }, disposed: {
                print("disposed")
            },  value: { image in
                print("value is \(image)")
            })
            .startWithResult { result in
                switch result {
                case let .failure(error): print("An error occurred: \(error)")
                case let .success(image): print("Successfully fetched image: \(image)")
                }
        }
    }
}



class TestConcate {

    deinit {
        print("TestConcate deinit")
    }

    func test() {
        // sets page to 1 at the beginning
        // searchImage(trigger: SignalProducer.empty).start()

        // increments page by nextPageTrigger
        let trigger = SignalProducer<(), NoError>(value: ())
        searchImage(trigger: trigger).start()
    }


    func testPropertyToSignalProducer() {
        let nextPageTrigger = MutableProperty(())
        var completedCalled = false
        searchImage(trigger: nextPageTrigger.producer.skip(first: 1)).on(completed: { completedCalled = true }).start()
//        nextPageTrigger.value = ()
//        nextPageTrigger.value = ()
        print("completedCalled flag is \(completedCalled)")
    }

    func searchImage(trigger: SignalProducer<(), NoError>) -> SignalProducer<String, NoError> {
        return SignalProducer { observer, disposable in
            let firstSearch = SignalProducer<(), NoError>(value: ())
            let load = firstSearch.concat(trigger)
            var parameter = 1

            load.on(value: {
                self.requestJSON(parameter: parameter).start({ event in
                    switch event {
                    case .value(let json):
                        observer.send(value: json)
                        observer.sendCompleted()
                        print(json)
                    case .failed(let error):
                        observer.send(error: error)
                        print(error)
                    case .completed:
                        print("completed")
                    case .interrupted:
                        observer.sendInterrupted()
                        print("interrupted")
                    }
                })
                parameter += 1
            }).start()
        }
    }


    func requestJSON(parameter: Int) -> SignalProducer<String, NoError> {
        return SignalProducer { observer, disposable in
            print("requestJSON parameter is \(parameter)")

            observer.send(value: "this is the json string")
            observer.sendCompleted()
        }
    }
}


class TestSignalDeinit {

    let signal: Signal<Int, NoError>
    let observer: Signal<Int, NoError>.Observer
    let testValue = 4

    init() {
        (signal, observer) = Signal<Int, NoError>.pipe()
        signal.observeValues { value in
            print(value + self.testValue)
        }
        observer.send(value: 2)

        // This is IMPORTANT!!! otherwise will cause memory leak
        observer.sendCompleted()
    }

    deinit {
        print("TestSignalDeinit deinit")
        // observer.sendCompleted() // *
    }
}




class TestSignalAndObserver {
    let active = MutableProperty(false)
    let refreshObserver: Signal<Void, NoError>.Observer
    let isLoading: MutableProperty<Bool>
    let contentChangesSignal: Signal<[Player], NoError>
    let contentChangesObserver: Signal<[Player], NoError>.Observer

    // Actions
    lazy var deleteAction: Action<IndexPath, Bool, AnyError> = { [unowned self] in
        return Action(execute: { indexPath in
            // delete, return true if success
            return SignalProducer(value: true)
        })
    }()

    class Player {

    }

    init() {

        let isLoading = MutableProperty(false)
        self.isLoading = isLoading
        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver

        let (contentChangesSignal, contentChangesObserver) = Signal<[Player], NoError>.pipe()
        self.contentChangesSignal = contentChangesSignal
        self.contentChangesObserver = contentChangesObserver

        // Trigger refresh when view becomes active
        active.producer
            .filter { $0 }
            .map { _ in () }
            .start(refreshObserver)

        // Trigger refresh after deleting a match
        deleteAction.values
            .filter { $0 }
            .map { _ in () }
            .observe(refreshObserver)

        self.isLoading.producer
            .observe(on: UIScheduler())
            .startWithValues({ isLoading in
                print("observer isLoading : \(isLoading)")
            })

        SignalProducer(refreshSignal)
            .on(starting: {
                self.isLoading.value = true
                print("isLoading")
            })
            .on(event: { event in
                switch event {
                case .completed:
                    print("event completed")
                case .value():
                    print("event value")
                case .failed(_):
                    print("event error")
                case .interrupted:
                    print("interrupted")
                }
            })
            .flatMap(.latest, { _ in
                return SignalProducer(value: [Player(), Player(), Player()])
            })
            .on(started: {
                self.isLoading.value = false
                print("isLoading completed")
            })
            .combinePrevious([])
            .startWithValues({ [weak self] (oldPlayers, newPlayers) in
                if let observer = self?.contentChangesObserver {
                    observer.send(value: newPlayers)
                }
            })




        self.contentChangesSignal
            .observe(on: UIScheduler())
            .observeValues({ players in
                print("new players count is \(players.count)")
            })


        // begin Test,
        self.refreshObserver.send(value: ())
        self.refreshObserver.send(value: ())
        self.refreshObserver.sendCompleted()

//        self.isLoading.value = false
//        self.isLoading.value = false
    }

    deinit {
        print("TestSignalAndObserver deinit")
    }
}



class TestSignalInput {
    func test() {
        let signal = Signal<(), NoError>.pipe()
        _ = signal.input
    }
}


/// combineLatest 如果是SignalProducer，那么会立刻回调observeValues；
/// 如果是 Signal，因为没有初始值，那么不会立刻回调，需要等待所有的signal 都产生数据才会
class TestCombineLatest {
    func test() {
        let a = MutableProperty<String>("")
        let b = MutableProperty<String>("")
        let c = MutableProperty<String>("")

        a.value = "helo"
        b.value = "hi"
        c.value = "e"

        Signal.combineLatest(a.signal, b.signal, c.signal)
            .observeValues { (aVal, bVal, cVal) in
                print("combined signal = \(aVal + bVal + cVal)")
        }

        SignalProducer.combineLatest(a.producer, b.producer, c.producer).startWithValues { (aVal, bVal, cVal) in
            print("combined producer = \(aVal + bVal + cVal)")
        }
    }
}


class TestThen {
    let a = MutableProperty<String>("")
    let c = MutableProperty<String>("c")
    func test() {
        let hasGetPlayersInfoSignal = a.producer
            .skip(first: 1)
            .map { $0.count > 0 }
            .flatMap(.latest, { _ in SignalProducer<(), NoError>.empty })

        hasGetPlayersInfoSignal.then(c.producer)
            .on(started: { [weak self] in
                guard let strongSelf = self else { return }

                DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: {
                    strongSelf.c.value = "cc"
                })

                print("hello...ming")
            })
            .startWithValues { (state) in
                print("state is \(state)")
        }

        a.value = "aa"
        c.value = "ccc"
    }
}





