final class Container {
    let infrastructure: InfrastructureContainer
    let repositories: RepositoryContainer
    let useCases: UseCaseContainer
    let presentation: PresentationContainer

    init() throws {
        infrastructure = try InfrastructureContainer()
        repositories = RepositoryContainer(infrastructure: infrastructure)
        useCases = UseCaseContainer(repositories: repositories)
        presentation = PresentationContainer(useCases: useCases)
    }
}
