//
//  TestModel.swift
//  3332323
//
//  Created by dd on 25/7/2021.
//

import Foundation

struct mediaResTagModel: Codable {
    let id: Int
    let plate: Int
    let tag_name: String?
    let tag_color: String?
    let status: Int
    let remark: String?
    let operator_str: String?   //operator
    let created_at: String?
    let updated_at: String?

}


struct mediaResCateModel: Codable {
    let id: Int
    let category: String?
}


struct mediaResModel: Codable {
    
    var id: Int = 0
    var title: String!
    var details: String!
    var obj_type: Int = 0
    var top: Int = 0
    var avatar_url: String!
    var video_duration: Int = 0
    var user_id: Int = 0
    var user_name: String!
    var city: String!
    var essay_content: String!
    var created_at: String!
    var updated_at: String!
    var likecount: Int = 0
    var commentcount: Int = 0
    var sharecount: Int = 0
    var collectcount: Int = 0
    var Category: [mediaResCateModel]!
    var images: [String]
    var videos: [String]
    var islike: Bool = false
    var iscollect: Bool = false
    var isshare: Bool = false
    var iscomment: Bool = false
    var created_at_str: String!
    var h5_url: String!
}



struct TestModel: Codable {
    var page: Int
    var pageSize: Int
    var totalRecord: Int
    var list: [mediaResModel]
}
