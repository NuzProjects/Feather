import Foundation
import Combine
final class GitHubSources: ObservableObject {
    static let shared = GitHubSources()
    @Published private(set) var repositories: [GitHubRepository] = []
    private init() { reload() }
    func reload() {
        repositories = (UserDefaults.standard.data(forKey: "GitHub.sources").flatMap { try? JSONDecoder().decode([GitHubRepository].self, from: $0) }) ?? []
    }
    func add(_ repository: GitHubRepository) {
        guard !repositories.contains(where: { $0.slug.lowercased() == repository.slug.lowercased() }) else { return }
        repositories.append(repository); save()
    }
    func remove(_ repository: GitHubRepository) { repositories.removeAll { $0 == repository }; save() }
    private func save() {
        if let data = try? JSONEncoder().encode(repositories) { UserDefaults.standard.set(data, forKey: "GitHub.sources") }
    }
}
