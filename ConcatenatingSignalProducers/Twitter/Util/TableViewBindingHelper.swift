//
//  TableViewBindingHelper.swift
//  ReactiveSwiftFlickrSearch
//
//  Created by Colin Eberhardt on 15/07/2014.
//  Copyright (c) 2014 Colin Eberhardt. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import Result

protocol ReactiveView {
    func bindViewModel(_ viewModel: AnyObject)
}

// a helper that makes it easier to bind to UITableView instances
// see: http://www.scottlogic.com/blog/2014/05/11/reactivecocoa-tableview-binding.html
class TableViewBindingHelper<T: AnyObject> : NSObject {

    //MARK: Properties

    var delegate: UITableViewDelegate?

    private let tableView: UITableView
    private let templateCell: UITableViewCell
    private let dataSource: DataSource

    //MARK: Public API

    init(tableView: UITableView, sourceSignal: SignalProducer<[T], NoError>, nibName: String) {
        self.tableView = tableView

        let nib = UINib(nibName: nibName, bundle: nil)

        // create an instance of the template cell and register with the table view
        templateCell = nib.instantiate(withOwner: nil, options: nil)[0] as! UITableViewCell
        tableView.register(nib, forCellReuseIdentifier: templateCell.reuseIdentifier!)

        dataSource = DataSource(data: nil, templateCell: templateCell)

        super.init()

        sourceSignal.startWithValues { [weak self] data in
            self?.dataSource.data = data.map({ $0 as AnyObject })
            self?.tableView.reloadData()
        }

        self.tableView.dataSource = dataSource
        self.tableView.delegate = dataSource

        self.tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 100.0
    }
}

class DataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    private let templateCell: UITableViewCell
    var data: [AnyObject]?

    init(data: [AnyObject]?, templateCell: UITableViewCell) {
        self.data = data
        self.templateCell = templateCell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: templateCell.reuseIdentifier!),
            let item = data?.safeIndex(indexPath.row),
            let reactiveView = cell as? ReactiveView else {
                return UITableViewCell()
        }

        reactiveView.bindViewModel(item)
        return cell
    }
}
