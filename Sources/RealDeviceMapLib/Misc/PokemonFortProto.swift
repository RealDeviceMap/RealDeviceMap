//
// Created by fabio on 17.08.22.
//

import Foundation
import POGOProtos

extension PokemonFortProto {

    func calculatePowerUpPoints(now: UInt32) -> (level: UInt16, timestamp: UInt32?) {
        let powerUpLevelExpirationMs = UInt32(powerUpLevelExpirationMs / 1000)
        let powerUpPoints = powerUpProgressPoints
        var powerUpLevel: UInt16 = 0
        var powerUpEndTimestamp: UInt32?
        if powerUpPoints < 50 {
            powerUpLevel = 0
        } else if powerUpPoints < 100 && powerUpLevelExpirationMs > now {
            powerUpLevel = 1
            powerUpEndTimestamp = powerUpLevelExpirationMs
        } else if powerUpPoints < 150 && powerUpLevelExpirationMs > now {
            powerUpLevel = 2
            powerUpEndTimestamp = powerUpLevelExpirationMs
        } else if powerUpLevelExpirationMs > now {
            powerUpLevel = 3
            powerUpEndTimestamp = powerUpLevelExpirationMs
        } else {
            powerUpLevel = 0
        }
        return (powerUpLevel, powerUpEndTimestamp)
    }
}
