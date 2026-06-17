import Foundation

final class Spinner: @unchecked Sendable {
    private let frames  = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private let message: String
    private var frameIndex = 0
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "dev.resource.spinner")
    private let lock  = NSLock()

    init(_ message: String) {
        self.message = message
    }

    func start() {
        guard Terminal.isInteractive else {
            print("\(message)...")
            return
        }
        Cursor.hide()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: .milliseconds(80))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let frame = Color.green.apply(self.frames[self.frameIndex])
            self.frameIndex = (self.frameIndex + 1) % self.frames.count
            self.lock.unlock()
            print("\r  \(frame)  \(self.message)", terminator: "")
            fflush(stdout)
        }
        t.resume()
        timer = t
    }

    func stop(success: Bool = true, label: String? = nil) {
        timer?.cancel()
        timer = nil
        let mark = success ? Color.green.apply("✓") : Color.red.apply("✗")
        let text = label ?? message
        print("\r  \(mark)  \(text)                                        ")
        Cursor.show()
    }
}
