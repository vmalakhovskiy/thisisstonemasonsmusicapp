import Vapor
import AuthProvider
import Fluent
import Foundation
import Multipart
import FormData

extension Droplet {
    func setupRoutes() throws {
        try setupUnauthenticatedRoutes()
        try setupPasswordProtectedRoutes()
        try setupTokenProtectedRoutes()
    }

    private func setupUnauthenticatedRoutes() throws {
        resource("users", UserController(hash: hash))
    }

    private func setupPasswordProtectedRoutes() throws {
        let password = grouped([
            PasswordAuthenticationMiddleware(User.self)
        ])

        password.post("login") { req in
            let user = try req.user()
            let token = try Token.generate(for: user)
            try token.save()
            return token
        }
    }

    private func setupTokenProtectedRoutes() throws {
        let token = grouped([
            TokenAuthenticationMiddleware(User.self)
        ])

        token.get("me") { req in
            let user = try req.user()
            return JSON(
                [
                    "user" : try user.makeJSON(),
                    "bands" : try user.bands().all().makeJSON()
                ]
            )
        }

        token.get("bands", "all") { req in
            return try Band.makeQuery().all().makeJSON()
        }

        BandController().registerRoutes(with: token)
    }
}
