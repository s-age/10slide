final class Container {
    let infrastructure: InfrastructureContainer
    let repositories: RepositoryContainer
    let domain: DomainContainer
    let useCases: UseCaseContainer
    let presentation: PresentationContainer

    init() throws {
        infrastructure = try InfrastructureContainer()
        repositories = RepositoryContainer(infrastructure: infrastructure)
        domain = DomainContainer(repositories: repositories)
        useCases = UseCaseContainer(domain: domain)
        presentation = PresentationContainer(useCases: useCases)
    }
}
