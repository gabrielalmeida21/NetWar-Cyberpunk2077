// NET War — gera a torre de andares de um nó: estilo da facção dona + modificadores sorteados.
module NetWar.Breach

import NetWar.Data.*

public abstract class NWFloorKind {
  public static func Password() -> Int32 { return 0; }
  public static func File() -> Int32 { return 1; }
  public static func ControlNode() -> Int32 { return 2; }
  public static func Ice() -> Int32 { return 3; }
  public static func DaemonCache() -> Int32 { return 4; }

  public static func Name(k: Int32) -> String {
    switch k {
      case 0: return NWL.T("Senha", "Password");
      case 1: return NWL.T("Arquivo", "File");
      case 2: return NWL.T("Nó de Controle", "Control Node");
      case 3: return "Black ICE";
      case 4: return NWL.T("Cache de daemon", "Daemon cache");
      default: return "?";
    }
  }
}

// Modificadores sorteados por invasão.
public abstract class NWArchMod {
  public static func RotatingPasswords() -> Int32 { return 0; }
  public static func ColdChamber() -> Int32 { return 1; }
  public static func DenseFog() -> Int32 { return 2; }
  public static func TraceEcho() -> Int32 { return 3; }
  public static func Unstable() -> Int32 { return 4; }
  public static func RandomCount() -> Int32 { return 4; } // 0..3 entram no sorteio; Instável é só da Blackwall

  public static func Name(m: Int32) -> String {
    switch m {
      case 0: return NWL.T("Senhas rotativas", "Rotating passwords");
      case 1: return NWL.T("Câmara fria", "Cold chamber");
      case 2: return NWL.T("Névoa densa", "Dense fog");
      case 3: return NWL.T("Eco de rastreio", "Trace echo");
      case 4: return NWL.T("Instável", "Unstable");
      default: return "?";
    }
  }

  public static func Description(m: Int32) -> String {
    switch m {
      case 0: return NWL.T("DV das senhas sobe a cada 3 turnos", "Password DV rises every 3 turns");
      case 1: return NWL.T("ICE mais forte, arquivos valem o dobro", "Stronger ICE, files are worth double");
      case 2: return NWL.T("Só desce para andares já escaneados", "Can only descend to scanned floors");
      case 3: return NWL.T("+1 de rastreio a cada turno", "+1 trace every turn");
      case 4: return NWL.T("Andares à frente se reconfiguram", "Floors ahead reconfigure themselves");
      default: return "";
    }
  }
}

// Estilo de arquitetura de cada facção.
public abstract class NWArchStyle {
  public static func Name(f: Int32) -> String {
    switch f {
      case 0: return NWL.T("Rede do V", "V's net");
      case 1: return NWL.T("Torre Arasaka", "Arasaka Tower");
      case 2: return NWL.T("Cofre Militech", "Militech Vault");
      case 3: return NWL.T("Núcleo Netwatch", "Netwatch Core");
      case 4: return NWL.T("Mercado Kang Tao", "Kang Tao Market");
      case 5: return NWL.T("Labirinto Vodu", "Voodoo Maze");
      case 7: return NWL.T("Brecha", "Breach");
      default: return NWL.T("Rede livre", "Free net");
    }
  }

  public static func Description(f: Int32) -> String {
    switch f {
      case 1: return NWL.T("Torre funda, muito Black ICE", "Deep tower, lots of Black ICE");
      case 2: return NWL.T("Senhas em sequência", "Passwords in sequence");
      case 3: return NWL.T("Poucos andares, DV alto, falhas rendem o dobro de rastreio", "Few floors, high DV, failures give double trace");
      case 4: return NWL.T("Muitos arquivos, ICE rápido", "Many files, fast ICE");
      case 5: return NWL.T("Caminhos bifurcados", "Forking paths");
      case 7: return NWL.T("Caótica: a arquitetura muda durante a invasão", "Chaotic: the architecture changes during the breach");
      default: return NWL.T("Arquitetura padrão", "Standard architecture");
    }
  }

  public static func FloorsDelta(f: Int32) -> Int32 {
    switch f {
      case 1: return 1;
      case 3: return -2;
      default: return 0;
    }
  }

  public static func DvDelta(f: Int32) -> Int32 {
    switch f {
      case 1: return 1;
      case 3: return 2;
      default: return 0;
    }
  }

  // Chance (%) de senha e de arquivo; o resto é Black ICE.
  public static func PasswordWeight(f: Int32) -> Int32 {
    switch f {
      case 1: return 25;
      case 2: return 60;
      case 3: return 40;
      case 4: return 25;
      case 5: return 35;
      case 7: return 30;
      default: return 40;
    }
  }

  public static func FileWeight(f: Int32) -> Int32 {
    switch f {
      case 1: return 15;
      case 2: return 15;
      case 3: return 20;
      case 4: return 45;
      case 5: return 30;
      default: return 25;
    }
  }

  public static func TraceMultiplier(f: Int32) -> Int32 { return f == 3 ? 2 : 1; }
  public static func IceSpeedBonus(f: Int32) -> Int32 { return f == 4 ? 2 : 0; }

  public static func ForkCount(f: Int32) -> Int32 {
    switch f {
      case 5: return 2;
      case 7: return 1;
      default: return 0;
    }
  }

  // Chance (%) de um modificador sorteado.
  public static func ModChance(f: Int32) -> Int32 {
    switch f {
      case 0: return 0;
      case 1: return 75;
      case 2: return 50;
      case 3: return 60;
      case 4: return 50;
      case 5: return 50;
      case 7: return 100;
      default: return 30;
    }
  }
}

public class NWFloor {
  public let kind: Int32;
  public let dv: Int32;
  public let iceId: Int32;
  public let iceRez: Int32;
  public let iceRezMax: Int32;
  public let fileEddies: Int32;
  public let daemonId: Int32;
  public let daemonRarity: Int32;
  public let revealed: Bool;
  public let cleared: Bool;
  // Bifurcação: caminho alternativo deste andar ("Descer pela direita" a partir do anterior).
  public let alt: ref<NWFloor>;
  // Lobby (primeiros andares, como no RED): só senhas e arquivos, DV baixo.
  public let lobby: Bool;

  public func Label() -> String {
    if !this.revealed {
      return "???";
    }
    let text: String;
    if this.kind == NWFloorKind.Ice() {
      text = s"\(NWIce.Name(this.iceId)) (REZ \(this.iceRez)/\(this.iceRezMax))";
    } else {
      if this.kind == NWFloorKind.File() {
        text = NWL.T(s"Arquivo DV \(this.dv) (€$ \(this.fileEddies))", s"File DV \(this.dv) (€$ \(this.fileEddies))");
      } else {
        if this.kind == NWFloorKind.DaemonCache() {
          return this.cleared ? NWL.T(s"Cache: \(NWDaemon.Name(this.daemonId)) [coletado]", s"Cache: \(NWDaemon.Name(this.daemonId)) [collected]") : NWL.T("Cache de daemon", "Daemon cache");
        }
        text = s"\(NWFloorKind.Name(this.kind)) DV \(this.dv)";
      }
    }
    if this.cleared {
      text = text + NWL.T(" [livre]", " [clear]");
    }
    return text;
  }
}

public class NWArchitecture {
  public let floors: array<ref<NWFloor>>;
  public let style: Int32;
  public let mods: array<Int32>;

  public func HasMod(m: Int32) -> Bool {
    return ArrayContains(this.mods, m);
  }
}

public abstract class NWArchitectureGen {

  public static func Generate(def: ref<NWNodeDef>, faction: Int32) -> ref<NWArchitecture> {
    let arch = new NWArchitecture();
    arch.style = faction;

    // Modificadores.
    if faction == NWFaction.Blackwall() {
      ArrayPush(arch.mods, NWArchMod.Unstable());
    }
    if RandRange(0, 100) < NWArchStyle.ModChance(faction) {
      ArrayPush(arch.mods, RandRange(0, NWArchMod.RandomCount()));
    }
    let cold = arch.HasMod(NWArchMod.ColdChamber());

    let count = Max(3, def.floors + NWArchStyle.FloorsDelta(faction));
    let dvBase = def.dvBase + NWArchStyle.DvDelta(faction);

    // Andares 0..count-2 recebem conteúdo; o último é sempre o Nó de Controle.
    // Lobby: os 2 primeiros andares (1 numa torre de 3) só têm senha ou arquivo, DV 6 (8 na Blackwall).
    let lobby = count >= 4 ? 2 : 1;
    let kinds: array<Int32>;
    let iceIds: array<Int32>;
    let k = 0;
    while k < count - 1 {
      ArrayPush(kinds, k < lobby ? NWArchitectureGen.RollLobbyKind(faction) : NWArchitectureGen.RollKind(faction));
      ArrayPush(iceIds, -1);
      k += 1;
    }

    // Garante que cada ICE do nó aparece pelo menos uma vez, em andares aleatórios depois do lobby.
    let free: array<Int32>;
    k = lobby;
    while k < count - 1 {
      ArrayPush(free, k);
      k += 1;
    }
    for ice in def.ice {
      if ArraySize(free) > 0 {
        let pick = RandRange(0, ArraySize(free));
        let slot = free[pick];
        ArrayErase(free, pick);
        kinds[slot] = NWFloorKind.Ice();
        iceIds[slot] = ice;
      }
    }

    let cacheChance = cold ? 25 : 12;
    k = lobby;
    while k < count - 1 {
      if iceIds[k] < 0 && RandRange(0, 100) < cacheChance {
        kinds[k] = NWFloorKind.DaemonCache();
      }
      k += 1;
    }

    k = 0;
    while k < count {
      if k == count - 1 {
        let control = new NWFloor();
        control.kind = NWFloorKind.ControlNode();
        control.dv = dvBase + 2;
        ArrayPush(arch.floors, control);
      } else {
        if k < lobby {
          let lf = NWArchitectureGen.MakeFloor(def, kinds[k], -1, faction == NWFaction.Blackwall() ? 8 : 6, cold);
          lf.lobby = true;
          ArrayPush(arch.floors, lf);
        } else {
          ArrayPush(arch.floors, NWArchitectureGen.MakeFloor(def, kinds[k], iceIds[k], dvBase + k / 3, cold));
        }
      }
      k += 1;
    }

    // Bifurcações: andares do meio ganham um caminho alternativo de outro tipo.
    let forks = NWArchitectureGen.ForkSlots(count, NWArchStyle.ForkCount(faction), lobby);
    for slot in forks {
      let mainKind = arch.floors[slot].kind;
      let altKind = NWArchitectureGen.RollKind(faction);
      if altKind == mainKind {
        altKind = mainKind == NWFloorKind.Ice() ? NWFloorKind.File() : NWFloorKind.Ice();
      }
      arch.floors[slot].alt = NWArchitectureGen.MakeFloor(def, altKind, -1, dvBase + slot / 3, cold);
    }
    return arch;
  }

  public static func RollLobbyKind(faction: Int32) -> Int32 {
    let pw = NWArchStyle.PasswordWeight(faction);
    let fw = NWArchStyle.FileWeight(faction);
    return RandRange(0, pw + fw) < pw ? NWFloorKind.Password() : NWFloorKind.File();
  }

  public static func RollKind(faction: Int32) -> Int32 {
    let roll = RandRange(0, 100);
    let pw = NWArchStyle.PasswordWeight(faction);
    if roll < pw {
      return NWFloorKind.Password();
    }
    if roll < pw + NWArchStyle.FileWeight(faction) {
      return NWFloorKind.File();
    }
    return NWFloorKind.Ice();
  }

  public static func MakeFloor(def: ref<NWNodeDef>, kind: Int32, iceId: Int32, dv: Int32, cold: Bool) -> ref<NWFloor> {
    let f = new NWFloor();
    f.kind = kind;
    f.dv = dv;
    if kind == NWFloorKind.Ice() {
      let id = iceId;
      if id < 0 {
        id = ArraySize(def.ice) > 0 ? def.ice[RandRange(0, ArraySize(def.ice))] : 0;
      }
      f.iceId = id;
      f.iceRezMax = NWIce.Rez(id);
      if cold {
        f.iceRezMax = (f.iceRezMax * 5) / 4;
      }
      f.iceRez = f.iceRezMax;
    }
    if kind == NWFloorKind.DaemonCache() {
      let blackwall = def.startOwner == NWFaction.Blackwall();
      f.daemonId = NWDaemon.RollId(blackwall);
      f.daemonRarity = NWDaemon.RollRarity(def.dvBase, blackwall);
    }
    if kind == NWFloorKind.File() {
      f.fileEddies = 200 * def.dvBase + 50 * RandRange(0, 20);
      if cold {
        f.fileEddies *= 2;
      }
    }
    return f;
  }

  // Andares 1..count-2 que viram bifurcação (nunca o primeiro nem o Nó de Controle).
  private static func ForkSlots(count: Int32, wanted: Int32, first: Int32) -> array<Int32> {
    let slots: array<Int32>;
    let candidates: array<Int32>;
    let k = Max(1, first);
    while k < count - 1 {
      ArrayPush(candidates, k);
      k += 1;
    }
    while ArraySize(slots) < wanted && ArraySize(candidates) > 0 {
      let pick = RandRange(0, ArraySize(candidates));
      ArrayPush(slots, candidates[pick]);
      ArrayErase(candidates, pick);
    }
    return slots;
  }
}
