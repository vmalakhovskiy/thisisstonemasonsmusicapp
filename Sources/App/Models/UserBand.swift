//
//  Bands.swift
//  Auth
//
//  Created by Vitaliy Malakhovskiy on 6/26/17.
//
//

import Vapor
import FluentProvider

final class UserBand: Model {
    let storage = Storage()

    static let userIdKey = "user_id"
    var userId: Identifier

    static let bandIdKey = "band_id"
    var bandId: Identifier

    init(userId: Identifier, bandId: Identifier) {
        self.userId = userId
        self.bandId = bandId
    }

    init(row: Row) throws {
        userId = try row.get(UserBand.userIdKey)
        bandId = try row.get(UserBand.bandIdKey)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(UserBand.userIdKey, userId)
        try row.set(UserBand.bandIdKey, bandId)
        return row
    }
}

extension UserBand: Preparation {
    /// Prepares a table/collection in the database
    /// for storing Users
    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.int(UserBand.userIdKey)
            builder.int(UserBand.bandIdKey)
        }
    }

    /// Undoes what was done in `prepare`
    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}
