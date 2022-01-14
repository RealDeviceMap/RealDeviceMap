import Foundation
import PerfectThread

public class TimedMap<K: Hashable, V> {

    private let mapLock = Threading.Lock()
    private var map: [K: [(time: UInt64, value: V)]] = [:]
    private let length: Int

    public init(length: Int) {
        self.length = length
    }

    public func setValue(key: K, value: V, time: UInt64) {
        mapLock.lock()
        if map[key] != nil {
            let lastIndex = map[key]?.lastIndex {value in value.time >= time}
            if lastIndex != nil {
                map[key]!.insert((time: time, value: value), at: lastIndex!)
            } else {
                map[key]!.append((time: time, value: value))
            }
            if map[key]!.count > length {
                _ = map[key]!.dropFirst()
            }
        } else {
            map[key] = [(time: time, value: value)]
        }
        mapLock.unlock()
    }

    public func getValueAt(key: K, time: UInt64) -> V? {
        mapLock.lock()
        let value: V?
        if map[key] != nil {
            value = map[key]!.last {value in value.time <= time}?.value
        } else {
            value = nil
        }
        mapLock.unlock()
        return value
    }
}
