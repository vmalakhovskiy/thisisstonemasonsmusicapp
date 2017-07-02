//
//  Audio.swift
//  Auth
//
//  Created by Vitaliy Malakhovskiy on 6/29/17.
//
//

import Vapor
import FluentProvider
import Foundation

final class Audio: Model {
    let storage = Storage()

    static let nameKey = "name"
    var name: String

    static let systemNameKey = "systemName"
    var systemName: String

    let bandId: Identifier

    init(name: String, systemName: String, band: Band) throws {
        self.name = name
        self.bandId = try band.assertExists()
        self.systemName = systemName
    }

    init(row: Row) throws {
        name = try row.get(Audio.nameKey)
        systemName = try row.get(Audio.systemNameKey)
        bandId = try row.get(Band.foreignIdKey)
    }

    func makeRow() throws -> Row {
        var row = Row()
        try row.set(Audio.nameKey, name)
        try row.set(Band.foreignIdKey, bandId)
        try row.set(Audio.systemNameKey, systemName)
        return row
    }
}

extension Audio: Preparation {
    static func prepare(_ database: Database) throws {
        try database.create(self) { builder in
            builder.id()
            builder.string(Audio.nameKey)
            builder.string(Audio.systemNameKey)
            builder.foreignId(for: Band.self)
        }
    }

    /// Undoes what was done in `prepare`
    static func revert(_ database: Database) throws {
        try database.delete(self)
    }
}

extension Audio {
    /// Fluent relation for accessing the user
    var band: Parent<Audio, Band> {
        return parent(id: bandId)
    }
}

extension Audio {
    func audioUrl() throws -> URL {
        guard let band = try band.get() else {
            throw EntityError.noDatabase(Audio.self)
        }
        let imageDirUrl = URL(fileURLWithPath: workingDirectory())
            .appendingPathComponent("Public/Uploads/\(band.name)/Audio", isDirectory: true)
        return imageDirUrl.appendingPathComponent(systemName, isDirectory: false)
    }
}

extension Audio: JSONRepresentable {
    func makeJSON() throws -> JSON {
        var json = JSON()
        try json.set(Audio.idKey, id)
        try json.set(Audio.nameKey, name)
        return json
    }
}

extension Audio: ResponseRepresentable {}
