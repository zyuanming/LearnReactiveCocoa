//
//  ViewController.swift
//  ConcatenatingSignalProducers
//
//  Created by Alex on 05/12/16.
//  www.jarroo.com
//

import UIKit
import ReactiveSwift
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

    override func viewDidLoad() {
        super.viewDidLoad()
        
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
//        SignalProducer
//            .flatten(.concat, producers: getAvatars)
//            .on(starting: {
//                print("starting")
//            }, started: {
//                print("started")
//            }, event: { event in
//                print("event is \(event)")
//            }, value: { image in
//                print("value is \(image)")
//            }, completed: {
//                print("completed")
//            },  disposed: {
//                print("disposed")
//            })
//            .startWithResult { result in
//                switch result {
//                case let .failure(error): print("An error occurred: \(error)")
//                case let .success(image): print("Successfully fetched image: \(image)")
//                }
//        }

        // Test strategy concate
        let test = TestConcate()
        test.testPropertyToSignalProducer()

        var a: TestSignalDeinit?
        a = TestSignalDeinit()
        a = nil
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
        let nextPageTrigger = MutableProperty()
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
