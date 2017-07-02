import Vapor
import HTTP
import Fluent
import Foundation
import Multipart

/// Here we have a controller that helps facilitate
/// RESTful interactions with our Users table
final class BandController {

    func registerRoutes(with routeBuilder: RouteBuilder) {
        routeBuilder.get("bands", handler: get)
        routeBuilder.post("bands", handler: create)
        routeBuilder.get("bands", Int.parameter, handler: getConcrete)
        routeBuilder.delete("bands", handler: delete)

        let bandToken = routeBuilder.grouped([BandMiddleware()])
        let bandAndUserToken = bandToken.grouped([UserMiddleware()])

        bandAndUserToken.post("bands", Int.parameter, "user", Int.parameter, handler: connect)
        bandAndUserToken.delete("bands", Int.parameter, "user", Int.parameter, handler: disconnect)

        bandToken.post("bands", Int.parameter, "upload", handler: upload)
        bandToken.get("bands", Int.parameter, "audio", Int.parameter, handler: getAudio)
        bandToken.delete("bands", Int.parameter, "audio", Int.parameter, handler: deleteAudio)
    }

    func get(request: Request) throws -> ResponseRepresentable {
        let user = try request.user()
        let bands = try user.bands().all()
        return try bands.makeJSON()
    }

    /// When consumers call 'POST' on '/users' with valid JSON
    /// create and save the user
    func create(request: Request) throws -> ResponseRepresentable {
        guard let json = request.json else {
            throw Abort(.badRequest)
        }

        let user = try request.user()

        let band = try Band(json: json)

        guard try Band.makeQuery().filter("name", band.name).first() == nil else {
            throw Abort(.badRequest, reason: "A band with that name already exists.")
        }

        try band.save()

        let pivot = try Pivot<User, Band>(user, band)
        try pivot.save()

        return band
    }

    func getConcrete(request: Request) throws -> ResponseRepresentable {
        return try request.band()
    }

    /// When the consumer calls 'DELETE' on a specific resource, ie:
    /// 'users/l2jd9' we should remove that resource from the database
    func delete(request: Request) throws -> ResponseRepresentable {
        try request.band().delete()
        return JSON([:])
    }

    /// When the user calls 'PATCH' on a specific resource, we should
    /// update that resource to the new values.
    func update(request: Request) throws -> ResponseRepresentable {
        let band = try request.band()
        try band.update(for: request)

        // Save an return the updated user.
        try band.save()
        return band
    }

    func connect(request: Request) throws -> ResponseRepresentable {
        let passedUser = try request.passedUser()
        let band = try request.band()

        guard try passedUser.bands().makeQuery().filter(Band.idKey, band.id).first() == nil else {
            throw Abort(.badRequest, reason: "User already in that band")
        }

        let pivot = try Pivot<User, Band>(passedUser, band)
        try pivot.save()

        return band
    }

    func disconnect(request: Request) throws -> ResponseRepresentable {
        let passedUser = try request.passedUser()
        let band = try request.band()

        guard try passedUser.bands().makeQuery().filter(Band.idKey, band.id).first() != nil else {
            throw Abort(.badRequest, reason: "User is not in that band")
        }

        try Pivot<User, Band>.makeQuery()
            .filter(UserBand.userIdKey, passedUser.id)
            .filter(UserBand.bandIdKey, band.id)
            .delete()

        return band
    }

    func upload(request: Request) throws -> ResponseRepresentable {
        guard
            let field = request.formData?["audio"],
            let filename = request.formData?["name"]?.string,
            !field.part.body.isEmpty
            else {
                throw Abort(.badRequest, reason: "No file in request")
        }

        let bytes = field.part.body
        let band = try request.band()

        let fileManager = FileManager.default
        let imageDirUrl = URL(fileURLWithPath: workingDirectory())
            .appendingPathComponent("Public/Uploads/\(band.name)/Audio", isDirectory: true)
        try fileManager.createDirectory(at: imageDirUrl, withIntermediateDirectories: true, attributes: nil)
        let systemName = UUID().uuidString + ".m4a"
        let saveURL = imageDirUrl.appendingPathComponent(systemName, isDirectory: false)

        do {
            let data = Data(bytes: bytes)
            try data.write(to: saveURL)
        } catch {
            throw Abort(.internalServerError, reason:  "Unable to write multipart form data to file. Underlying error \(error)")
        }

        let audio = try Audio(name: filename, systemName: systemName, band: band)
        try audio.save()

        return audio
    }

    func getAudio(request: Request) throws -> ResponseRepresentable {
        let band = try request.band()

        guard let audioId = request.parameters[Int.uniqueSlug]?.array?.last?.int else {
            throw Abort.badRequest
        }

        guard let audio = try band.audios().makeQuery().filter(Audio.idKey, audioId).first() else {
            throw Abort(.badRequest, reason: "No audios found with that id")
        }

        let url = try audio.audioUrl()
        let file = try Data(contentsOf: url)

        let response = Response(status: .ok)
        response.multipart = [
            Part(headers: [:], body: try audio.makeJSON().makeBody().bytes!),
            Part(headers: [HeaderKey.contentType: "audio/x-m4a"], body: file.makeBytes())
        ]
        return response
    }

    func deleteAudio(request: Request) throws -> ResponseRepresentable {
        let band = try request.band()

        guard let audioId = request.parameters[Int.uniqueSlug]?.array?.last?.int else {
            throw Abort.badRequest
        }

        guard let audio = try band.audios().makeQuery().filter(Audio.idKey, audioId).first() else {
            throw Abort(.badRequest, reason: "No audios found with that id")
        }

        let url = try audio.audioUrl()
        try audio.delete()
        try FileManager.default.removeItem(at: url)

        return JSON([:])
    }
}

public final class BandMiddleware: Middleware {
    public func respond(to req: Request, chainingTo next: Responder) throws -> Response {
        guard let bandId = req.parameters[Int.uniqueSlug]?.int ?? req.parameters[Int.uniqueSlug]?.array?.first?.int else {
            throw Abort.badRequest
        }

        guard let band = try Band.makeQuery().filter(Band.idKey, bandId).first() else {
            throw Abort(.badRequest, reason: "No bands found with that id")
        }

        req.storage["band"] = band
        return try next.respond(to: req)
    }
}

public final class UserMiddleware: Middleware {
    public func respond(to req: Request, chainingTo next: Responder) throws -> Response {
        guard let userId = req.parameters[Int.uniqueSlug]?.array?.last?.int else {
            throw Abort.badRequest
        }

        guard let user = try User.makeQuery().filter(User.idKey, userId).first() else {
            throw Abort(.badRequest, reason: "No user found with that id")
        }

        req.storage["passed_user"] = user
        return try next.respond(to: req)
    }
}

extension Request {
    func band() throws -> Band {
        guard let band = storage["band"] as? Band else {
            throw EntityError.doesntExist(Band.self)
        }
        return band
    }

    func passedUser() throws -> User {
        guard let user = storage["passed_user"] as? User else {
            throw EntityError.doesntExist(User.self)
        }
        return user
    }
}
