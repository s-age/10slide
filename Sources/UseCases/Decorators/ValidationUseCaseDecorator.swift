final class ValidationAsyncUseCaseDecorator<
    Request: UseCaseRequest, Response, U: AsyncUseCase
>: AsyncUseCase, Sendable where U.Request == Request, U.Response == Response {
    private let decoratee: U

    init(decoratee: U) {
        self.decoratee = decoratee
    }

    func execute(_ request: Request) async throws -> Response {
        try request.validate()
        return try await decoratee.execute(request)
    }
}

final class ValidationSyncUseCaseDecorator<
    Request: UseCaseRequest, Response, U: SyncUseCase
>: SyncUseCase, Sendable where U.Request == Request, U.Response == Response {
    private let decoratee: U

    init(decoratee: U) {
        self.decoratee = decoratee
    }

    func execute(_ request: Request) throws -> Response {
        try request.validate()
        return try decoratee.execute(request)
    }
}
