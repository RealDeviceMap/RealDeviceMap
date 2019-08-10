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
        //.mewtwoAIntro,
        .mewtwoNormal,
        .rattataShadow,
        .rattataPurified,
        .raticateShadow,
        .raticatePurified,
        .zubatNormal,
        .zubatShadow,
        .zubatPurified,
        .golbatNormal,
        .golbatShadow,
        .golbatPurified,
        .bulbasaurNormal,
        .bulbasaurShadow,
        .bulbasaurPurified,
        .ivysaurNormal,
        .ivysaurShadow,
        .ivysaurPurified,
        .venusaurNormal,
        .venusaurShadow,
        .venusaurPurified,
        .charmanderNormal,
        .charmanderShadow,
        .charmanderPurified,
        .charmeleonNormal,
        .charmeleonShadow,
        .charmeleonPurified,
        .charizardNormal,
        .charizardShadow,
        .charizardPurified,
        .squirtleNormal,
        .squirtleShadow,
        .squirtlePurified,
        .wartortleNormal,
        .wartortleShadow,
        .wartortlePurified,
        .blastoiseNormal,
        .blastoiseShadow,
        .blastoisePurified,
        .dratiniNormal,
        .dratiniShadow,
        .dratiniPurified,
        .dragonairNormal,
        .dragonairShadow,
        .dragonairPurified,
        .dragoniteNormal,
        .dragoniteShadow,
        .dragonitePurified,
        .snorlaxNormal,
        .snorlaxShadow,
        .snorlaxPurified,
        .crobatNormal,
        .crobatShadow,
        .crobatPurified,
        .mudkipNormal,
        .mudkipShadow,
        .mudkipPurified,
        .marshtompNormal,
        .marshtompShadow,
        .marshtompPurified,
        .swampertNormal,
        .swampertShadow,
        .swampertPurified,
        .drowzeeNormal,
        .drowzeeShadow,
        .drowzeePurified,
        .hypnoNormal,
        .hypnoShadow,
        .hypnoPurified,
        .grimerShadow,
        .grimerPurified,
        .mukShadow,
        .mukPurified,
        .cuboneNormal,
        .cuboneShadow,
        .cubonePurified,
        .marowakShadow,
        .marowakPurified,
        .houndourNormal,
        .houndourShadow,
        .houndourPurified,
        .houndoomNormal,
        .houndoomShadow,
        .houndoomPurified,
        .poliwagNormal,
        .poliwagShadow,
        .poliwagPurified,
        .poliwhirlNormal,
        .poliwhirlShadow,
        .poliwhirlPurified,
        .poliwrathNormal,
        .poliwrathShadow,
        .poliwrathPurified,
        .politoedNormal,
        .politoedShadow,
        .politoedPurified,
        .scytherNormal,
        .scytherShadow,
        .scytherPurified,
        .scizorNormal,
        .scizorShadow,
        .scizorPurified,
        .magikarpNormal,
        .magikarpShadow,
        .magikarpPurified,
        .gyaradosNormal,
        .gyaradosShadow,
        .gyaradosPurified,
        .venonatNormal,
        .venonatShadow,
        .venonatPurified,
        .venomothNormal,
        .venomothShadow,
        .venomothPurified,
        .oddishNormal,
        .oddishShadow,
        .oddishPurified,
        .gloomNormal,
        .gloomShadow,
        .gloomPurified,
        .vileplumeNormal,
        .vileplumeShadow,
        .vileplumePurified,
        .bellossomNormal,
        .bellossomShadow,
        .bellossomPurified,
        .hitmonchanNormal,
        .hitmonchanShadow,
        .hitmonchanPurified,
        .growlitheNormal,
        .growlitheShadow,
        .growlithePurified,
        .arcanineNormal,
        .arcanineShadow,
        .arcaninePurified,
        .psyduckNormal,
        .psyduckShadow,
        .psyduckPurified,
        .golduckNormal,
        .golduckShadow,
        .golduckPurified,
        .raltsNormal,
        .raltsShadow,
        .raltsPurified,
        .kirliaNormal,
        .kirliaShadow,
        .kirliaPurified,
        .gardevoirNormal,
        .gardevoirShadow,
        .gardevoirPurified,
        .galladeNormal,
        .galladeShadow,
        .galladePurified,
        .abraNormal,
        .abraShadow,
        .abraPurified,
        .kadabraNormal,
        .kadabraShadow,
        .kadabraPurified,
        .alakazamNormal,
        .alakazamShadow,
        .alakazamPurified,
        .larvitarNormal,
        .larvitarShadow,
        .larvitarPurified,
        .pupitarNormal,
        .pupitarShadow,
        .pupitarPurified,
        .tyranitarNormal,
        .tyranitarShadow,
        .tyranitarPurified,
        .laprasNormal,
        .laprasShadow,
        .laprasPurified,
        .pikachuNormal,
        //.pikachuNoevolve,
        .wurmpleNormal,
        //.wurmpleNoevolve,
        .wobbuffetNormal,
        //.wobbuffetNoevolve,
        //.bulbasaurNoevolve,
        //.charmanderNoevolve,
        //.charizardNoevolve,
        //.squirtleNoevolve,
        //.blastoiseNoevolve,
        //.raticateNoevolve,
        .cacneaNormal,
        .cacneaShadow,
        .cacneaPurified,
        .cacturneNormal,
        .cacturneShadow,
        .cacturnePurified,
        .weedleNormal,
        .weedleShadow,
        .weedlePurified,
        .kakunaNormal,
        .kakunaShadow,
        .kakunaPurified,
        .beedrillNormal,
        .beedrillShadow,
        .beedrillPurified,
        .seedotNormal,
        .seedotShadow,
        .seedotPurified,
        .nuzleafNormal,
        .nuzleafShadow,
        .nuzleafPurified,
        .shiftryNormal,
        .shiftryShadow,
        .shiftryPurified,
        .magmarNormal,
        .magmarShadow,
        .magmarPurified,
        .magmortarNormal,
        .magmortarShadow,
        .magmortarPurified,
        .electabuzzNormal,
        .electabuzzShadow,
        .electabuzzPurified,
        .electivireNormal,
        .electivireShadow,
        .electivirePurified,
        .mareepNormal,
        .mareepShadow,
        .mareepPurified,
        .flaaffyNormal,
        .flaaffyShadow,
        .flaaffyPurified,
        .ampharosNormal,
        .ampharosShadow,
        .ampharosPurified,
        .magnemiteNormal,
        .magnemiteShadow,
        .magnemitePurified,
        .magnetonNormal,
        .magnetonShadow,
        .magnetonPurified,
        .magnezoneNormal,
        .magnezoneShadow,
        .magnezonePurified,
        .bellsproutNormal,
        .bellsproutShadow,
        .bellsproutPurified,
        .weepinbellNormal,
        .weepinbellShadow,
        .weepinbellPurified,
        .victreebelNormal,
        .victreebelShadow,
        .victreebelPurified,
        .sandshrewShadow,
        .sandshrewPurified,
        .sandslashShadow,
        .sandslashPurified,
        .porygonNormal,
        .porygonShadow,
        .porygonPurified,
        .porygon2Normal,
        .porygon2Shadow,
        .porygon2Purified,
        .porygonZNormal,
        .porygonZShadow,
        .porygonZPurified,
        .wobbuffetShadow,
        .wobbuffetPurified,
        .turtwigNormal,
        .turtwigShadow,
        .turtwigPurified,
        .grotleNormal,
        .grotleShadow,
        .grotlePurified,
        .torterraNormal,
        .torterraShadow,
        .torterraPurified,
        .ekansNormal,
        .ekansShadow,
        .ekansPurified,
        .arbokNormal,
        .arbokShadow,
        .arbokPurified,
        .koffingNormal,
        .koffingShadow,
        .koffingPurified,
        .weezingNormal,
        .weezingShadow,
        .weezingPurified,
        .meowthShadow,
        .meowthPurified,
        .persianShadow,
        .persianPurified,
        .hitmonleeNormal,
        .hitmonleeShadow,
        .hitmonleePurified,
        .articunoNormal,
        .articunoShadow,
        .articunoPurified,
        .misdreavusNormal,
        .misdreavusShadow,
        .misdreavusPurified,
        .mismagiusNormal,
        .mismagiusShadow,
        .mismagiusPurified,
        .vulpixShadow,
        .vulpixPurified,
        .ninetalesShadow,
        .ninetalesPurified,
        .exeggcuteNormal,
        .exeggcuteShadow,
        .exeggcutePurified,
        .exeggutorShadow,
        .exeggutorPurified,
        .carvanhaNormal,
        .carvanhaShadow,
        .carvanhaPurified,
        .sharpedoNormal,
        .sharpedoShadow,
        .sharpedoPurified,
        .omanyteNormal,
        .omanyteShadow,
        .omanytePurified,
        .omastarNormal,
        .omastarShadow,
        .omastarPurified,
        .trapinchNormal,
        .trapinchShadow,
        .trapinchPurified,
        .vibravaNormal,
        .vibravaShadow,
        .vibravaPurified,
        .flygonNormal,
        .flygonShadow,
        .flygonPurified,
        .bagonNormal,
        .bagonShadow,
        .bagonPurified,
        .shelgonNormal,
        .shelgonShadow,
        .shelgonPurified,
        .salamenceNormal,
        .salamenceShadow,
        .salamencePurified,
        .beldumNormal,
        .beldumShadow,
        .beldumPurified,
        .metangNormal,
        .metangShadow,
        .metangPurified,
        .metagrossNormal,
        .metagrossShadow,
        .metagrossPurified,
        .zapdosNormal,
        .zapdosShadow,
        .zapdosPurified,
        .nidoranNormal,
        .nidoranShadow,
        .nidoranPurified,
        .nidorinaNormal,
        .nidorinaShadow,
        .nidorinaPurified,
        .nidoqueenNormal,
        .nidoqueenShadow,
        .nidoqueenPurified,
        .nidorinoNormal,
        .nidorinoShadow,
        .nidorinoPurified,
        .nidokingNormal,
        .nidokingShadow,
        .nidokingPurified,
        .stunkyNormal,
        .stunkyShadow,
        .stunkyPurified,
        .skuntankNormal,
        .skuntankShadow,
        .skuntankPurified,
        .sneaselNormal,
        .sneaselShadow,
        .sneaselPurified,
        .weavileNormal,
        .weavileShadow,
        .weavilePurified,
        .gligarNormal,
        .gligarShadow,
        .gligarPurified,
        .gliscorNormal,
        .gliscorShadow,
        .gliscorPurified,
        .machopNormal,
        .machopShadow,
        .machopPurified,
        .machokeNormal,
        .machokeShadow,
        .machokePurified,
        .machampNormal,
        .machampShadow,
        .machampPurified,
        .chimcharNormal,
        .chimcharShadow,
        .chimcharPurified,
        .monfernoNormal,
        .monfernoShadow,
        .monfernoPurified,
        .infernapeNormal,
        .infernapeShadow,
        .infernapePurified,
        .shuckleNormal,
        .shuckleShadow,
        .shucklePurified,
        .absolNormal,
        .absolShadow,
        .absolPurified,
        .mawileNormal,
        .mawileShadow,
        .mawilePurified,
        .moltresNormal,
        .moltresShadow,
        .moltresPurified,
        .kangaskhanNormal,
        .kangaskhanShadow,
        .kangaskhanPurified,
        .diglettShadow,
        .diglettPurified,
        .dugtrioShadow,
        .dugtrioPurified,
        .rhyhornNormal,
        .rhyhornShadow,
        .rhyhornPurified,
        .rhydonNormal,
        .rhydonShadow,
        .rhydonPurified,
        .rhyperiorNormal,
        .rhyperiorShadow,
        .rhyperiorPurified,
        .murkrowNormal,
        .murkrowShadow,
        .murkrowPurified,
        .honchkrowNormal,
        .honchkrowShadow,
        .honchkrowPurified,
        .gibleNormal,
        .gibleShadow,
        .giblePurified,
        .gabiteNormal,
        .gabiteShadow,
        .gabitePurified,
        .garchompNormal,
        .garchompShadow,
        .garchompPurified,
        .krabbyNormal,
        .krabbyShadow,
        .krabbyPurified,
        .kinglerNormal,
        .kinglerShadow,
        .kinglerPurified,
        .shellderNormal,
        .shellderShadow,
        .shellderPurified,
        .cloysterNormal,
        .cloysterShadow,
        .cloysterPurified,
        .geodudeShadow,
        .geodudePurified,
        .gravelerShadow,
        .gravelerPurified,
        .golemShadow,
        .golemPurified,
        .hippopotasNormal,
        .hippopotasShadow,
        .hippopotasPurified,
        .hippowdonNormal,
        .hippowdonShadow,
        .hippowdonPurified,
        .pikachuFall,
        .squirtleFall,
        .charmanderFall,
        .bulbasaurFall
    ]
    
    static var allFormsInString: [String] {
        var formStrings = [String]()
        for form in POGOProtos_Enums_Form.allCases {
            for formString in form.formStrings {
                formStrings.append(formString)
            }
        }
        return formStrings
    }
    
    var formStrings: [String] {
        switch self {
        case .unownA: return ["201-1"]
        case .unownB: return ["201-2"]
        case .unownC: return ["201-3"]
        case .unownD: return ["201-4"]
        case .unownE: return ["201-5"]
        case .unownF: return ["201-6"]
        case .unownG: return ["201-7"]
        case .unownH: return ["201-8"]
        case .unownI: return ["201-9"]
        case .unownJ: return ["201-10"]
        case .unownK: return ["201-11"]
        case .unownL: return ["201-12"]
        case .unownM: return ["201-13"]
        case .unownN: return ["201-14"]
        case .unownO: return ["201-15"]
        case .unownP: return ["201-16"]
        case .unownQ: return ["201-17"]
        case .unownR: return ["201-18"]
        case .unownS: return ["201-19"]
        case .unownT: return ["201-20"]
        case .unownU: return ["201-21"]
        case .unownV: return ["201-22"]
        case .unownW: return ["201-23"]
        case .unownX: return ["201-24"]
        case .unownY: return ["201-25"]
        case .unownZ: return ["201-26"]
        case .unownExclamationPoint: return ["201-27"]
        case .unownQuestionMark: return ["201-28"]
        case .castformNormal: return ["351-29"]
        case .castformSunny: return ["351-30"]
        case .castformRainy: return ["351-31"]
        case .castformSnowy: return ["351-32"]
        case .deoxysNormal: return ["386-33"]
        case .deoxysAttack: return ["386-34"]
        case .deoxysDefense: return ["386-35"]
        case .deoxysSpeed: return ["386-36"]
        case .spinda00: return ["327-37"]
        case .spinda01: return ["327-38"]
        case .spinda02: return ["327-39"]
        case .spinda03: return ["327-40"]
        case .spinda04: return ["327-41"]
        case .spinda05: return ["327-42"]
        case .spinda06: return ["327-43"]
        case .spinda07: return ["327-44"]
        case .rattataNormal: return ["19-45"]
        case .rattataAlola: return ["19-46"]
        case .raticateNormal: return ["20-47"]
        case .raticateAlola: return ["20-48"]
        case .raichuNormal: return ["26-49"]
        case .raichuAlola: return ["26-50"]
        case .sandshrewNormal: return ["27-51"]
        case .sandshrewAlola: return ["27-52"]
        case .sandslashNormal: return ["28-53"]
        case .sandslashAlola: return ["28-54"]
        case .vulpixNormal: return ["37-55"]
        case .vulpixAlola: return ["37-56"]
        case .ninetalesNormal: return ["38-57"]
        case .ninetalesAlola: return ["38-58"]
        case .diglettNormal: return ["50-59"]
        case .diglettAlola: return ["50-60"]
        case .dugtrioNormal: return ["51-61"]
        case .dugtrioAlola: return ["51-62"]
        case .meowthNormal: return ["52-63"]
        case .meowthAlola: return ["52-64"]
        case .persianNormal: return ["53-65"]
        case .persianAlola: return ["53-66"]
        case .geodudeNormal: return ["74-67"]
        case .geodudeAlola: return ["74-68"]
        case .gravelerNormal: return ["75-69"]
        case .gravelerAlola: return ["75-70"]
        case .golemNormal: return ["76-71"]
        case .golemAlola: return ["76-72"]
        case .grimerNormal: return ["88-73"]
        case .grimerAlola: return ["88-74"]
        case .mukNormal: return ["89-75"]
        case .mukAlola: return ["89-76"]
        case .exeggutorNormal: return ["103-77"]
        case .exeggutorAlola: return ["103-78"]
        case .marowakNormal: return ["105-79"]
        case .marowakAlola: return ["105-80"]
        case .rotomNormal: return ["479-81"]
        case .rotomFrost: return ["479-82"]
        case .rotomFan: return ["479-83"]
        case .rotomMow: return ["479-84"]
        case .rotomWash: return ["479-85"]
        case .rotomHeat: return ["479-86"]
        case .wormadamPlant: return ["413-87"]
        case .wormadamSandy: return ["413-88"]
        case .wormadamTrash: return ["413-89"]
        case .giratinaAltered: return ["487-90"]
        case .giratinaOrigin: return ["487-91"]
        case .shayminSky: return ["492-92"]
        case .shayminLand: return ["492-93"]
        case .cherrimOvercast: return ["421-94"]
        case .cherrimSunny: return ["421-95"]
        case .shellosWestSea: return ["422-96"]
        case .shellosEastSea: return ["422-97"]
        case .gastrodonWestSea: return ["423-98"]
        case .gastrodonEastSea: return ["423-99"]
        case .arceusNormal: return ["493-100"]
        case .arceusFighting: return ["493-101"]
        case .arceusFlying: return ["493-102"]
        case .arceusPoison: return ["493-103"]
        case .arceusGround: return ["493-104"]
        case .arceusRock: return ["493-105"]
        case .arceusBug: return ["493-106"]
        case .arceusGhost: return ["493-107"]
        case .arceusSteel: return ["493-108"]
        case .arceusFire: return ["493-109"]
        case .arceusWater: return ["493-110"]
        case .arceusGrass: return ["493-111"]
        case .arceusElectric: return ["493-112"]
        case .arceusPsychic: return ["493-113"]
        case .arceusIce: return ["493-114"]
        case .arceusDragon: return ["493-115"]
        case .arceusDark: return ["493-116"]
        case .arceusFairy: return ["493-117"]
        case .burmyPlant: return ["412-118"]
        case .burmySandy: return ["412-119"]
        case .burmyTrash: return ["412-120"]
        case .spinda08: return ["327-121"]
        case .spinda09: return ["327-122"]
        case .spinda10: return ["327-123"]
        case .spinda11: return ["327-124"]
        case .spinda12: return ["327-125"]
        case .spinda13: return ["327-126"]
        case .spinda14: return ["327-127"]
        case .spinda15: return ["327-128"]
        case .spinda16: return ["327-129"]
        case .spinda17: return ["327-130"]
        case .spinda18: return ["327-131"]
        case .spinda19: return ["327-132"]
        case .mewtwoA: return ["150-133"]
        //case .mewtwoAIntro: return ["150-134"]
        case .mewtwoNormal: return ["150-135"]
        case .rattataShadow: return ["19-153"]
        case .rattataPurified: return ["19-154"]
        case .raticateShadow: return ["20-155"]
        case .raticatePurified: return ["20-156"]
        case .zubatNormal: return ["41-157"]
        case .zubatShadow: return ["41-158"]
        case .zubatPurified: return ["41-159"]
        case .golbatNormal: return ["42-160"]
        case .golbatShadow: return ["42-161"]
        case .golbatPurified: return ["42-162"]
        case .bulbasaurNormal: return ["1-163"]
        case .bulbasaurShadow: return ["1-164"]
        case .bulbasaurPurified: return ["1-165"]
        case .ivysaurNormal: return ["2-166"]
        case .ivysaurShadow: return ["2-167"]
        case .ivysaurPurified: return ["2-168"]
        case .venusaurNormal: return ["3-169"]
        case .venusaurShadow: return ["3-170"]
        case .venusaurPurified: return ["3-171"]
        case .charmanderNormal: return ["4-172"]
        case .charmanderShadow: return ["4-173"]
        case .charmanderPurified: return ["4-174"]
        case .charmeleonNormal: return ["5-175"]
        case .charmeleonShadow: return ["5-176"]
        case .charmeleonPurified: return ["5-177"]
        case .charizardNormal: return ["6-178"]
        case .charizardShadow: return ["6-179"]
        case .charizardPurified: return ["6-180"]
        case .squirtleNormal: return ["7-181"]
        case .squirtleShadow: return ["7-182"]
        case .squirtlePurified: return ["7-183"]
        case .wartortleNormal: return ["8-184"]
        case .wartortleShadow: return ["8-185"]
        case .wartortlePurified: return ["8-186"]
        case .blastoiseNormal: return ["9-187"]
        case .blastoiseShadow: return ["9-188"]
        case .blastoisePurified: return ["9-189"]
        case .dratiniNormal: return ["147-190"]
        case .dratiniShadow: return ["147-191"]
        case .dratiniPurified: return ["147-192"]
        case .dragonairNormal: return ["148-193"]
        case .dragonairShadow: return ["148-194"]
        case .dragonairPurified: return ["148-195"]
        case .dragoniteNormal: return ["149-196"]
        case .dragoniteShadow: return ["149-197"]
        case .dragonitePurified: return ["149-198"]
        case .snorlaxNormal: return ["143-199"]
        case .snorlaxShadow: return ["143-200"]
        case .snorlaxPurified: return ["143-201"]
        case .crobatNormal: return ["169-202"]
        case .crobatShadow: return ["169-203"]
        case .crobatPurified: return ["169-204"]
        case .mudkipNormal: return ["258-205"]
        case .mudkipShadow: return ["258-206"]
        case .mudkipPurified: return ["258-207"]
        case .marshtompNormal: return ["259-208"]
        case .marshtompShadow: return ["259-209"]
        case .marshtompPurified: return ["259-210"]
        case .swampertNormal: return ["260-211"]
        case .swampertShadow: return ["260-212"]
        case .swampertPurified: return ["260-213"]
        case .drowzeeNormal: return ["96-214"]
        case .drowzeeShadow: return ["96-215"]
        case .drowzeePurified: return ["96-216"]
        case .hypnoNormal: return ["97-217"]
        case .hypnoShadow: return ["97-218"]
        case .hypnoPurified: return ["97-219"]
        case .grimerShadow: return ["88-220"]
        case .grimerPurified: return ["88-221"]
        case .mukShadow: return ["89-222"]
        case .mukPurified: return ["89-223"]
        case .cuboneNormal: return ["104-224"]
        case .cuboneShadow: return ["104-225"]
        case .cubonePurified: return ["104-226"]
        case .marowakShadow: return ["105-227"]
        case .marowakPurified: return ["105-228"]
        case .houndourNormal: return ["228-229"]
        case .houndourShadow: return ["228-230"]
        case .houndourPurified: return ["228-231"]
        case .houndoomNormal: return ["229-232"]
        case .houndoomShadow: return ["229-233"]
        case .houndoomPurified: return ["229-234"]
        case .poliwagNormal: return ["60-235"]
        case .poliwagShadow: return ["60-236"]
        case .poliwagPurified: return ["60-237"]
        case .poliwhirlNormal: return ["61-238"]
        case .poliwhirlShadow: return ["61-239"]
        case .poliwhirlPurified: return ["61-240"]
        case .poliwrathNormal: return ["62-241"]
        case .poliwrathShadow: return ["62-242"]
        case .poliwrathPurified: return ["62-243"]
        case .politoedNormal: return ["186-244"]
        case .politoedShadow: return ["186-245"]
        case .politoedPurified: return ["186-246"]
        case .scytherNormal: return ["123-247"]
        case .scytherShadow: return ["123-248"]
        case .scytherPurified: return ["123-249"]
        case .scizorNormal: return ["212-250"]
        case .scizorShadow: return ["212-251"]
        case .scizorPurified: return ["212-252"]
        case .magikarpNormal: return ["129-253"]
        case .magikarpShadow: return ["129-254"]
        case .magikarpPurified: return ["129-255"]
        case .gyaradosNormal: return ["130-256"]
        case .gyaradosShadow: return ["130-257"]
        case .gyaradosPurified: return ["130-258"]
        case .venonatNormal: return ["48-259"]
        case .venonatShadow: return ["48-260"]
        case .venonatPurified: return ["48-261"]
        case .venomothNormal: return ["49-262"]
        case .venomothShadow: return ["49-263"]
        case .venomothPurified: return ["49-264"]
        case .oddishNormal: return ["43-265"]
        case .oddishShadow: return ["43-266"]
        case .oddishPurified: return ["43-267"]
        case .gloomNormal: return ["44-268"]
        case .gloomShadow: return ["44-269"]
        case .gloomPurified: return ["44-270"]
        case .vileplumeNormal: return ["45-271"]
        case .vileplumeShadow: return ["45-272"]
        case .vileplumePurified: return ["45-273"]
        case .bellossomNormal: return ["182-274"]
        case .bellossomShadow: return ["182-275"]
        case .bellossomPurified: return ["182-276"]
        case .hitmonchanNormal: return ["107-277"]
        case .hitmonchanShadow: return ["107-278"]
        case .hitmonchanPurified: return ["107-279"]
        case .growlitheNormal: return ["58-280"]
        case .growlitheShadow: return ["58-281"]
        case .growlithePurified: return ["58-282"]
        case .arcanineNormal: return ["59-283"]
        case .arcanineShadow: return ["59-284"]
        case .arcaninePurified: return ["59-285"]
        case .psyduckNormal: return ["54-286"]
        case .psyduckShadow: return ["54-287"]
        case .psyduckPurified: return ["54-288"]
        case .golduckNormal: return ["55-289"]
        case .golduckShadow: return ["55-290"]
        case .golduckPurified: return ["55-291"]
        case .raltsNormal: return ["280-292"]
        case .raltsShadow: return ["280-293"]
        case .raltsPurified: return ["280-294"]
        case .kirliaNormal: return ["281-295"]
        case .kirliaShadow: return ["281-296"]
        case .kirliaPurified: return ["281-297"]
        case .gardevoirNormal: return ["282-298"]
        case .gardevoirShadow: return ["282-299"]
        case .gardevoirPurified: return ["282-300"]
        case .galladeNormal: return ["475-301"]
        case .galladeShadow: return ["475-302"]
        case .galladePurified: return ["475-303"]
        case .abraNormal: return ["63-304"]
        case .abraShadow: return ["63-305"]
        case .abraPurified: return ["63-306"]
        case .kadabraNormal: return ["63-307"]
        case .kadabraShadow: return ["63-308"]
        case .kadabraPurified: return ["63-309"]
        case .alakazamNormal: return ["65-310"]
        case .alakazamShadow: return ["65-311"]
        case .alakazamPurified: return ["65-312"]
        case .larvitarNormal: return ["246-313"]
        case .larvitarShadow: return ["246-314"]
        case .larvitarPurified: return ["246-315"]
        case .pupitarNormal: return ["247-316"]
        case .pupitarShadow: return ["247-317"]
        case .pupitarPurified: return ["247-318"]
        case .tyranitarNormal: return ["248-319"]
        case .tyranitarShadow: return ["248-320"]
        case .tyranitarPurified: return ["248-321"]
        case .laprasNormal: return ["131-322"]
        case .laprasShadow: return ["131-323"]
        case .laprasPurified: return ["131-324"]
        case .pikachuNormal: return ["25-598"]
        //case .pikachuNoevolve: return ["25-599"]
        case .wurmpleNormal: return ["265-600"]
        //case .wurmpleNoevolve: return ["265-601"]
        case .wobbuffetNormal: return ["202-602"]
            //case .wobbuffetNoevolve: return ["202-603"]
            //case .bulbasaurNoevolve: return ["1-604"]
            //case .charmanderNoevolve: return ["4-605"]
            //case .charizardNoevolve: return ["6-606"]
            //case .squirtleNoevolve: return ["7-607"]
            //case .blastoiseNoevolve: return ["9-608"]
        //case .raticateNoevolve: return ["20-609"]
        case .cacneaNormal: return ["331-610"]
        case .cacneaShadow: return ["331-611"]
        case .cacneaPurified: return ["331-612"]
        case .cacturneNormal: return ["332-613"]
        case .cacturneShadow: return ["332-614"]
        case .cacturnePurified: return ["332-615"]
        case .weedleNormal: return ["13-616"]
        case .weedleShadow: return ["13-617"]
        case .weedlePurified: return ["13-618"]
        case .kakunaNormal: return ["14-619"]
        case .kakunaShadow: return ["14-620"]
        case .kakunaPurified: return ["14-621"]
        case .beedrillNormal: return ["15-622"]
        case .beedrillShadow: return ["15-623"]
        case .beedrillPurified: return ["15-624"]
        case .seedotNormal: return ["273-625"]
        case .seedotShadow: return ["273-626"]
        case .seedotPurified: return ["273-627"]
        case .nuzleafNormal: return ["274-628"]
        case .nuzleafShadow: return ["274-629"]
        case .nuzleafPurified: return ["274-630"]
        case .shiftryNormal: return ["275-631"]
        case .shiftryShadow: return ["275-632"]
        case .shiftryPurified: return ["275-633"]
        case .magmarNormal: return ["126-634"]
        case .magmarShadow: return ["126-635"]
        case .magmarPurified: return ["126-636"]
        case .magmortarNormal: return ["467-637"]
        case .magmortarShadow: return ["467-638"]
        case .magmortarPurified: return ["467-639"]
        case .electabuzzNormal: return ["125-640"]
        case .electabuzzShadow: return ["125-641"]
        case .electabuzzPurified: return ["125-642"]
        case .electivireNormal: return ["466-643"]
        case .electivireShadow: return ["466-644"]
        case .electivirePurified: return ["466-645"]
        case .mareepNormal: return ["179-646"]
        case .mareepShadow: return ["179-647"]
        case .mareepPurified: return ["179-648"]
        case .flaaffyNormal: return ["180-649"]
        case .flaaffyShadow: return ["180-650"]
        case .flaaffyPurified: return ["180-651"]
        case .ampharosNormal: return ["181-652"]
        case .ampharosShadow: return ["181-653"]
        case .ampharosPurified: return ["181-654"]
        case .magnemiteNormal: return ["81-655"]
        case .magnemiteShadow: return ["81-656"]
        case .magnemitePurified: return ["81-657"]
        case .magnetonNormal: return ["82-658"]
        case .magnetonShadow: return ["82-659"]
        case .magnetonPurified: return ["82-660"]
        case .magnezoneNormal: return ["462-661"]
        case .magnezoneShadow: return ["462-662"]
        case .magnezonePurified: return ["462-663"]
        case .bellsproutNormal: return ["69-664"]
        case .bellsproutShadow: return ["69-665"]
        case .bellsproutPurified: return ["69-666"]
        case .weepinbellNormal: return ["70-667"]
        case .weepinbellShadow: return ["70-668"]
        case .weepinbellPurified: return ["70-669"]
        case .victreebelNormal: return ["71-670"]
        case .victreebelShadow: return ["71-671"]
        case .victreebelPurified: return ["71-672"]
        case .sandshrewShadow: return ["27-673"]
        case .sandshrewPurified: return ["27-674"]
        case .sandslashShadow: return ["28-675"]
        case .sandslashPurified: return ["28-676"]
        case .porygonNormal: return ["137-677"]
        case .porygonShadow: return ["137-678"]
        case .porygonPurified: return ["137-679"]
        case .porygon2Normal: return ["137-680"]
        case .porygon2Shadow: return ["137-681"]
        case .porygon2Purified: return ["137-682"]
        case .porygonZNormal: return ["137-683"]
        case .porygonZShadow: return ["137-684"]
        case .porygonZPurified: return ["137-685"]
        case .wobbuffetShadow: return ["202-686"]
        case .wobbuffetPurified: return ["202-687"]
        case .turtwigNormal: return ["387-688"]
        case .turtwigShadow: return ["387-689"]
        case .turtwigPurified: return ["387-690"]
        case .grotleNormal: return ["388-691"]
        case .grotleShadow: return ["388-692"]
        case .grotlePurified: return ["388-693"]
        case .torterraNormal: return ["389-694"]
        case .torterraShadow: return ["389-695"]
        case .torterraPurified: return ["389-696"]
        case .ekansNormal: return ["23-697"]
        case .ekansShadow: return ["23-698"]
        case .ekansPurified: return ["23-699"]
        case .arbokNormal: return ["24-700"]
        case .arbokShadow: return ["24-701"]
        case .arbokPurified: return ["24-702"]
        case .koffingNormal: return ["109-703"]
        case .koffingShadow: return ["109-704"]
        case .koffingPurified: return ["109-705"]
        case .weezingNormal: return ["110-706"]
        case .weezingShadow: return ["110-707"]
        case .weezingPurified: return ["110-708"]
        case .meowthShadow: return ["52-709"]
        case .meowthPurified: return ["52-710"]
        case .persianShadow: return ["53-711"]
        case .persianPurified: return ["53-712"]
        case .hitmonleeNormal: return ["106-713"]
        case .hitmonleeShadow: return ["106-714"]
        case .hitmonleePurified: return ["106-715"]
        case .articunoNormal: return ["144-716"]
        case .articunoShadow: return ["144-717"]
        case .articunoPurified: return ["144-718"]
        case .misdreavusNormal: return ["200-719"]
        case .misdreavusShadow: return ["200-720"]
        case .misdreavusPurified: return ["200-721"]
        case .mismagiusNormal: return ["429-722"]
        case .mismagiusShadow: return ["429-723"]
        case .mismagiusPurified: return ["429-724"]
        case .vulpixShadow: return ["37-725"]
        case .vulpixPurified: return ["37-726"]
        case .ninetalesShadow: return ["38-727"]
        case .ninetalesPurified: return ["38-728"]
        case .exeggcuteNormal: return ["102-729"]
        case .exeggcuteShadow: return ["102-730"]
        case .exeggcutePurified: return ["102-731"]
        case .exeggutorShadow: return ["103-732"]
        case .exeggutorPurified: return ["103-733"]
        case .carvanhaNormal: return ["318-734"]
        case .carvanhaShadow: return ["318-735"]
        case .carvanhaPurified: return ["318-736"]
        case .sharpedoNormal: return ["319-737"]
        case .sharpedoShadow: return ["319-738"]
        case .sharpedoPurified: return ["319-739"]
        case .omanyteNormal: return ["138-740"]
        case .omanyteShadow: return ["138-741"]
        case .omanytePurified: return ["138-742"]
        case .omastarNormal: return ["139-743"]
        case .omastarShadow: return ["139-744"]
        case .omastarPurified: return ["139-745"]
        case .trapinchNormal: return ["328-746"]
        case .trapinchShadow: return ["328-747"]
        case .trapinchPurified: return ["328-748"]
        case .vibravaNormal: return ["329-749"]
        case .vibravaShadow: return ["329-750"]
        case .vibravaPurified: return ["329-751"]
        case .flygonNormal: return ["330-752"]
        case .flygonShadow: return ["330-753"]
        case .flygonPurified: return ["330-754"]
        case .bagonNormal: return ["371-755"]
        case .bagonShadow: return ["371-756"]
        case .bagonPurified: return ["371-757"]
        case .shelgonNormal: return ["372-758"]
        case .shelgonShadow: return ["372-759"]
        case .shelgonPurified: return ["372-760"]
        case .salamenceNormal: return ["373-761"]
        case .salamenceShadow: return ["373-762"]
        case .salamencePurified: return ["373-763"]
        case .beldumNormal: return ["374-764"]
        case .beldumShadow: return ["374-765"]
        case .beldumPurified: return ["374-766"]
        case .metangNormal: return ["375-767"]
        case .metangShadow: return ["375-768"]
        case .metangPurified: return ["375-769"]
        case .metagrossNormal: return ["376-770"]
        case .metagrossShadow: return ["376-771"]
        case .metagrossPurified: return ["376-772"]
        case .zapdosNormal: return ["145-773"]
        case .zapdosShadow: return ["145-774"]
        case .zapdosPurified: return ["145-775"]
        case .nidoranNormal: return ["29-776", "32-776"]
        case .nidoranShadow: return ["29-777", "32-777"]
        case .nidoranPurified: return ["29-778", "32-778"]
        case .nidorinaNormal: return ["30-779"]
        case .nidorinaShadow: return ["30-780"]
        case .nidorinaPurified: return ["30-781"]
        case .nidoqueenNormal: return ["31-782"]
        case .nidoqueenShadow: return ["31-783"]
        case .nidoqueenPurified: return ["31-784"]
        case .nidorinoNormal: return ["33-785"]
        case .nidorinoShadow: return ["33-786"]
        case .nidorinoPurified: return ["33-787"]
        case .nidokingNormal: return ["34-788"]
        case .nidokingShadow: return ["34-789"]
        case .nidokingPurified: return ["34-790"]
        case .stunkyNormal: return ["434-791"]
        case .stunkyShadow: return ["434-792"]
        case .stunkyPurified: return ["434-793"]
        case .skuntankNormal: return ["435-794"]
        case .skuntankShadow: return ["435-795"]
        case .skuntankPurified: return ["435-796"]
        case .sneaselNormal: return ["215-797"]
        case .sneaselShadow: return ["215-798"]
        case .sneaselPurified: return ["215-799"]
        case .weavileNormal: return ["461-800"]
        case .weavileShadow: return ["461-801"]
        case .weavilePurified: return ["461-802"]
        case .gligarNormal: return ["207-803"]
        case .gligarShadow: return ["207-804"]
        case .gligarPurified: return ["207-805"]
        case .gliscorNormal: return ["472-806"]
        case .gliscorShadow: return ["472-807"]
        case .gliscorPurified: return ["472-808"]
        case .machopNormal: return ["66-809"]
        case .machopShadow: return ["66-810"]
        case .machopPurified: return ["66-811"]
        case .machokeNormal: return ["67-812"]
        case .machokeShadow: return ["67-813"]
        case .machokePurified: return ["67-814"]
        case .machampNormal: return ["68-815"]
        case .machampShadow: return ["68-816"]
        case .machampPurified: return ["68-817"]
        case .chimcharNormal: return ["390-818"]
        case .chimcharShadow: return ["390-819"]
        case .chimcharPurified: return ["390-820"]
        case .monfernoNormal: return ["391-821"]
        case .monfernoShadow: return ["391-822"]
        case .monfernoPurified: return ["391-823"]
        case .infernapeNormal: return ["392-824"]
        case .infernapeShadow: return ["392-825"]
        case .infernapePurified: return ["392-826"]
        case .shuckleNormal: return ["213-827"]
        case .shuckleShadow: return ["213-828"]
        case .shucklePurified: return ["213-829"]
        case .absolNormal: return ["359-830"]
        case .absolShadow: return ["359-831"]
        case .absolPurified: return ["359-832"]
        case .mawileNormal: return ["303-833"]
        case .mawileShadow: return ["303-834"]
        case .mawilePurified: return ["303-835"]
        case .moltresNormal: return ["146-836"]
        case .moltresShadow: return ["146-837"]
        case .moltresPurified: return ["146-838"]
        case .kangaskhanNormal: return ["115-839"]
        case .kangaskhanShadow: return ["115-840"]
        case .kangaskhanPurified: return ["115-841"]
        case .diglettShadow: return ["50-842"]
        case .diglettPurified: return ["50-843"]
        case .dugtrioShadow: return ["51-844"]
        case .dugtrioPurified: return ["51-845"]
        case .rhyhornNormal: return ["111-846"]
        case .rhyhornShadow: return ["111-847"]
        case .rhyhornPurified: return ["111-848"]
        case .rhydonNormal: return ["112-849"]
        case .rhydonShadow: return  ["112-850"]
        case .rhydonPurified: return  ["112-851"]
        case .rhyperiorNormal: return ["464-852"]
        case .rhyperiorShadow: return ["464-853"]
        case .rhyperiorPurified: return ["464-854"]
        case .murkrowNormal: return ["198-855"]
        case .murkrowShadow: return ["198-856"]
        case .murkrowPurified: return ["198-857"]
        case .honchkrowNormal: return ["430-858"]
        case .honchkrowShadow: return ["430-859"]
        case .honchkrowPurified: return ["430-860"]
        case .gibleNormal: return ["443-861"]
        case .gibleShadow: return ["443-862"]
        case .giblePurified: return ["443-863"]
        case .gabiteNormal: return ["444-864"]
        case .gabiteShadow: return ["444-865"]
        case .gabitePurified: return ["444-866"]
        case .garchompNormal: return ["445-867"]
        case .garchompShadow: return ["445-868"]
        case .garchompPurified: return ["445-869"]
        case .krabbyNormal: return ["98-870"]
        case .krabbyShadow: return ["98-871"]
        case .krabbyPurified: return ["98-872"]
        case .kinglerNormal: return ["99-873"]
        case .kinglerShadow: return ["99-874"]
        case .kinglerPurified: return ["99-875"]
        case .shellderNormal: return ["90-876"]
        case .shellderShadow: return ["90-877"]
        case .shellderPurified: return ["90-878"]
        case .cloysterNormal: return ["91-879"]
        case .cloysterShadow: return ["91-880"]
        case .cloysterPurified: return ["91-881"]
        case .geodudeShadow: return ["74-882"]
        case .geodudePurified: return ["74-883"]
        case .gravelerShadow: return ["75-884"]
        case .gravelerPurified: return ["75-885"]
        case .golemShadow: return ["76-886"]
        case .golemPurified: return ["76-887"]
        case .hippopotasNormal: return ["449-888"]
        case .hippopotasShadow: return ["449-889"]
        case .hippopotasPurified: return ["449-890"]
        case .hippowdonNormal: return ["450-891"]
        case .hippowdonShadow: return ["450-892"]
        case .hippowdonPurified: return ["450-893"]
        case .pikachuFall: return ["25-894"]
        case .squirtleFall: return ["7-895"]
        case .charmanderFall: return ["4-896"]
        case .bulbasaurFall: return ["1-897"]
        case .unset: return []
        case .UNRECOGNIZED: return []
        }
    }
    
}
