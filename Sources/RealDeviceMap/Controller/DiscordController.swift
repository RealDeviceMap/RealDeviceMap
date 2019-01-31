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

class DiscordController {
    
    struct DiscordUser {
        var id: UInt64
        var roleIds: Set<UInt64>
        var guildIds: Set<UInt64>
    }

    public private(set) static var global = DiscordController()
    
    public static var guilds = [UInt64]()
    public static var token: String?
    
    private var users = [UInt64: DiscordUser]()

    private init() {}
    
    public func setup() throws {
        
        let queue = Threading.getQueue(name: "DiscordController", type: .serial)
        queue.dispatch {
            self.runForEver()
        }
    }

    private func runForEver() {
        while true {
            if DiscordController.token != nil && DiscordController.token! != "" {
                let users = getAll(guilds: DiscordController.guilds)
                var changedUsers = [DiscordUser]()
                for user in users {
                    let oldUser = self.users[user.key]
                    if oldUser == nil {
                        changedUsers.append(user.value)
                    } else {
                        if oldUser!.guildIds != user.value.guildIds ||
                            oldUser!.roleIds != user.value.roleIds {
                            changedUsers.append(user.value)
                        }
                    }
                }
                Log.debug(message: "[DiscordController] Users: \(users.count), Changed: \(changedUsers.count)")
                //print(changedUsers)
                
                // TODO: - Changed Users
                
                self.users = users
            }
            Threading.sleep(seconds: 15.0)
        }
    }
    
    public func getAll(guilds: [UInt64]) -> [UInt64: DiscordUser] {
        
        var users = [UInt64: DiscordUser]()
        
        for guild in guilds {
        
            let url = "https://discordapp.com/api/guilds/\(guild)/members"
            var done = false
            var after: UInt64 = 0
            
            while !done && DiscordController.token != nil {
            
                let curlObject = CURL(url: "\(url)?limit=1000&after=\(after)")
                curlObject.setOption(CURLOPT_HTTPHEADER, s: "Authorization: Bot \(DiscordController.token ?? "")")
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
                        
                        var discordUser = DiscordUser(id: id, roleIds: Set(roles), guildIds: Set([guild]))
                        if let oldUser = users[id] {
                            discordUser.roleIds.formUnion(oldUser.roleIds)
                            discordUser.guildIds.formUnion([guild])
                            users[id] = discordUser
                        } else {
                            users[id] = discordUser
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
    
}

