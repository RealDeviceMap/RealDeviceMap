//
//  CircleInstanceController.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 30.09.18.
//

import Foundation
import PerfectLib
import PerfectThread
import PerfectMySQL
import Turf

class CircleInstanceController: InstanceControllerProto {

    enum CircleType {
        case pokemon
        case smartPokemon
        case findyPokemon
        case jumpyPokemon
        case raid
    }

    public private(set) var name: String
    public private(set) var minLevel: UInt8
    public private(set) var maxLevel: UInt8
    public private(set) var accountGroup: String?
    public private(set) var isEvent: Bool
    internal var scanNextCoords: [Coord] = []
    public weak var delegate: InstanceControllerDelegate?

    private let type: CircleType
    private let coords: [Coord]
    private var lastIndex: Int = 0
    internal var lock = Threading.Lock()
    private var lastLastCompletedTime: Date?
    private var lastCompletedTime: Date?
    private var currentUuidIndexes: [String: Int]
    private var currentUuidSeenTime: [String: Date]
    public let useRwForRaid: Bool = ConfigLoader.global.getConfig(type: .accUseRwForRaid)
    public let useRwForPokes: Bool = ConfigLoader.global.getConfig(type: .accUseRwForPokes)

    struct jumpyCoord
    {
        var id: UInt64
        var coord: Coord
        var spawn_sec: UInt16
    }
    var jumpyCoords: [jumpyCoord]
    var findyCoords: [Coord]
    let minTimeFromSpawn: UInt64 = 30
    let minTimeLeft : UInt64 = 1200
    var jumpySpot: Int = 0
    static var currentDevicesMaxLocation = Dictionary<String,Int>()
    let deviceUuid: String
    var jumpyLock = Threading.Lock()
    var findyLock = Threading.Lock()
    var pauseJumping: Bool = false
    var firstRun: Bool = true
    public static var jumpyCache: MemoryCache<Int> = MemoryCache(interval:240, keepTime:3600, extendTtlOnHit:false)
    public static var findyCache: MemoryCache<Int> = MemoryCache(interval:60, keepTime:900, extendTtlOnHit:false)
    
    init(name: String, coords: [Coord], type: CircleType, minLevel: UInt8, maxLevel: UInt8,
         accountGroup: String?, isEvent: Bool) {
        self.name = name
        self.minLevel = minLevel
        self.maxLevel = maxLevel
        self.accountGroup = accountGroup
        self.isEvent = isEvent
        self.coords = coords
        self.type = type
        self.lastCompletedTime = Date()
        self.currentUuidIndexes = [:]
        self.currentUuidSeenTime = [:]
        self.scanNextCoords = [Coord]()
        
        self.jumpyCoords = [jumpyCoord]()
        self.findyCoords = [Coord]()
        self.deviceUuid = UUID().uuidString
    }


    func initJumpyCoords() throws
    {
        Log.debug(message: "initJumpyCoords() - Starting")
        guard let mysql = DBController.global.mysql else 
        {
            Log.error(message: "[WebHookRequestHandler] [initJumpyCoords] Failed to connect to database.")
            return
        }

        if coords.count > 0
        {
            jumpyLock.lock()
            jumpyCoords.removeAll(keepingCapacity: true)
            
            Log.debug(message: "initJumpyCoords() - got \(coords.count) coords for geofence")
            
            var arrayCoords = [[Coord]]()
            var tmpArrayCoord = [Coord]()
            for coord in coords
            {
                tmpArrayCoord.append(coord)
            }
            tmpArrayCoord.append(coords[0])
            arrayCoords.append(tmpArrayCoord)
            
            let geofence = createMultiPolygon(areaArray: arrayCoords)

            var tmpCoords: [jumpyCoord] = [jumpyCoord]()
            //tmpCoords.reserveCapacity( min( 2000, jumpyCoords.count / 2 ) )

            // get min and max coords from the route coords list
            var minLat:Double = 90
            var maxLat:Double = -90
            var minLon:Double = 180
            var maxLon:Double = -180
            for coord in coords
            {
                minLat = min(minLat, coord.lat)
                maxLat = max(maxLat, coord.lat)
                minLon = min(minLon, coord.lon)
                maxLon = max(maxLon, coord.lon)
            }
        
            // assemble the sql
            var sql = "select id, despawn_sec, lat, lon from spawnpoint where " 
            sql.append("(lat>" + String(minLat) + " AND lon >" + String(minLon) + ")")
            sql.append(" AND ")
            sql.append("(lat<" + String(maxLat) + " AND lon <" + String(maxLon) + ")")
            sql.append(" AND despawn_sec is not null")
            sql.append(" order by despawn_sec")

            let mysqlStmt = MySQLStmt(mysql)
            _ = mysqlStmt.prepare(statement: sql)

            guard mysqlStmt.execute() else
            {
                Log.error(message: "[initJumpyCoords] Failed to execute query. (\(mysqlStmt.errorMessage())")
                throw DBController.DBError()
            }

            var count:Int = 0;
            let results = mysqlStmt.results()
            while let result = results.next()
            { 
                let id = result[0] as! UInt64
                let despawn_sec = result[1] as! UInt16
                let lat = result[2] as! Double
                let lon = result[3] as! Double

                var spawn_sec:Int = Int(despawn_sec)

                spawn_sec -= 1800 // add 30min so when spawn should show, rdm not track 60min spawns

                if (spawn_sec < 0)
                {
                    spawn_sec += 3600
                }

                if ( inPolygon(lat: lat, lon: lon, multiPolygon: geofence) )
                {
                    tmpCoords.append( jumpyCoord( id: id, coord: Coord(lat: lat,lon: lon), spawn_sec: UInt16(spawn_sec) ) )
                }

                count += 1
            }
            Log.debug(message: "initJumpyCoords() - got \(count) spawnpoints in min/max rectangle")
            Log.debug(message: "initJumpyCoords() - got \(tmpCoords.count) spawnpoints in geofence")

            // sort the array, so 0-3600 sec in order
            jumpyCoords = tmpCoords

            // take lazy man's approach, probably not ideal
            // add elements to end, so 3600-7199 sec
            for coord in tmpCoords
            {
                jumpyCoords.append(jumpyCoord( id: coord.id, coord: coord.coord, spawn_sec: coord.spawn_sec + 3600 ))
            }

            // did the list shrink from last query?
            let oldJumpyCoord = CircleInstanceController.currentDevicesMaxLocation[self.name] ?? 0
            if (oldJumpyCoord >= jumpyCoords.count)
            {
                CircleInstanceController.currentDevicesMaxLocation[self.name] = jumpyCoords.count - 1
            }

            jumpyLock.unlock()
        }
    }

    func initFindyCoords() throws
    {
        Log.debug(message: "initJumpyCoords() - Starting")
        guard let mysql = DBController.global.mysql else 
        {
            Log.error(message: "[WebHookRequestHandler] [initJumpyCoords] Failed to connect to database.")
            return
        }

        if coords.count > 0
        {
            findyLock.lock()
            findyCoords.removeAll(keepingCapacity: true)
            
            Log.debug(message: "initJumpyCoords() - got \(coords.count) coords for geofence")
            
            var arrayCoords = [[Coord]]()
            var tmpArrayCoord = [Coord]()
            for coord in coords
            {
                tmpArrayCoord.append(coord)
            }
            tmpArrayCoord.append(coords[0])
            arrayCoords.append(tmpArrayCoord)
            
            let geofence = createMultiPolygon(areaArray: arrayCoords)

            var tmpCoords = [Coord]()
            //tmpCoords.reserveCapacity( min( 2000, jumpyCoords.count / 2 ) )

            // get min and max coords from the route coords list
            var minLat:Double = 90
            var maxLat:Double = -90
            var minLon:Double = 180
            var maxLon:Double = -180
            for coord in coords
            {
                minLat = min(minLat, coord.lat)
                maxLat = max(maxLat, coord.lat)
                minLon = min(minLon, coord.lon)
                maxLon = max(maxLon, coord.lon)
            }
        
            // assemble the sql
            var sql = "select lat, lon from spawnpoint where " 
            sql.append("(lat>" + String(minLat) + " AND lon >" + String(minLon) + ")")
            sql.append(" AND ")
            sql.append("(lat<" + String(maxLat) + " AND lon <" + String(maxLon) + ")")
            sql.append(" AND despawn_sec is null")

            let mysqlStmt = MySQLStmt(mysql)
            _ = mysqlStmt.prepare(statement: sql)

            guard mysqlStmt.execute() else
            {
                Log.error(message: "[initJumpyCoords] Failed to execute query. (\(mysqlStmt.errorMessage())")
                throw DBController.DBError()
            }

            var count:Int = 0;
            let results = mysqlStmt.results()
            while let result = results.next()
            { 
                let lat = result[0] as! Double
                let lon = result[1] as! Double

                if ( inPolygon(lat: lat, lon: lon, multiPolygon: geofence) )
                {
                    tmpCoords.append( Coord(lat: lat,lon: lon) )
                }

                count += 1
            }
            Log.debug(message: "initFindyCoords() - got \(count) spawnpoints in min/max rectangle with null tth")
            Log.debug(message: "initFindyCoords() - got \(tmpCoords.count) spawnpoints in geofence with null tth")

            if (count == 0)
            {
                Log.debug(message: "initFindyCoords() - got \(count) spawnpoints in min/max rectangle with null tth")
            }

            if (tmpCoords.count == 0)
            {
                Log.debug(message: "initFindyCoords() - got \(tmpCoords.count) spawnpoints in geofence with null tth")
            }

            // sort the array, so 0-3600 sec in order
            findyCoords = tmpCoords

            // did the list shrink from last query?
            /*
            let oldJumpyCoord = CircleInstanceController.currentDevicesMaxLocation[self.name] ?? 0
            if (oldJumpyCoord >= jumpyCoords.count)
            {
                CircleInstanceController.currentDevicesMaxLocation[self.name] = jumpyCoords.count - 1
            }
            */
            CircleInstanceController.currentDevicesMaxLocation[self.name] = 0

            findyLock.unlock()
        }
    }


    func secondsFromTopOfHour(seconds: UInt64 )-> (UInt64)
    {
        var ret:UInt64 = (seconds % 3600)
        ret += (seconds % 3600) % 60
        return ret
    }

    func secondsToHoursMinutesSeconds() -> (hours: UInt64, minutes: UInt64, seconds: UInt64)
    {
        let now = UInt64(Date().timeIntervalSince1970)
        return (UInt64(now / 3600), UInt64((now % 3600) / 60), UInt64((now % 3600) % 60))
    }

    func offsetsForSpawnTimer(time: UInt16) -> (UInt16, UInt16)
    {
        let maxTime:UInt16 = time + 300
        let minTime:UInt16 = time + 15

        return (minTime, maxTime)
    }
    
    func determineNextJumpyLocation(CurTime: UInt64, curLocation: Int) -> Int
    {
        let cntArray = jumpyCoords.count
        let cntCoords = jumpyCoords.count / 2

        var curTime = CurTime
        var loc = curLocation
        
        // increment position
        loc = curLocation + 1
        if (loc > cntCoords )  // past the end of normal coords
        {
            Log.debug(message: "determineNextJumpyLocation() - reached end of data, going back to zero")
            
            lastLastCompletedTime = lastCompletedTime
            lastCompletedTime = Date()

            return 0
        }
        else if (loc < 0)  // somehow less than zero
        {
            loc = 0
        }
        
        var nextCoord = jumpyCoords[loc]
        var spawn_sec:UInt16 = nextCoord.spawn_sec

        var (minTime, maxTime) = offsetsForSpawnTimer(time: spawn_sec)
        Log.debug(message: "determineNextJumpyLocation() - minTime=\(minTime) & curTime=\(curTime) & maxTime=\(maxTime)")

        let topOfHour = (minTime < 0)
        if (topOfHour)
        {
            curTime += 3600
            minTime += 3600
            maxTime += 3600
        }

        // do the shit
        if ((curTime >= minTime) && (curTime <= maxTime))
        {
            // good to jump as between to key points for current time
            Log.debug(message: "determineNextJumpyLocation() a1 - curtime between min and max, moving standard 1 forward")

            // test if we are getting too close to the mintime
            if  (Double(curTime) - Double(minTime) < 30) 
            {
                Log.debug(message: "determineNextJumpyLocation() a2 - sleeping 10sec as too close to minTime, in normal time")
                Threading.sleep(seconds: 10)
            }
        }
        else if (curTime < minTime)
        {
            // spawn is past time to visit, need to find a good one to jump to
            Log.debug(message: "determineNextJumpyLocation() b1 - curTime \(curTime) > maxTime, iterate")

            var found: Bool = false
            let start = loc
            for idx in start..<cntArray
            {
                nextCoord = jumpyCoords[idx]
                spawn_sec = nextCoord.spawn_sec
                    
                let (mnTime, mxTime) = offsetsForSpawnTimer(time: spawn_sec)

                if  (curTime >= mnTime) && (curTime <= mnTime + 120)
                {
                    Log.debug(message: "determineNextJumpyLocation() b2 - mnTime=\(mnTime) & curTime=\(curTime) & & mxTime=\(mxTime)")
                    found = true
                    loc = idx
                    break
                }
            }
            
            if (!found)  // location not found from current to end of spawntimes for hour, start over at zero
            {
                for idx in (0..<start).reversed()
                {
                    nextCoord = jumpyCoords[idx]
                    spawn_sec = nextCoord.spawn_sec
                        
                    let (mnTime, mxTime) = offsetsForSpawnTimer(time: spawn_sec)

                    if  (curTime >= mnTime + 30) && (curTime < mnTime + 120)
                    {
                        Log.debug(message: "determineNextJumpyLocation() b3 - iterate backwards solution=\(found)")
                        Log.debug(message: "determineNextJumpyLocation() b4 -  mnTime=\(mnTime) & curTime=\(curTime) &mxTime=\(mxTime)")
                        found = true
                        loc = idx
                        break
                    }
                }
            }
        }
        else if (curTime < minTime ) && (!firstRun)
        {
            Log.debug(message: "determineNextJumpyLocation() c1 - sleeping 20sec")
            Threading.sleep(seconds: 20)

            pauseJumping = true
            loc = loc - 1
        }
        else if (curTime > maxTime)
        {
            // spawn is past time to visit, need to find a good one to jump to
            Log.debug(message: "determineNextJumpyLocation() d1 - curTime=\(curTime) > maxTime=\(maxTime), iterate")

            var found: Bool = false
            let start = loc
            for idx in start..<cntArray
            {
                nextCoord = jumpyCoords[idx]
                spawn_sec = nextCoord.spawn_sec
                    
                let (mnTime, mxTime) = offsetsForSpawnTimer(time: spawn_sec)

                if  (curTime >= mnTime+30) && (curTime <= mnTime + 120)
                {
                    Log.debug(message: "determineNextJumpyLocation() d2 - iterate forward solution=\(found)")
                    Log.debug(message: "determineNextJumpyLocation() d3 -  mnTime=\(mnTime) & curTime=\(curTime) &mxTime=\(mxTime)")
                    found = true
                    loc = idx
                    break
                }
            }
            
            if (!found)  // location not found from current to end of spawntimes for hour, start over at zero
            {
                for idx in (0..<start).reversed()
                {
                    nextCoord = jumpyCoords[idx]
                    spawn_sec = nextCoord.spawn_sec
                        
                    let (mnTime, mxTime) = offsetsForSpawnTimer(time: spawn_sec)

                    if   (curTime >= mnTime+30) && (curTime <= mnTime + 120)
                    {
                        Log.debug(message: "determineNextJumpyLocation() d4 - iterate backwards solution=\(found)")
                        Log.debug(message: "determineNextJumpyLocation() d5 -  mnTime=\(mnTime) & curTime=\(curTime) &mxTime=\(mxTime)")
                        found = true
                        loc = idx
                        break
                    }
                }
            }
        }
        else
        {
            Log.debug(message: "determineNextJumpyLocation() e1 - criteria fail with curTime=\(curTime) & curLocation=\(curLocation)" +
                      "& despawn=\(spawn_sec)")
            // go back to zero and iterate somewhere useful
            loc=0
        }
        
        if (loc == cntCoords-1)
        {
            lastLastCompletedTime = lastCompletedTime
            lastCompletedTime = Date()
        }

        // check if we went past half
        if (loc > cntCoords)
        {
            loc -= cntCoords
        }
        
        return loc
    }

    func routeDistance(xcoord: Int, ycoord: Int) -> Int {
        if xcoord < ycoord {
            return ycoord - xcoord
        }
        return ycoord + (coords.count - xcoord)
    }

    func checkSpacingDevices(uuid: String) -> [String: Int] {
        let deadDeviceCutoffTime = Date().addingTimeInterval(-60)
        var liveDevices = [String]()

        // Check if all registered devices are still online and clean list
        for (currentUuid, _) in currentUuidIndexes.sorted(by: { return $0.1 < $1.1 }) {
            let lastSeen = currentUuidSeenTime[currentUuid]
            if lastSeen != nil {
                if lastSeen! < deadDeviceCutoffTime {
                    currentUuidIndexes[currentUuid] = nil
                    currentUuidSeenTime[currentUuid] = nil
                } else {
                    liveDevices.append(currentUuid)
                }
            }
        }

        let nbliveDevices = liveDevices.count
        var distanceToNext = coords.count

        for i in 0..<nbliveDevices {
            if uuid != liveDevices[i] {
                continue
            }
            if i < nbliveDevices - 1 {
                let nextDevice = liveDevices[i+1]
                distanceToNext = routeDistance(xcoord: currentUuidIndexes[uuid]!,
                                               ycoord: currentUuidIndexes[nextDevice]!)
            } else {
                let nextDevice = liveDevices[0]
                distanceToNext = routeDistance(xcoord: currentUuidIndexes[uuid]!,
                                               ycoord: currentUuidIndexes[nextDevice]!)
            }
        }
        return ["numliveDevices": nbliveDevices, "distanceToNext": distanceToNext]
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    func getTask(mysql: MySQL, uuid: String, username: String?, account: Account?, timestamp: UInt64) -> [String: Any] {
        var currentIndex = 0
        var currentUuidIndex = 0
        var currentCoord = coords[currentIndex]
        lock.lock()
        
        if type != .jumpyPokemon || type != .findyPokemon {
            if !scanNextCoords.isEmpty {
                currentCoord = scanNextCoords.removeFirst()
                lock.unlock()
                var task: [String: Any] = ["action": "scan_pokemon", "lat": currentCoord.lat, "lon": currentCoord.lon,
                        "min_level": minLevel, "max_level": maxLevel]
                if InstanceController.sendTaskForLureEncounter { task["lure_encounter"] = true }
                return task
            }
        }


        if type == .jumpyPokemon
        { 
            // don't give a crap about laptime, as by definition it is 1hr

            lock.unlock()

            let hit = CircleInstanceController.jumpyCache.get(id: self.name) ?? 0
            if hit == 0
            {
                try? initJumpyCoords()
                CircleInstanceController.jumpyCache.set(id: self.name, value: 1)
            }
            
            Log.debug(message: "getTask() - jumpy started for \(self.name)")

            let (_,min,sec) = secondsToHoursMinutesSeconds()
            let curSecInHour = min*60+sec
            jumpyLock.lock()
            
            // increment location
            var loc:Int = 0
            let keyExists = CircleInstanceController.currentDevicesMaxLocation[self.name] != nil
            if keyExists
            {
                loc = CircleInstanceController.currentDevicesMaxLocation[self.name]!
            }
            else
            {
                loc = 0
            }

            let newLoc = determineNextJumpyLocation(CurTime: curSecInHour, curLocation: loc)
            firstRun = false

            Log.debug(message: "getTask() jumpy - oldLoc=\(loc) & newLoc=\(newLoc)/\(jumpyCoords.count / 2)")
            
            var currentJumpyCoord:jumpyCoord = jumpyCoord(id:1, coord:Coord(lat: 0.0,lon: 0.0), spawn_sec:0)
            if jumpyCoords.indices.contains(newLoc)
            {
                CircleInstanceController.currentDevicesMaxLocation[self.name] = newLoc
                currentJumpyCoord = jumpyCoords[newLoc]
            }
            else
            {
                if jumpyCoords.indices.contains(0)
                {
                    CircleInstanceController.currentDevicesMaxLocation[self.name] = 0
                    currentJumpyCoord = jumpyCoords[0]
                }
                else
                {
                    CircleInstanceController.currentDevicesMaxLocation[self.name] = -1
                }
            }

            jumpyLock.unlock()

            var task: [String: Any] = ["action": "scan_pokemon", "lat": currentJumpyCoord.coord.lat, "lon": currentJumpyCoord.coord.lon, "min_level": minLevel, "max_level": maxLevel]
            
            if InstanceController.sendTaskForLureEncounter { task["lure_encounter"] = true }

            Log.debug(message: "getTask() jumpy- ended")

            return task
        }
        else if type == .findyPokemon
        {
            // get route like for findy, specify fence and use tth = null
            // with each gettask, just increment to next point in list
            // requery the route every ???? min, set with cache above
            // run until data length == 0, then output a message to tell user done
            // since we actually care about laptime, use that variable

            lock.unlock()

            findyLock.lock()

            let hit = CircleInstanceController.findyCache.get(id: self.name) ?? 0
            if hit == 0
            {
                try? initFindyCoords()
                CircleInstanceController.findyCache.set(id: self.name, value: 1)
            }

            // increment location
            var loc:Int = 0
            let keyExists = CircleInstanceController.currentDevicesMaxLocation[self.name] != nil
            if keyExists
            {
                loc = CircleInstanceController.currentDevicesMaxLocation[self.name]!
            }
            else
            {
                loc = 0
            }

            var newLoc = loc + 1
            if (newLoc >= findyCoords.count )
            {
                newLoc = 0
            }

            Log.debug(message: "getTask() findy - oldLoc=\(loc) & newLoc=\(newLoc)/\(findyCoords.count)")

            CircleInstanceController.currentDevicesMaxLocation[self.name] = newLoc
            
            var currentFindyCoord:Coord = Coord(lat: 0.0,lon: 0.0)
            if findyCoords.indices.contains(newLoc)
            {
                currentFindyCoord = findyCoords[newLoc]
            }
            else
            {
                if findyCoords.indices.contains(0)
                {
                    CircleInstanceController.currentDevicesMaxLocation[self.name] = 0
                    currentFindyCoord = findyCoords[newLoc]
                }
                else
                {
                    CircleInstanceController.currentDevicesMaxLocation[self.name] = -1
                }
            }
 
            var task: [String: Any] = ["action": "scan_pokemon", "lat": currentFindyCoord.lat, "lon": currentFindyCoord.lon, "min_level": minLevel, "max_level": maxLevel]
            
            findyLock.unlock()

            if InstanceController.sendTaskForLureEncounter { task["lure_encounter"] = true }

            Log.debug(message: "getTask() findy- ended")

            return task

        }
        else if type == .smartPokemon {
            currentUuidIndex = currentUuidIndexes[uuid] ?? Int.random(in: 0..<coords.count)
            currentUuidIndexes[uuid] = currentUuidIndex
            currentUuidSeenTime[uuid] = Date()
            var shouldAdvance = true
            var jumpDistance = 0

            if currentUuidIndexes.count > 1 && Int.random(in: 0...100) < 15 {
                let live = checkSpacingDevices(uuid: uuid)
                let dist = 10 * live["distanceToNext"]! * live["numliveDevices"]! + 5
                if dist < 10 * coords.count {
                    shouldAdvance = false
                }
                if dist > 12 * coords.count {
                    jumpDistance = live["distanceToNext"]! - coords.count / live["numliveDevices"]! - 1
                }
            }
            if currentUuidIndex == 0 && coords.count > 1 {
                shouldAdvance = true
            }
            if shouldAdvance {
                currentUuidIndex += jumpDistance + 1
                if currentUuidIndex >= coords.count - 1 {
                    currentUuidIndex -= coords.count - 1
                    lastLastCompletedTime = lastCompletedTime
                    lastCompletedTime = Date()
                }
            } else {
                currentUuidIndex -= 1
                if currentUuidIndex < 0 {
                    currentUuidIndex = coords.count - 1
                }
            }
            currentUuidIndexes[uuid] = currentUuidIndex
            currentCoord = coords[currentUuidIndex]
            lock.unlock()
            var task: [String: Any] = ["action": "scan_pokemon", "lat": currentCoord.lat, "lon": currentCoord.lon,
                    "min_level": minLevel, "max_level": maxLevel]
            if InstanceController.sendTaskForLureEncounter { task["lure_encounter"] = true }
            return task
        } else {
            currentIndex = self.lastIndex
            if lastIndex + 1 == coords.count {
                lastLastCompletedTime = lastCompletedTime
                lastCompletedTime = Date()
                lastIndex = 0
            } else {
                lastIndex += 1
            }
            currentCoord = coords[currentIndex]
            lock.unlock()
            var task: [String: Any]
            if type == .pokemon {
                task = ["action": "scan_pokemon", "lat": currentCoord.lat, "lon": currentCoord.lon,
                        "min_level": minLevel, "max_level": maxLevel]
            } else {
                task = ["action": "scan_raid", "lat": currentCoord.lat, "lon": currentCoord.lon,
                        "min_level": minLevel, "max_level": maxLevel]
            }
            if InstanceController.sendTaskForLureEncounter { task["lure_encounter"] = true }
            return task
        }
    }

    // swiftlint:enable function_body_length
    func getStatus(mysql: MySQL, formatted: Bool) -> JSONConvertible? {
        if self.type == .jumpyPokemon
        {
            let cnt = self.jumpyCoords.count/2

            if formatted
            {
                return "Coord Count: \(cnt)"
            } else {
                return ["coord_count": cnt]
            }
        }
        else if self.type == .findyPokemon
        {
            if formatted
            {
                return "Coord Count: \(self.findyCoords.count)"
            }
            else
            {
                return ["coord_count": self.findyCoords.count]
            }
        }
        else
        {
            if let lastLast = lastLastCompletedTime, let last = lastCompletedTime
            {
                let time = Int(last.timeIntervalSince(lastLast))
                if formatted {
                    return "Round Time: \(time)s"
                } else {
                    return ["round_time": time]
                }
            } else {
                if formatted {
                    return "-"
                } else {
                    return nil
                }
            }
        }
    }

    func reload() {
        lock.lock()
        lastIndex = 0
        lock.unlock()
    }

    func stop() {}

    func getAccount(mysql: MySQL, uuid: String) throws -> Account? {
        switch type {
        case .pokemon, .smartPokemon, .jumpyPokemon, .findyPokemon:
            return try Account.getNewAccount(
                mysql: mysql,
                minLevel: minLevel,
                maxLevel: maxLevel,
                ignoringWarning: useRwForPokes,
                spins: nil,
                noCooldown: false,
                device: uuid,
                group: accountGroup
            )
        case .raid:
            return try Account.getNewAccount(
                mysql: mysql,
                minLevel: minLevel,
                maxLevel: maxLevel,
                ignoringWarning: useRwForRaid,
                spins: nil,
                noCooldown: false,
                device: uuid,
                group: accountGroup
            )
        }
    }

    func accountValid(account: Account) -> Bool {
        switch type {
        case .pokemon, .smartPokemon, .jumpyPokemon, .findyPokemon:
            return account.level >= minLevel &&
                account.level <= maxLevel &&
                account.isValid(ignoringWarning: useRwForPokes, group: accountGroup)
        case .raid:
            return account.level >= minLevel &&
                account.level <= maxLevel &&
                account.isValid(ignoringWarning: useRwForRaid, group: accountGroup)
        }
    }
    
    private func createMultiPolygon(areaArray: [[Coord]]) -> MultiPolygon {
        var geofences = [[[LocationCoordinate2D]]]()
        for coord in areaArray {
            var geofence = [LocationCoordinate2D]()
            for crd in coord {
                geofence.append(LocationCoordinate2D.init(latitude: crd.lat, longitude: crd.lon))
            }
            geofences.append([geofence])
        }
        return MultiPolygon.init(geofences)
    }
    
    private func inPolygon(lat: Double, lon: Double, multiPolygon: MultiPolygon) -> Bool
    {
        for polygon in multiPolygon.polygons
        {
            let coord = LocationCoordinate2D(latitude: lat, longitude: lon)
            
            if polygon.contains(coord, ignoreBoundary: false)
            {
                return true
            }
        }
        
        return false
    }
}
