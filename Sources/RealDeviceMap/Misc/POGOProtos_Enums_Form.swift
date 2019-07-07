//
//  File.swift
//  RealDeviceMap
//
//  Created by Florian Kostenzer on 17.10.18.
//

import Foundation
import POGOProtos

extension POGOProtos_Enums_Form {
    
    public static var allCases: [POGOProtos_Enums_Form] = [
        .unset,
        .unownA,
        .unownB,
        .unownC,
        .unownD,
        .unownE,
        .unownF,
        .unownG,
        .unownH,
        .unownI,
        .unownJ,
        .unownK,
        .unownL,
        .unownM,
        .unownN,
        .unownO,
        .unownP,
        .unownQ,
        .unownR,
        .unownS,
        .unownT,
        .unownU,
        .unownV,
        .unownW,
        .unownX,
        .unownY,
        .unownZ,
        .unownExclamationPoint,
        .unownQuestionMark,
        .castformNormal,
        .castformSunny,
        .castformRainy,
        .castformSnowy,
        .deoxysNormal,
        .deoxysAttack,
        .deoxysDefense,
        .deoxysSpeed,
        .spinda00,
        .spinda01,
        .spinda02,
        .spinda03,
        .spinda04,
        .spinda05,
        .spinda06,
        .spinda07,
        .rattataNormal,
        .rattataAlola,
        .raticateNormal,
        .raticateAlola,
        .raichuNormal,
        .raichuAlola,
        .sandshrewNormal,
        .sandshrewAlola,
        .sandslashNormal,
        .sandslashAlola,
        .vulpixNormal,
        .vulpixAlola,
        .ninetalesNormal,
        .ninetalesAlola,
        .diglettNormal,
        .diglettAlola,
        .dugtrioNormal,
        .dugtrioAlola,
        .meowthNormal,
        .meowthAlola,
        .persianNormal,
        .persianAlola,
        .geodudeNormal,
        .geodudeAlola,
        .gravelerNormal,
        .gravelerAlola,
        .golemNormal,
        .golemAlola,
        .grimerNormal,
        .grimerAlola,
        .mukNormal,
        .mukAlola,
        .exeggutorNormal,
        .exeggutorAlola,
        .marowakNormal,
        .marowakAlola,
        .rotomNormal,
        .rotomFrost,
        .rotomFan,
        .rotomMow,
        .rotomWash,
        .rotomHeat,
        .wormadamPlant,
        .wormadamSandy,
        .wormadamTrash,
        .giratinaAltered,
        .giratinaOrigin,
        .shayminSky,
        .shayminLand,
        .cherrimOvercast,
        .cherrimSunny,
        .shellosWestSea,
        .shellosEastSea,
        .gastrodonWestSea,
        .gastrodonEastSea,
        .arceusNormal,
        .arceusFighting,
        .arceusFlying,
        .arceusPoison,
        .arceusGround,
        .arceusRock,
        .arceusBug,
        .arceusGhost,
        .arceusSteel,
        .arceusFire,
        .arceusWater,
        .arceusGrass,
        .arceusElectric,
        .arceusPsychic,
        .arceusIce,
        .arceusDragon,
        .arceusDark,
        .arceusFairy,
        .burmyPlant,
        .burmySandy,
        .burmyTrash,
        .spinda08,
        .spinda09,
        .spinda10,
        .spinda11,
        .spinda12,
        .spinda13,
        .spinda14,
        .spinda15,
        .spinda16,
        .spinda17,
        .spinda18,
        .spinda19,
        .mewtwoA,
        .mewtwoAIntro,
        .mewtwoNormal,
    ]
    
    static var allFormsInString: [String] {
        
        var formStrings = [String]()
        for form in POGOProtos_Enums_Form.allCases {
            formStrings.append(form.formString)
        }
        return formStrings
        
    }
    
    var formString: String {
        
        switch self {
        case .unownA: return "201-1"
        case .unownB: return "201-2"
        case .unownC: return "201-3"
        case .unownD: return "201-4"
        case .unownE: return "201-5"
        case .unownF: return "201-6"
        case .unownG: return "201-7"
        case .unownH: return "201-8"
        case .unownI: return "201-9"
        case .unownJ: return "201-10"
        case .unownK: return "201-11"
        case .unownL: return "201-12"
        case .unownM: return "201-13"
        case .unownN: return "201-14"
        case .unownO: return "201-15"
        case .unownP: return "201-16"
        case .unownQ: return "201-17"
        case .unownR: return "201-18"
        case .unownS: return "201-19"
        case .unownT: return "201-20"
        case .unownU: return "201-21"
        case .unownV: return "201-22"
        case .unownW: return "201-23"
        case .unownX: return "201-24"
        case .unownY: return "201-25"
        case .unownZ: return "201-26"
        case .unownExclamationPoint: return "201-27"
        case .unownQuestionMark: return "201-28"
        case .castformNormal: return "351-29"
        case .castformSunny: return "351-30"
        case .castformRainy: return "351-31"
        case .castformSnowy: return "351-32"
        case .deoxysNormal: return "386-33"
        case .deoxysAttack: return "386-34"
        case .deoxysDefense: return "386-35"
        case .deoxysSpeed: return "386-36"
        case .spinda00: return "327-37"
        case .spinda01: return "327-38"
        case .spinda02: return "327-39"
        case .spinda03: return "327-40"
        case .spinda04: return "327-41"
        case .spinda05: return "327-42"
        case .spinda06: return "327-43"
        case .spinda07: return "327-44"
        case .rattataNormal: return "19-45"
        case .rattataAlola: return "19-46"
        case .raticateNormal: return "20-47"
        case .raticateAlola: return "20-48"
        case .raichuNormal: return "26-49"
        case .raichuAlola: return "26-50"
        case .sandshrewNormal: return "27-51"
        case .sandshrewAlola: return "27-52"
        case .sandslashNormal: return "28-53"
        case .sandslashAlola: return "28-54"
        case .vulpixNormal: return "37-55"
        case .vulpixAlola: return "37-56"
        case .ninetalesNormal: return "38-57"
        case .ninetalesAlola: return "38-58"
        case .diglettNormal: return "50-59"
        case .diglettAlola: return "50-60"
        case .dugtrioNormal: return "51-61"
        case .dugtrioAlola: return "51-62"
        case .meowthNormal: return "52-63"
        case .meowthAlola: return "52-64"
        case .persianNormal: return "53-65"
        case .persianAlola: return "53-66"
        case .geodudeNormal: return "74-67"
        case .geodudeAlola: return "74-68"
        case .gravelerNormal: return "75-69"
        case .gravelerAlola: return "75-70"
        case .golemNormal: return "76-71"
        case .golemAlola: return "76-72"
        case .grimerNormal: return "88-73"
        case .grimerAlola: return "88-74"
        case .mukNormal: return "89-75"
        case .mukAlola: return "89-76"
        case .exeggutorNormal: return "103-77"
        case .exeggutorAlola: return "103-78"
        case .marowakNormal: return "105-79"
        case .marowakAlola: return "105-80"
        case .rotomNormal: return "479-81"
        case .rotomFrost: return "479-82"
        case .rotomFan: return "479-83"
        case .rotomMow: return "479-84"
        case .rotomWash: return "479-85"
        case .rotomHeat: return "479-86"
        case .wormadamPlant: return "413-87"
        case .wormadamSandy: return "413-88"
        case .wormadamTrash: return "413-89"
        case .giratinaAltered: return "487-90"
        case .giratinaOrigin: return "487-91"
        case .shayminSky: return "492-92"
        case .shayminLand: return "492-93"
        case .cherrimOvercast: return "421-94"
        case .cherrimSunny: return "421-95"
        case .shellosWestSea: return "422-96"
        case .shellosEastSea: return "422-97"
        case .gastrodonWestSea: return "423-98"
        case .gastrodonEastSea: return "423-99"
        case .arceusNormal: return "493-100"
        case .arceusFighting: return "493-101"
        case .arceusFlying: return "493-102"
        case .arceusPoison: return "493-103"
        case .arceusGround: return "493-104"
        case .arceusRock: return "493-105"
        case .arceusBug: return "493-106"
        case .arceusGhost: return "493-107"
        case .arceusSteel: return "493-108"
        case .arceusFire: return "493-109"
        case .arceusWater: return "493-110"
        case .arceusGrass: return "493-111"
        case .arceusElectric: return "493-112"
        case .arceusPsychic: return "493-113"
        case .arceusIce: return "493-114"
        case .arceusDragon: return "493-115"
        case .arceusDark: return "493-116"
        case .arceusFairy: return "493-117"
        case .burmyPlant: return "412-118"
        case .burmySandy: return "412-119"
        case .burmyTrash: return "412-120"
        case .spinda08: return "327-121"
        case .spinda09: return "327-122"
        case .spinda10: return "327-123"
        case .spinda11: return "327-124"
        case .spinda12: return "327-125"
        case .spinda13: return "327-126"
        case .spinda14: return "327-127"
        case .spinda15: return "327-128"
        case .spinda16: return "327-129"
        case .spinda17: return "327-130"
        case .spinda18: return "327-131"
        case .spinda19: return "327-132"
        case .mewtwoA: return "150_133"
        case .mewtwoAIntro: return "150_134"
        case .mewtwoNormal: return "150_135"
        case .rattataShadow: return "19-153"
        case .rattataPurified: return "19-154"
        case .raticateShadow: return "20-155"
        case .raticatePurified: return "20-156"
        case .zubatNormal: return "41-157"
        case .zubatShadow: return "41-158"
        case .zubatPurified: return "41-159"
        case .golbatNormal: return "42-160"
        case .golbatShadow: return "42-161"
        case .golbatPurified: return "42-162"
        case .bulbasaurNormal: return "1-163"
        case .bulbasaurShadow: return "1-164"
        case .bulbasaurPurified: return "1-165"
        case .ivysaurNormal: return "2-166"
        case .ivysaurShadow: return "2-167"
        case .ivysaurPurified: return "2-168"
        case .venusaurNormal: return "3-169"
        case .venusaurShadow: return "3-170"
        case .venusaurPurified: return "3-171"
        case .charmanderNormal: return "4-172"
        case .charmanderShadow: return "4-173"
        case .charmanderPurified: return "4-174"
        case .charmeleonNormal: return "5-175"
        case .charmeleonShadow: return "5-176"
        case .charmeleonPurified: return "5-177"
        case .charizardNormal: return "6-178"
        case .charizardShadow: return "6-179"
        case .charizardPurified: return "6-180"
        case .squirtleNormal: return "7-181"
        case .squirtleShadow: return "7-182"
        case .squirtlePurified: return "7-183"
        case .wartortleNormal: return "8-184"
        case .wartortleShadow: return "8-185"
        case .wartortlePurified: return "8-186"
        case .blastoiseNormal: return "9-187"
        case .blastoiseShadow: return "9-188"
        case .blastoisePurified: return "9-189"
        case .dratiniNormal: return "147-190"
        case .dratiniShadow: return "147-191"
        case .dratiniPurified: return "147-192"
        case .dragonairNormal: return "148-193"
        case .dragonairShadow: return "148-194"
        case .dragonairPurified: return "148-195"
        case .dragoniteNormal: return "149-196"
        case .dragoniteShadow: return "149-197"
        case .dragonitePurified: return "149-198"
        case .snorlaxNormal: return "143-199"
        case .snorlaxShadow: return "143-200"
        case .snorlaxPurified: return "143-201"
        case .crobatNormal: return "169-202"
        case .crobatShadow: return "169-203"
        case .crobatPurified: return "169-204"
        case .mudkipNormal: return "258-205"
        case .mudkipShadow: return "258-206"
        case .mudkipPurified: return "258-207"
        case .marshtompNormal: return "259-208"
        case .marshtompShadow: return "259-209"
        case .marshtompPurified: return "259-210"
        case .swampertNormal: return "260-211"
        case .swampertShadow: return "260-212"
        case .swampertPurified: return "260-213"
        case .pikachuNormal: return "25-598"
        case .pikachuNoevolve: return "25-599"
        case .wurmpleNormal: return "265-600"
        case .wurmpleNoevolve: return "265-601"
        case .wobbuffetNormal: return "202-602"
        case .wobbuffetNoevolve: return "202-603"
        case .bulbasaurNoevolve: return "1-604"
        case .charmanderNoevolve: return "4-605"
        case .charizardNoevolve: return "5-606"
        case .squirtleNoevolve: return "7-607"
        case .blastoiseNoevolve: return "9-608"
        case .raticateNoevolve: return "20-609"
        case .unset:
            return ""
        case .UNRECOGNIZED(_):
            return ""
        }
        
    }
    
}
