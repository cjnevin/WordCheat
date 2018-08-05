import Foundation

typealias Debouncer = (@escaping () -> Void) -> Void

func createDebouncer(delay: TimeInterval = 0.15,
                     queue: DispatchQueue = .main) -> Debouncer {
    var lastCalled = DispatchTime(uptimeNanoseconds: 0)
    let delay = DispatchTimeInterval.milliseconds(Int(delay * 1000))
    
    return { action in
        let called = DispatchTime.now()
        lastCalled = called
        
        queue.asyncAfter(deadline: .now() + delay) {
            let executeAfter = lastCalled + delay
            if called >= lastCalled && DispatchTime.now() >= executeAfter {
                action()
            }
        }
    }
}
