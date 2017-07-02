import Vapor
import HTTP

/// Here we have a controller that helps facilitate
/// RESTful interactions with our Users table
final class UserController: ResourceRepresentable {

    let hash: HashProtocol

    init(hash: HashProtocol) {
        self.hash = hash
    }

    /// When users call 'GET' on '/users'
    /// it should return an index of all available users
    func index(req: Request) throws -> ResponseRepresentable {
        return try User.all().makeJSON()
    }

    /// When consumers call 'POST' on '/users' with valid JSON
    /// create and save the user
    func create(request: Request) throws -> ResponseRepresentable {
        // require that the request body be json
        guard let json = request.json else {
            throw Abort(.badRequest)
        }

        // initialize the name and email from
        // the request json
        let user = try User(json: json)

        // ensure no us er with this email already exists
        guard try User.makeQuery().filter("email", user.email).first() == nil else {
            throw Abort(.badRequest, reason: "A user with that email already exists.")
        }

        // require a plaintext password is supplied
        guard let password = json["password"]?.string else {
            throw Abort(.badRequest)
        }
        // hash the password and set it on the user
        user.password = try self.hash.make(password.makeBytes()).makeString()

        // save and return the new user
        try user.save()
        return user
    }

    /// When the consumer calls 'GET' on a specific resource, ie:
    /// '/users/13rd88' we should show that specific user
    func show(req: Request, user: User) throws -> ResponseRepresentable {
        return user
    }

    /// When the consumer calls 'DELETE' on a specific resource, ie:
    /// 'users/l2jd9' we should remove that resource from the database
    func delete(req: Request, user: User) throws -> ResponseRepresentable {
        try user.delete()
        return Response(status: .ok)
    }

    /// When the consumer calls 'DELETE' on the entire table, ie:
    /// '/users' we should remove the entire table
    func clear(req: Request) throws -> ResponseRepresentable {
        try User.makeQuery().delete()
        return Response(status: .ok)
    }

    /// When the user calls 'PATCH' on a specific resource, we should
    /// update that resource to the new values.
    func update(req: Request, user: User) throws -> ResponseRepresentable {
        // See `extension User: Updateable`
        try user.update(for: req)

        // Save an return the updated user.
        try user.save()
        return user
    }

    /// When making a controller, it is pretty flexible in that it
    /// only expects closures, this is useful for advanced scenarios, but
    /// most of the time, it should look almost identical to this
    /// implementation
    func makeResource() -> Resource<User> {
        return Resource(
            index: index,
            store: create,
            show: show,
            update: update,
            destroy: delete,
            clear: clear
        )
    }
}
