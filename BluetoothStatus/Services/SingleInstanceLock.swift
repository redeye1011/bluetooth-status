import Darwin
import Foundation

@_silgen_name("flock")
private func flockFile(_ descriptor: Int32, _ operation: Int32) -> Int32

final class SingleInstanceLock {
    private let descriptor: Int32

    init?(url: URL) {
        let descriptor = Darwin.open(url.path, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { return nil }
        guard flockFile(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            Darwin.close(descriptor)
            return nil
        }
        self.descriptor = descriptor
    }

    deinit {
        Darwin.close(descriptor)
    }
}
