//
// Created by fabio on 07.02.22.
//

import Foundation
import POGOProtos

extension QuestRewardProto.TypeEnum {

    public static var allAvailable: [QuestRewardProto.TypeEnum] = [
        // .unset,
        // .experience,
        .item,
        .stardust,
        .candy,
        // .avatarClothing,
        // .quest,
        .pokemonEncounter,
        // .pokecoin,
        .xlCandy,
        // .levelCap,
        // .sticker,
        .megaResource
        // .incident
    ]
}
