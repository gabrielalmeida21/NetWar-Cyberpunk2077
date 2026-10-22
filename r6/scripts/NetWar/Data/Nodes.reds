// NET War — os 14 nós da rede (definições estáticas; nada disto vai para o save).
// Valores tirados do mockup "NET War — Mapa Mundi" e do plano técnico.
module NetWar.Data

public abstract class NWBonus {
  public static func None() -> Int32 { return 0; }
  public static func MaxRam() -> Int32 { return 1; }        // +valor RAM máxima
  public static func DaemonSlot() -> Int32 { return 2; }    // +valor slots de daemon
  public static func TraceReduction() -> Int32 { return 3; } // -valor% no ganho de rastreio
  public static func Interface() -> Int32 { return 4; }     // +valor Interface
  public static func Intel() -> Int32 { return 5; }         // só texto por enquanto (itens via TweakXL na fase 6)
}

public class NWNodeDef {
  public let code: Int32;              // código numérico fixo, usado no save; nunca reutilizar
  public let id: String;
  public let name: String;
  public let subtitle: String;
  // Textos em inglês (vazio = igual ao português). Exibição sempre por Name()/Subtitle()/RewardText().
  public let nameEn: String;
  public let subtitleEn: String;
  public let rewardTextEn: String;
  public let lat: Float;
  public let lon: Float;
  public let startOwner: Int32;
  public let startControl: Int32;
  public let floors: Int32;
  public let dvBase: Int32;
  public let ice: array<Int32>;
  public let rewardEddies: Int32;
  public let dailyIncome: Int32;
  public let bonusType: Int32;
  public let bonusValue: Int32;
  public let rewardText: String;
  public let isHome: Bool;
  public let connections: array<String>;

  public func Name() -> String { return NWL.T(this.name, StrLen(this.nameEn) > 0 ? this.nameEn : this.name); }
  public func Subtitle() -> String { return NWL.T(this.subtitle, StrLen(this.subtitleEn) > 0 ? this.subtitleEn : this.subtitle); }
  public func RewardText() -> String { return NWL.T(this.rewardText, StrLen(this.rewardTextEn) > 0 ? this.rewardTextEn : this.rewardText); }
}

// Projeção equiretangular recortada: lon −135..160, lat 72..−50, área 1200×496.
public abstract class NWProjection {
  public static func MapWidth() -> Float { return 1200.0; }
  public static func MapHeight() -> Float { return 496.0; }
  public static func X(lon: Float) -> Float { return (lon + 135.0) * (1200.0 / 295.0); }
  public static func Y(lat: Float) -> Float { return (72.0 - lat) * (496.0 / 122.0); }
}

public abstract class NWNodes {

  // Cópia rasa (arrays copiados) para ajustar valores de uma invasão sem tocar na definição.
  public static func Clone(d: ref<NWNodeDef>) -> ref<NWNodeDef> {
    let n = new NWNodeDef();
    n.code = d.code;
    n.id = d.id;
    n.name = d.name;
    n.subtitle = d.subtitle;
    n.lat = d.lat;
    n.lon = d.lon;
    n.startOwner = d.startOwner;
    n.startControl = d.startControl;
    n.floors = d.floors;
    n.dvBase = d.dvBase;
    n.ice = d.ice;
    n.rewardEddies = d.rewardEddies;
    n.dailyIncome = d.dailyIncome;
    n.bonusType = d.bonusType;
    n.bonusValue = d.bonusValue;
    n.rewardText = d.rewardText;
    n.nameEn = d.nameEn;
    n.subtitleEn = d.subtitleEn;
    n.rewardTextEn = d.rewardTextEn;
    n.isHome = d.isHome;
    n.connections = d.connections;
    return n;
  }

  private static func Make(code: Int32, id: String, name: String, lat: Float, lon: Float, owner: Int32, control: Int32,
                           floors: Int32, dv: Int32, subtitle: String) -> ref<NWNodeDef> {
    let n = new NWNodeDef();
    n.code = code;
    n.id = id;
    n.name = name;
    n.lat = lat;
    n.lon = lon;
    n.startOwner = owner;
    n.startControl = control;
    n.floors = floors;
    n.dvBase = dv;
    n.subtitle = subtitle;
    n.bonusType = NWBonus.None();
    return n;
  }

  private static func Reward(n: ref<NWNodeDef>, eddies: Int32, income: Int32, bonusType: Int32, bonusValue: Int32, text: String) -> Void {
    n.rewardEddies = eddies;
    n.dailyIncome = income;
    n.bonusType = bonusType;
    n.bonusValue = bonusValue;
    n.rewardText = text;
  }

  private static func En(n: ref<NWNodeDef>, name: String, subtitle: String, reward: String) -> Void {
    n.nameEn = name;
    n.subtitleEn = subtitle;
    n.rewardTextEn = reward;
  }

  public static func Build() -> array<ref<NWNodeDef>> {
    let all: array<ref<NWNodeDef>>;
    let n: ref<NWNodeDef>;

    n = NWNodes.Make(1, "nc", "Night City", 35.5, -121.0, NWFaction.V(), 100, 4, 6, "NÓ DOMÉSTICO · MEGABUILDING H10");
    n.isHome = true;
    ArrayPush(n.ice, 0);
    NWNodes.Reward(n, 0, 1200, NWBonus.None(), 0, "Renda passiva: €$ 1.200 / dia");
    ArrayPush(n.connections, "sea"); ArrayPush(n.connections, "mex"); ArrayPush(n.connections, "dc"); ArrayPush(n.connections, "tok");
    NWNodes.En(n, "Night City", "HOME NODE · MEGABUILDING H10", "Passive income: €$ 1,200 / day");
    ArrayPush(all, n);

    n = NWNodes.Make(2, "sea", "Seattle", 47.6, -122.3, NWFaction.Neutral(), 40, 3, 6, "SUBREDE PORTUÁRIA · LIVRE");
    ArrayPush(n.ice, 0);
    NWNodes.Reward(n, 3000, 300, NWBonus.None(), 0, "€$ 3.000 · Rota para o norte da rede");
    ArrayPush(n.connections, "nc");
    NWNodes.En(n, "Seattle", "PORT SUBNET · FREE", "€$ 3,000 · Route to the northern net");
    ArrayPush(all, n);

    n = NWNodes.Make(3, "mex", "Cidade do México", 19.4, -99.1, NWFaction.V(), 64, 5, 8, "EM DISPUTA · INVASÃO EM CURSO");
    ArrayPush(n.ice, 1); ArrayPush(n.ice, 2);
    NWNodes.Reward(n, 6500, 600, NWBonus.DaemonSlot(), 1, "€$ 6.500 · +1 slot de daemon");
    ArrayPush(n.connections, "nc"); ArrayPush(n.connections, "pap");
    NWNodes.En(n, "Mexico City", "CONTESTED · BREACH IN PROGRESS", "€$ 6,500 · +1 daemon slot");
    ArrayPush(all, n);

    n = NWNodes.Make(4, "dc", "Washington D.C.", 38.9, -77.0, NWFaction.Militech(), 92, 7, 10, "MILITECH · REDE DA NUSA");
    ArrayPush(n.ice, 5); ArrayPush(n.ice, 6); ArrayPush(n.ice, 2);
    NWNodes.Reward(n, 22000, 1500, NWBonus.Intel(), 0, "€$ 22.000 · Blueprint de quickhack militar");
    ArrayPush(n.connections, "nc"); ArrayPush(n.connections, "pap"); ArrayPush(n.connections, "bru");
    NWNodes.En(n, "Washington D.C.", "MILITECH · NUSA NETWORK", "€$ 22,000 · Military quickhack blueprint");
    ArrayPush(all, n);

    n = NWNodes.Make(5, "pap", "Porto Príncipe", 18.5, -72.3, NWFaction.VoodooBoys(), 81, 6, 8, "VOODOO BOYS · REDE DO VODU");
    ArrayPush(n.ice, 4); ArrayPush(n.ice, 0);
    NWNodes.Reward(n, 9000, 700, NWBonus.Intel(), 0, "€$ 9.000 · Fragmento sobre a Blackwall");
    ArrayPush(n.connections, "mex"); ArrayPush(n.connections, "dc"); ArrayPush(n.connections, "sp");
    NWNodes.En(n, "Port-au-Prince", "VOODOO BOYS · VOODOO NET", "€$ 9,000 · Fragment about the Blackwall");
    ArrayPush(all, n);

    n = NWNodes.Make(6, "sp", "São Paulo", -23.5, -46.6, NWFaction.Neutral(), 35, 4, 6, "REDE METROPOLITANA · LIVRE");
    ArrayPush(n.ice, 1);
    NWNodes.Reward(n, 5000, 500, NWBonus.None(), 0, "€$ 5.000 · Acesso à rota do Atlântico");
    ArrayPush(n.connections, "pap"); ArrayPush(n.connections, "lag"); ArrayPush(n.connections, "sat");
    NWNodes.En(n, "São Paulo", "METRO NETWORK · FREE", "€$ 5,000 · Access to the Atlantic route");
    ArrayPush(all, n);

    n = NWNodes.Make(7, "bru", "Bruxelas", 50.8, 4.35, NWFaction.Netwatch(), 100, 8, 12, "NETWATCH · NÚCLEO EUROPEU");
    ArrayPush(n.ice, 5); ArrayPush(n.ice, 9); ArrayPush(n.ice, 8);
    NWNodes.Reward(n, 40000, 2000, NWBonus.TraceReduction(), 15, "€$ 40.000 · −15% rastreio global");
    ArrayPush(n.connections, "dc"); ArrayPush(n.connections, "lag"); ArrayPush(n.connections, "mos");
    NWNodes.En(n, "Brussels", "NETWATCH · EUROPEAN CORE", "€$ 40,000 · −15% global trace");
    ArrayPush(all, n);

    n = NWNodes.Make(8, "lag", "Lagos", 6.5, 3.4, NWFaction.Neutral(), 20, 3, 6, "HUB DE DADOS · LIVRE");
    ArrayPush(n.ice, 0);
    NWNodes.Reward(n, 2500, 300, NWBonus.None(), 0, "€$ 2.500");
    ArrayPush(n.connections, "sp"); ArrayPush(n.connections, "bru"); ArrayPush(n.connections, "dub");
    NWNodes.En(n, "Lagos", "DATA HUB · FREE", "€$ 2,500");
    ArrayPush(all, n);

    n = NWNodes.Make(9, "mos", "Moscou", 55.75, 37.6, NWFaction.Neutral(), 55, 5, 8, "REDE INSTÁVEL · CONTESTADA");
    ArrayPush(n.ice, 3); ArrayPush(n.ice, 1);
    NWNodes.Reward(n, 8000, 600, NWBonus.None(), 0, "€$ 8.000");
    ArrayPush(n.connections, "bru"); ArrayPush(n.connections, "dub"); ArrayPush(n.connections, "sib");
    NWNodes.En(n, "Moscow", "UNSTABLE NETWORK · CONTESTED", "€$ 8,000");
    ArrayPush(all, n);

    n = NWNodes.Make(10, "dub", "Dubai", 25.2, 55.3, NWFaction.KangTao(), 70, 5, 8, "KANG TAO · ESCRITÓRIO REGIONAL");
    ArrayPush(n.ice, 6); ArrayPush(n.ice, 2);
    NWNodes.Reward(n, 12000, 900, NWBonus.Intel(), 0, "€$ 12.000 · Intel de armas inteligentes");
    ArrayPush(n.connections, "lag"); ArrayPush(n.connections, "mos"); ArrayPush(n.connections, "hk");
    NWNodes.En(n, "Dubai", "KANG TAO · REGIONAL OFFICE", "€$ 12,000 · Smart weapon intel");
    ArrayPush(all, n);

    n = NWNodes.Make(11, "sib", "Brecha Sibéria", 62.0, 100.0, NWFaction.Blackwall(), 0, 10, 14, "ALÉM DA BLACKWALL · NÃO MAPEADO");
    ArrayPush(n.ice, 11); ArrayPush(n.ice, 12);
    NWNodes.Reward(n, 60000, 0, NWBonus.Interface(), 1, "Desconhecida · Risco de morte cerebral");
    ArrayPush(n.connections, "mos"); ArrayPush(n.connections, "tok");
    NWNodes.En(n, "Siberia Breach", "BEYOND THE BLACKWALL · UNMAPPED", "Unknown · Risk of brain death");
    ArrayPush(all, n);

    n = NWNodes.Make(12, "sat", "Zona Morta", -38.0, -18.0, NWFaction.Blackwall(), 0, 8, 13, "ATLÂNTICO SUL · REDE MORTA");
    ArrayPush(n.ice, 13);
    NWNodes.Reward(n, 30000, 0, NWBonus.MaxRam(), 1, "Dados da Rede antiga");
    ArrayPush(n.connections, "sp");
    NWNodes.En(n, "Dead Zone", "SOUTH ATLANTIC · DEAD NET", "Old Net data");
    ArrayPush(all, n);

    n = NWNodes.Make(13, "hk", "Hong Kong", 22.3, 114.2, NWFaction.KangTao(), 96, 7, 10, "KANG TAO · SEDE DE P&D");
    ArrayPush(n.ice, 9); ArrayPush(n.ice, 4);
    NWNodes.Reward(n, 26000, 1600, NWBonus.Interface(), 1, "€$ 26.000 · Protótipo de cyberdeck (+1 Interface)");
    ArrayPush(n.connections, "dub"); ArrayPush(n.connections, "tok");
    NWNodes.En(n, "Hong Kong", "KANG TAO · R&D HQ", "€$ 26,000 · Cyberdeck prototype (+1 Interface)");
    ArrayPush(all, n);

    n = NWNodes.Make(14, "tok", "Tóquio", 35.7, 139.7, NWFaction.Arasaka(), 100, 8, 12, "ARASAKA · SUBREDE 07 · CHIYODA");
    ArrayPush(n.ice, 5); ArrayPush(n.ice, 7); ArrayPush(n.ice, 10);
    NWNodes.Reward(n, 45000, 2500, NWBonus.MaxRam(), 2, "€$ 45.000 · +2 RAM extra por jack-in");
    ArrayPush(n.connections, "hk"); ArrayPush(n.connections, "sib"); ArrayPush(n.connections, "nc");
    NWNodes.En(n, "Tokyo", "ARASAKA · SUBNET 07 · CHIYODA", "€$ 45,000 · +2 extra RAM per jack-in");
    ArrayPush(all, n);

    return all;
  }
}
