//
//  DiscordController.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 31.12.18.
//

import Foundation
import PerfectLib
import PerfectThread
import cURL
import PerfectCURL
import PerfectMySQL

class DiscordController {

    struct DiscordUser {
        var id: UInt64
        var rolesInGuilds: [UInt64: [UInt64]]
    }

    public private(set) static var global = DiscordController()
    
    public var guilds = [UInt64]()
    public var token: String?
    
    private var usersLock = Threading.Lock()
    private var users = [UInt64: DiscordUser]()
    
    private var discordRulesLock = Threading.Lock()
    private var discordRules = [DiscordRule]()

    private init() {}
    
    public func setup() throws {
        
        self.users = [UInt64: DiscordUser]()
        let users = try User.getAll()
        for user in users {
            if let id = user.discordId {
                self.users[id] = DiscordUser(id: id, rolesInGuilds: [UInt64: [UInt64]]())
            }
        }
        
        let queue = Threading.getQueue(name: "DiscordController", type: .serial)
        queue.dispatch {
            self.runForEver()
        }
        
        discordRulesLock.lock()
        discordRules = try DiscordRule.getAll()
        discordRules.sort { (lhs, rhs) -> Bool in
            return lhs.priority > rhs.priority
        }
        discordRulesLock.unlock()
        
    }

    private func runForEver() {
        while true {
            if token != nil && token! != "" {
                let users = getAll(guilds: guilds)
                usersLock.lock()
                let oldUsers = self.users
                usersLock.unlock()
                var changedUsers = [UInt64: DiscordUser]()
                for user in users {
                    let oldUser = oldUsers[user.key]
                    if oldUser == nil {
                        changedUsers[user.key] = user.value
                    } else {
                        if oldUser!.rolesInGuilds != user.value.rolesInGuilds {
                            changedUsers[user.key] = user.value
                        }
                    }
                }
                for oldUser in oldUsers {
                    if !users.contains(where: { (user) -> Bool in
                        user.key == oldUser.key
                    }) {
                        var oldUser = oldUser
                        oldUser.value.rolesInGuilds.removeAll()
                        changedUsers[oldUser.key] = oldUser.value
                    }
                }
                Log.debug(message: "[DiscordController] Users: \(users.count), Changed: \(changedUsers.count)")
                
                usersChanged(users: changedUsers)
                
                usersLock.lock()
                self.users = users
                usersLock.unlock()
            }
            Threading.sleep(seconds: 30.0)
        }
    }
    
    public func getAll(guilds: [UInt64]) -> [UInt64: DiscordUser] {
        
        var users = [UInt64: DiscordUser]()
        
        for guild in guilds {
        
            let url = "https://discordapp.com/api/guilds/\(guild)/members"
            var done = false
            var after: UInt64 = 0
            
            while !done && token != nil {
            
                let curlObject = CURL(url: "\(url)?limit=1000&after=\(after)")
                curlObject.setOption(CURLOPT_HTTPHEADER, s: "Authorization: Bot \(token ?? "")")
                let result = curlObject.performFullySync()
                let data = Data(result.bodyBytes)
                
                var rateLimitReset: UInt32 = 0
                var rateLimitRemaining = 10
                var rateLimitBlock: UInt64 = 0
                
                if let headers = String(data: Data(result.headerBytes), encoding: .utf8)?.components(separatedBy: "\r\n") {
                    for header in headers {
                        if header.contains(string: ":") {
                            let split = header.components(separatedBy: ":")
                            let key = split[0].trimmingCharacters(in: .whitespacesAndNewlines)
                            let value = split[1..<split.count].joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                            if key == "X-RateLimit-Remaining" {
                                rateLimitRemaining = value.toInt() ?? 10
                            } else if key == "X-RateLimit-Reset" {
                                rateLimitReset = value.toUInt32() ?? 0
                            } else if key == "Retry-After" {
                                rateLimitBlock = value.toUInt64() ?? 0
                            }
                        }
                    }
                }
                
                guard let json = String(data: data, encoding: .utf8)?.jsonDecodeForceTry() as? [[String: Any]] else {
                    Threading.sleep(seconds: 60.0)
                    continue
                }
                
                for element in json {
                    if let user = element["user"] as? [String: Any],
                       let id = (user["id"] as? String)?.toUInt64() {

                        let rolesString = element["roles"] as? [String] ?? [String]()
                        var roles = [UInt64]()
                        for roleString in rolesString {
                            if let role = roleString.toUInt64() {
                                roles.append(role)
                            }
                        }
                        
                        if var oldUser = users[id] {
                            oldUser.rolesInGuilds[guild] = roles
                            users[id] = oldUser
                        } else {
                            users[id] = DiscordUser(id: id, rolesInGuilds: [guild: roles])
                        }
                        
                        if id > after {
                            after = id
                        }
                            
                    }

                }
                
                if json.count != 1000 {
                    done = true
                }
                
                let now = UInt32(Date().timeIntervalSince1970)
                if rateLimitBlock != 0 {
                    let delay = rateLimitBlock / 1000
                    Log.debug(message: "[DiscordController] Hit Rate Limit. Sleeping \(delay)s.")
                    Threading.sleep(seconds: Double(delay))
                } else if rateLimitRemaining <= 1 && now < rateLimitReset {
                    let delay = rateLimitReset - now + 1
                    Log.debug(message: "[DiscordController] Rate Limited. Sleeping \(delay)s.")
                    Threading.sleep(seconds: Double(delay))
                }
            }
            
        }
        
        return users
    }
    
    public func userChanged(user: User) {
        usersLock.lock()
        if let discordId = user.discordId, let discordUser = users[discordId] {
            usersLock.unlock()
            userChanged(user: user, discordUser: discordUser)
        } else {
            usersLock.unlock()
        }
    }
    
    private func usersChanged(users: [UInt64: DiscordUser]) {
        
        if users.isEmpty {
            return
        }
        
        let mysql = DBController.global.mysql
        
        var success = false
        var dbUsers = [User]()
        while !success {
            do {
                dbUsers = try User.getAll(onlyDiscord: true, mysql: mysql)
                success = true
            } catch {
                Threading.sleep(seconds: 5.0)
            }
        }
        
        for dbUser in dbUsers {
            if let user = users[dbUser.discordId ?? 0] {
                userChanged(user: dbUser, discordUser: user)
            }
        }
        
    }
    
    private func userChanged(user: User, discordUser: DiscordUser) {

        var firstMatch: String
        if user.emailVerified {
            firstMatch = "default_verified"
        } else {
            firstMatch = "default"
        }
        
        discordRulesLock.lock()
        for rule in discordRules {
            
            if let roles = discordUser.rolesInGuilds[rule.serverId], (rule.roleId == nil || roles.contains(rule.roleId!)) {
                firstMatch = rule.groupName
                break
            }
        }
        discordRulesLock.unlock()
        
        var success = false
        while !success {
            do {
                try user.setGroup(groupName: firstMatch)
                success = true
            } catch {
                Threading.sleep(seconds: 5.0)
            }
        }
    }
    
    public func getAllGuilds() -> [UInt64: (name: String, roles: [UInt64: String])] {
        
        var guilds = [UInt64: (name: String, roles: [UInt64: String])]()
        
        for guild in self.guilds {
        
            let url = "https://discordapp.com/api/guilds/\(guild)"
            let curlObject = CURL(url: url)
            curlObject.setOption(CURLOPT_HTTPHEADER, s: "Authorization: Bot \(token ?? "")")
            let result = curlObject.performFullySync()
            let data = Data(result.bodyBytes)

            guard let json = String(data: data, encoding: .utf8)?.jsonDecodeForceTry() as? [String: Any] else {
                continue
            }

            if let idString = json["id"] as? String, let id = idString.toUInt64(), let name = json["name"] as? String, let roles = json["roles"] as? [[String: Any]] {
                var rolesNew = [UInt64: String]()
                for role in roles {
                    if let idString = role["id"] as? String, let id = idString.toUInt64(), let name = role["name"] as? String {
                        rolesNew[id] = name
                    }
                }
                
                guilds[id] = (name: name, roles: rolesNew)
            }
            
        }
        
        return guilds
    }
    
    public func addDiscordRule(discordRule: DiscordRule) {
        discordRulesLock.lock()
        discordRules.append(discordRule)
        discordRules.sort { (lhs, rhs) -> Bool in
            return lhs.priority > rhs.priority
        }
        discordRulesLock.unlock()
        
        usersChanged(users: users)
    }
    
    public func deleteDiscordRule(priority: Int32) {
        discordRulesLock.lock()
        if let index = discordRules.index(of: DiscordRule(priority: priority, serverId: 0, roleId: 0, groupName: "")) {
            discordRules.remove(at: index)
        }
        discordRules.sort { (lhs, rhs) -> Bool in
            return lhs.priority > rhs.priority
        }
        discordRulesLock.unlock()
    }
    
    public func updateDiscordRule(oldPriority: Int32, discordRule: DiscordRule) {
        discordRulesLock.lock()
        if let index = discordRules.index(of: DiscordRule(priority: oldPriority, serverId: 0, roleId: 0, groupName: "")) {
            discordRules.remove(at: index)
        }
        discordRules.append(discordRule)
        discordRules.sort { (lhs, rhs) -> Bool in
            return lhs.priority > rhs.priority
        }
        discordRulesLock.unlock()
    }
    
    public func updateGroupName(oldName: String, newName: String) {
        discordRulesLock.lock()
        for rule in discordRules {
            if rule.groupName == oldName {
                rule.groupName = newName
            }
        }
        discordRulesLock.unlock()
    }
    
    public func getDiscordRules() -> [DiscordRule] {
        discordRulesLock.lock()
        let rules = discordRules
        discordRulesLock.unlock()
        return rules
    }
    
}

