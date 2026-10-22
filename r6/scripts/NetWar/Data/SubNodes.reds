// NET War — sub-nós: 3 regiões por nó do mundo e 2–3 locais por região (zoom REGIÃO e CIDADE).
// Definições estáticas derivadas do nó pai; nada disto vai para o save além da lista de códigos
// que o V tomou (saveSubTaken). Códigos: pai*100 + (região+1)*10 + local (0 = a própria região).
module NetWar.Data

public class NWSubDef {
  public let code: Int32;
  public let parent: Int32;      // índice do nó do mundo
  public let parentSub: Int32;   // índice da região (só nos locais; −1 nas regiões)
  public let level: Int32;       // 1 região, 2 local
  public let name: String;       // rótulo curto no mapa
  public let fullName: String;   // nome no painel e na invasão
  public let nameEn: String;
  public let fullNameEn: String;
  public let x: Float;           // posição na área do mapa (1200×496)
  public let y: Float;
  public let def: ref<NWNodeDef>; // definição sintética usada pela invasão

  public func Name() -> String { return NWL.T(this.name, this.nameEn); }
  public func FullName() -> String { return NWL.T(this.fullName, this.fullNameEn); }
}

public abstract class NWSubNodes {

  public static func RegionLevel() -> Int32 { return 1; }
  public static func SiteLevel() -> Int32 { return 2; }

  // Controle tirado do dono do nó pai ao dominar (partial control).
  public static func ParentControlGain(level: Int32) -> Int32 { return level == 1 ? 15 : 5; }

  private static func RegionNames(id: String) -> array<String> {
    switch id {
      case "nc": return ["Watson", "City Center", "Pacifica"];
      case "sea": return ["Porto de Elliott", "Distrito Industrial", "Bellevue"];
      case "mex": return ["Centro Histórico", "Polanco", "Iztapalapa"];
      case "dc": return ["Capitólio", "Arlington", "Pentágono Sul"];
      case "pap": return ["Cité Soleil", "Pétion-Ville", "Cais do Porto"];
      case "sp": return ["Avenida Paulista", "Zona Leste", "Porto de Santos"];
      case "bru": return ["Distrito Europeu", "Anderlecht", "Nó de Antuérpia"];
      case "lag": return ["Ilha Vitória", "Ikeja", "Apapa"];
      case "mos": return ["Kremlin", "Moscou-City", "Zelenogrado"];
      case "dub": return ["Marina", "Jebel Ali", "Deira"];
      case "sib": return ["Fenda Norte", "Eco de Norilsk", "Vazio de Tunguska"];
      case "sat": return ["Abismo de Tristão", "Cabo Fantasma", "Fossa Atlântica"];
      case "hk": return ["Kowloon", "Central", "Lantau"];
      case "tok": return ["Chiyoda", "Shinjuku", "Minato"];
      default: return ["Setor A", "Setor B", "Setor C"];
    }
  }

  private static func RegionNamesEn(id: String) -> array<String> {
    switch id {
      case "nc": return ["Watson", "City Center", "Pacifica"];
      case "sea": return ["Elliott Harbor", "Industrial District", "Bellevue"];
      case "mex": return ["Historic Center", "Polanco", "Iztapalapa"];
      case "dc": return ["Capitol", "Arlington", "Pentagon South"];
      case "pap": return ["Cité Soleil", "Pétion-Ville", "Harbor Docks"];
      case "sp": return ["Paulista Avenue", "East Zone", "Port of Santos"];
      case "bru": return ["European Quarter", "Anderlecht", "Antwerp Node"];
      case "lag": return ["Victoria Island", "Ikeja", "Apapa"];
      case "mos": return ["Kremlin", "Moscow-City", "Zelenograd"];
      case "dub": return ["Marina", "Jebel Ali", "Deira"];
      case "sib": return ["North Rift", "Norilsk Echo", "Tunguska Void"];
      case "sat": return ["Tristan Abyss", "Ghost Cape", "Atlantic Trench"];
      case "hk": return ["Kowloon", "Central", "Lantau"];
      case "tok": return ["Chiyoda", "Shinjuku", "Minato"];
      default: return ["Sector A", "Sector B", "Sector C"];
    }
  }

  private static func SiteKindEn(k: Int32, blackwall: Bool) -> String {
    if blackwall {
      switch k % 4 {
        case 0: return "Memory fragment";
        case 1: return "AI echo";
        case 2: return "Data ruin";
        default: return "Ghost signal";
      }
    }
    switch k % 8 {
      case 0: return "Data server";
      case 1: return "Comms tower";
      case 2: return "Camera grid";
      case 3: return "Database";
      case 4: return "Laboratory";
      case 5: return "Data vault";
      case 6: return "Satellite relay";
      default: return "Substation";
    }
  }

  private static func SiteKind(k: Int32, blackwall: Bool) -> String {
    if blackwall {
      switch k % 4 {
        case 0: return "Fragmento de memória";
        case 1: return "Eco de IA";
        case 2: return "Ruína de dados";
        default: return "Sinal fantasma";
      }
    }
    switch k % 8 {
      case 0: return "Servidor de dados";
      case 1: return "Torre de comunicação";
      case 2: return "Rede de câmeras";
      case 3: return "Banco de dados";
      case 4: return "Laboratório";
      case 5: return "Cofre de dados";
      case 6: return "Relé de satélite";
      default: return "Subestação";
    }
  }

  // Graus → posição, presa à área do mapa.
  private static func Offset(cx: Float, cy: Float, radius: Float, deg: Float, out x: Float, out y: Float) -> Void {
    let rad = deg * 3.14159265 / 180.0;
    x = ClampF(cx + CosF(rad) * radius, 6.0, 1194.0);
    y = ClampF(cy + SinF(rad) * radius, 6.0, 490.0);
  }

  private static func MakeDef(parent: ref<NWNodeDef>, code: Int32, fullName: String, subtitle: String, fullNameEn: String, subtitleEn: String, level: Int32) -> ref<NWNodeDef> {
    let d = new NWNodeDef();
    d.code = code;
    d.id = s"sub\(code)";
    d.name = fullName;
    d.subtitle = subtitle;
    d.nameEn = fullNameEn;
    d.subtitleEn = subtitleEn;
    d.lat = parent.lat;
    d.lon = parent.lon;
    d.startOwner = parent.startOwner;
    d.startControl = 0;
    if level == 1 {
      d.floors = Max(3, parent.floors / 2 + 1);
      d.dvBase = Max(4, parent.dvBase - 2);
      d.rewardEddies = Max(1500, parent.rewardEddies / 10);
    } else {
      d.floors = 3;
      d.dvBase = Max(3, parent.dvBase - 3);
      d.rewardEddies = Max(800, parent.rewardEddies / 20);
    }
    // ICE: a região leva quase todo o ICE do pai; o local, só o primeiro.
    let k = 0;
    let keep = level == 1 ? Max(1, ArraySize(parent.ice) - 1) : 1;
    while k < ArraySize(parent.ice) && k < keep {
      ArrayPush(d.ice, parent.ice[k]);
      k += 1;
    }
    d.bonusType = NWBonus.None();
    d.rewardText = s"€$ \(d.rewardEddies)";
    return d;
  }

  public static func Build(defs: array<ref<NWNodeDef>>) -> array<ref<NWSubDef>> {
    let all: array<ref<NWSubDef>>;
    let i = 0;
    while i < ArraySize(defs) {
      let p = defs[i];
      let px = NWProjection.X(p.lon);
      let py = NWProjection.Y(p.lat);
      let names = NWSubNodes.RegionNames(p.id);
      let namesEn = NWSubNodes.RegionNamesEn(p.id);
      let parentEn = StrLen(p.nameEn) > 0 ? p.nameEn : p.name;
      let blackwall = p.startOwner == NWFaction.Blackwall();
      let base = Cast<Float>((p.code * 47) % 360);
      let r = 0;
      while r < 3 {
        let reg = new NWSubDef();
        reg.code = p.code * 100 + (r + 1) * 10;
        reg.parent = i;
        reg.parentSub = -1;
        reg.level = 1;
        reg.name = names[r];
        reg.fullName = s"\(names[r]) · \(p.name)";
        reg.nameEn = namesEn[r];
        reg.fullNameEn = s"\(namesEn[r]) · \(parentEn)";
        let angle = base + Cast<Float>(r) * 120.0;
        let rx: Float;
        let ry: Float;
        NWSubNodes.Offset(px, py, 24.0, angle, rx, ry);
        reg.x = rx;
        reg.y = ry;
        reg.def = NWSubNodes.MakeDef(p, reg.code, reg.fullName, s"REGIÃO DE \(NWText.Upper(p.name))", reg.fullNameEn, s"REGION OF \(NWText.Upper(parentEn))", 1);
        ArrayPush(all, reg);
        let regIndex = ArraySize(all) - 1;

        // Locais: em leque para fora do nó pai.
        let sites = 2 + (p.code + r) % 2;
        let c = 0;
        while c < sites {
          let site = new NWSubDef();
          site.code = reg.code + c + 1;
          site.parent = i;
          site.parentSub = regIndex;
          site.level = 2;
          site.name = NWSubNodes.SiteKind(p.code * 7 + r * 3 + c, blackwall);
          site.fullName = s"\(site.name) · \(names[r])";
          site.nameEn = NWSubNodes.SiteKindEn(p.code * 7 + r * 3 + c, blackwall);
          site.fullNameEn = s"\(site.nameEn) · \(namesEn[r])";
          let spread = Cast<Float>(c) - Cast<Float>(sites - 1) / 2.0;
          let sx: Float;
          let sy: Float;
          NWSubNodes.Offset(rx, ry, 14.0, angle + spread * 50.0, sx, sy);
          site.x = sx;
          site.y = sy;
          site.def = NWSubNodes.MakeDef(p, site.code, site.fullName, s"LOCAL EM \(NWText.Upper(names[r]))", site.fullNameEn, s"SITE IN \(NWText.Upper(namesEn[r]))", 2);
          ArrayPush(all, site);
          c += 1;
        }
        r += 1;
      }
      i += 1;
    }
    return all;
  }
}
