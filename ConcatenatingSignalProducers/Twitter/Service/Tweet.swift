//
//  Tweet.swift
//  ReactiveTwitterSearch
//
//  Created by Colin Eberhardt on 12/05/2015.
//  Copyright (c) 2015 Colin Eberhardt. All rights reserved.
//

import Foundation

struct Tweet {
    let profileImageUrl: String
    let username: String
    let status: String
    let timestamp: Date

    init(json: NSDictionary) {
        timestamp = Static.formatter.date(from: json["created_at"] as! String)!
        status = json["text"] as! String
        let user = json["user"] as! NSDictionary
        profileImageUrl = user["profile_image_url"] as! String
        username = user["screen_name"] as! String
    }
}

struct Static {
    static let formatter : DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d HH:mm:ss Z y"
        return formatter
    }()
}


