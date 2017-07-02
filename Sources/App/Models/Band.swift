//
//  Band.swift
//  Auth
//
//  Created by Vitaliy Malakhovskiy on 6/26/17.
//
//

import Vapor
import FluentProvider

final class Band: Model {
    let storage = Storage()

    static let nameKey = "name"
    var name: String

    static let audiosKey = "audios"

    init(name: String) {
        self.name = name
    }

    init(row: Row) throws {
        name = try row.get(Band.nameKey)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Band.nameKey, name)
        return row
    }
}

extension Band {
    func users() -> Siblings<Band, User, UserBand> {
        return siblings()
    }

    func audios() -> Children<Band, Audio> {
        return children()
    }
}

extension Band: Preparation {
    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(Band.nameKey)
        }
    }

    /// Undoes what was done in `prepare`
    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}

extension Band: JSONConvertible {
    convenience init(json: JSON) throws {
        try self.init(
            name: json.get(Band.nameKey)
        )
        id = try json.get(Band.idKey)
    }

    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Band.idKey, id)
        try json.set(Band.nameKey, name)
        try json.set(Band.audiosKey, audios().all().makeJSON())
        return json
    }
}

extension Band: ResponseRepresentable {}

extension Band: Updateable {
    public static var updateableKeys: [UpdateableKey<Band>] {
        return [
            UpdateableKey(Band.nameKey, String.self) { band, name in
                band.name = name
            }
        ]
    }
}
