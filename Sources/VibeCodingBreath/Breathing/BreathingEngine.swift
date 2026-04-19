import Foundation
import Observation

@MainActor
@Observable
final class BreathingEngine {
    private(set) var phase: BreathPhase = .exhale

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private(set) var isRunning: Bool = false
    @ObservationIgnored private(set) var taskSpawnCount: Int = 0

    init() {}

    func start() {
        guard !isRunning else { return }
        isRunning = true
        taskSpawnCount += 1
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                for p in BreathPhase.allCases {
                    if Task.isCancelled { return }
                    self.phase = p
                    do {
                        try await Task.sleep(for: .seconds(p.duration))
                    } catch {
                        return
                    }
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
    }
}
