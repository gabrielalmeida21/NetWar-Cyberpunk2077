// NET War — estado mutável da guerra da rede.
// Só tipos simples em arrays paralelos (indexados como NWNodes.Build()), para que a fase 2
// possa persistir estes campos no save sem conversão.
module NetWar.Core

import NetWar.Data.*

public class NWWorldState {
  // Definições estáticas (reconstruídas no código, nunca salvas).
  public let defs: array<ref<NWNodeDef>>;
  // Sub-nós (regiões e locais). Sem tomar, seguem o dono do nó pai; tomados pelo V, ficam com o V.
  public let subs: array<ref<NWSubDef>>;
  public let subTaken: array<Bool>;
  public let edgeA: array<Int32>;
  public let edgeB: array<Int32>;

  // Estado por nó.
  public let owner: array<Int32>;
  public let control: array<Int32>;
  // Defesas montadas pelo V: NWDefense.SlotsPerNode() camadas por nó (índice nó*3 + camada).
  public let layers: array<Int32>;
  // Inteligência: estilo visto (-1 = nenhum), máscara de modificadores, andares, mais fundo, invasões.
  public let intelStyle: array<Int32>;
  public let intelMods: array<Int32>;
  public let intelFloors: array<Int32>;
  public let intelDepth: array<Int32>;
  public let intelVisits: array<Int32>;
  public let scanned: array<Bool>;
  public let bonusClaimed: array<Bool>;

  // Recursos do jogador.
  public let trace: Int32;             // rastreio Netwatch 0..100
  public let ram: Int32;
  public let ramMax: Int32;
  public let interfaceBase: Int32;
  public let interfaceBonus: Int32;
  public let eddies: Int32;            // carteira interna; vira eddies reais do jogo numa fase posterior
  public let daemonSlots: Int32;
  public let traceReductionPct: Int32;
  public let pendingHealthPenalty: Int32;

  // Tempo da simulação (horas de jogo desde o início da guerra).
  public let simHours: Float;
  public let tickAccum: Float;
  public let incomeAccum: Float;
  public let traceDecayAccum: Float;
  public let ramRegenAccum: Float;
  public let lockoutHours: Float;
  public let lastIncomeDay: Int32;
  public let incomeToday: Int32;

  // Daemons: raridade possuída por id (-1 = nunca encontrado), cópias para fusão e equipados.
  public let daemonRarity: array<Int32>;
  public let daemonCopies: array<Int32>;
  public let equipped: array<Int32>;

  // Registro da rede (mais antigo primeiro).
  public let log: array<String>;

  public func Init() -> Void {
    ArrayClear(this.defs);
    ArrayClear(this.edgeA);
    ArrayClear(this.edgeB);
    ArrayClear(this.owner);
    ArrayClear(this.control);
    ArrayClear(this.layers);
    ArrayClear(this.intelStyle);
    ArrayClear(this.intelMods);
    ArrayClear(this.intelFloors);
    ArrayClear(this.intelDepth);
    ArrayClear(this.intelVisits);
    ArrayClear(this.scanned);
    ArrayClear(this.bonusClaimed);
    ArrayClear(this.log);

    this.defs = NWNodes.Build();
    this.subs = NWSubNodes.Build(this.defs);
    ArrayClear(this.subTaken);
    let si = 0;
    while si < ArraySize(this.subs) {
      ArrayPush(this.subTaken, false);
      si += 1;
    }
    let i = 0;
    let count = ArraySize(this.defs);
    while i < count {
      ArrayPush(this.owner, this.defs[i].startOwner);
      ArrayPush(this.control, this.defs[i].startControl);
      let l = 0;
      while l < NWDefense.SlotsPerNode() {
        ArrayPush(this.layers, NWDefense.None());
        l += 1;
      }
      ArrayPush(this.intelStyle, -1);
      ArrayPush(this.intelMods, 0);
      ArrayPush(this.intelFloors, 0);
      ArrayPush(this.intelDepth, 0);
      ArrayPush(this.intelVisits, 0);
      ArrayPush(this.scanned, false);
      ArrayPush(this.bonusClaimed, false);
      i += 1;
    }
    this.BuildEdges();

    ArrayClear(this.daemonRarity);
    ArrayClear(this.daemonCopies);
    ArrayClear(this.equipped);
    let d = 0;
    while d < NWDaemon.Count() {
      ArrayPush(this.daemonRarity, -1);
      ArrayPush(this.daemonCopies, 0);
      d += 1;
    }

    this.trace = 23;
    this.ramMax = 12;
    this.ram = 9;
    this.interfaceBase = 6;
    this.interfaceBonus = 0;
    this.eddies = 0;
    this.daemonSlots = 2;
    this.traceReductionPct = 0;
    this.pendingHealthPenalty = 0;
    this.simHours = 0.0;
    this.tickAccum = 0.0;
    this.incomeAccum = 0.0;
    this.traceDecayAccum = 0.0;
    this.ramRegenAccum = 0.0;
    this.lockoutHours = 0.0;
    this.lastIncomeDay = 0;
    this.incomeToday = 0;

    this.AddLog(NWL.T("Conexão estabelecida a partir do nó doméstico NIGHT CITY.", "Connection established from the NIGHT CITY home node."));
  }

  private func BuildEdges() -> Void {
    let i = 0;
    let count = ArraySize(this.defs);
    while i < count {
      for otherId in this.defs[i].connections {
        let j = this.IndexOf(otherId);
        if j >= 0 && !this.HasEdge(i, j) {
          ArrayPush(this.edgeA, i);
          ArrayPush(this.edgeB, j);
        }
      }
      i += 1;
    }
  }

  public func NodeCount() -> Int32 {
    return ArraySize(this.defs);
  }

  public func IsValid(i: Int32) -> Bool {
    return i >= 0 && i < ArraySize(this.defs);
  }

  public func IndexOf(id: String) -> Int32 {
    let i = 0;
    let count = ArraySize(this.defs);
    while i < count {
      if Equals(this.defs[i].id, id) {
        return i;
      }
      i += 1;
    }
    return -1;
  }

  public func HasEdge(a: Int32, b: Int32) -> Bool {
    let k = 0;
    let count = ArraySize(this.edgeA);
    while k < count {
      if (this.edgeA[k] == a && this.edgeB[k] == b) || (this.edgeA[k] == b && this.edgeB[k] == a) {
        return true;
      }
      k += 1;
    }
    return false;
  }

  public func Neighbors(i: Int32) -> array<Int32> {
    let result: array<Int32>;
    let k = 0;
    let count = ArraySize(this.edgeA);
    while k < count {
      if this.edgeA[k] == i {
        ArrayPush(result, this.edgeB[k]);
      } else {
        if this.edgeB[k] == i {
          ArrayPush(result, this.edgeA[k]);
        }
      }
      k += 1;
    }
    return result;
  }

  // Só é possível invadir nós do V em disputa ou nós conectados a um nó do V.
  public func IsValidSub(s: Int32) -> Bool {
    return s >= 0 && s < ArraySize(this.subs);
  }

  public func SubOwner(s: Int32) -> Int32 {
    return this.subTaken[s] ? NWFaction.V() : this.owner[this.subs[s].parent];
  }

  // Regiões do nó i nas mãos do V: cada uma tira 1 do DV da invasão ao nó grande.
  public func VRegionCount(i: Int32) -> Int32 {
    let n = 0;
    let s = 0;
    while s < ArraySize(this.subs) {
      if this.subs[s].parent == i && this.subs[s].level == 1 && this.SubOwner(s) == NWFaction.V() {
        n += 1;
      }
      s += 1;
    }
    return n;
  }

  public func IsReachable(i: Int32) -> Bool {
    if !this.IsValid(i) {
      return false;
    }
    if this.owner[i] == NWFaction.V() {
      return true;
    }
    for j in this.Neighbors(i) {
      if this.owner[j] == NWFaction.V() {
        return true;
      }
    }
    return false;
  }

  // ------------------------------------------------------------ defesas

  public func Layer(i: Int32, slot: Int32) -> Int32 {
    return this.layers[i * NWDefense.SlotsPerNode() + slot];
  }

  public func SetLayer(i: Int32, slot: Int32, t: Int32) -> Void {
    this.layers[i * NWDefense.SlotsPerNode() + slot] = t;
  }

  public func CountLayers(i: Int32, t: Int32) -> Int32 {
    let n = 0;
    let slot = 0;
    while slot < NWDefense.SlotsPerNode() {
      if this.Layer(i, slot) == t {
        n += 1;
      }
      slot += 1;
    }
    return n;
  }

  public func LayerCount(i: Int32) -> Int32 {
    return NWDefense.SlotsPerNode() - this.CountLayers(i, NWDefense.None());
  }

  public func DefenseBonus(i: Int32) -> Int32 {
    let total = 0;
    let slot = 0;
    while slot < NWDefense.SlotsPerNode() {
      total += NWDefense.DefenseBonus(this.Layer(i, slot));
      slot += 1;
    }
    return total;
  }

  // Remove a primeira camada do tipo; devolve true se removeu.
  public func RemoveOneLayer(i: Int32, t: Int32) -> Bool {
    let slot = 0;
    while slot < NWDefense.SlotsPerNode() {
      if this.Layer(i, slot) == t {
        this.SetLayer(i, slot, NWDefense.None());
        return true;
      }
      slot += 1;
    }
    return false;
  }

  public func RemoveAllLayers(i: Int32, t: Int32) -> Void {
    while this.RemoveOneLayer(i, t) {}
  }

  public func ClearLayers(i: Int32) -> Void {
    let slot = 0;
    while slot < NWDefense.SlotsPerNode() {
      this.SetLayer(i, slot, NWDefense.None());
      slot += 1;
    }
  }

  public func Interface() -> Int32 {
    return this.interfaceBase + this.interfaceBonus;
  }

  public func TerritoryCount() -> Int32 {
    let total = 0;
    for f in this.owner {
      if f == NWFaction.V() {
        total += 1;
      }
    }
    return total;
  }

  public func AddTrace(amount: Int32) -> Void {
    let scaled = amount;
    if amount > 0 && this.traceReductionPct > 0 {
      scaled = (amount * (100 - this.traceReductionPct) + 50) / 100;
    }
    this.trace = Clamp(this.trace + scaled, 0, 100);
  }

  public func Day() -> Int32 {
    return Cast<Int32>(this.simHours) / 24;
  }

  public func TimeLabel() -> String {
    let total = Cast<Int32>(this.simHours);
    let day = total / 24;
    let hour = total % 24;
    let hh = hour < 10 ? s"0\(hour)" : s"\(hour)";
    return s"[D\(day) \(hh)h]";
  }

  public func AddLog(text: String) -> Void {
    ArrayPush(this.log, this.TimeLabel() + " " + text);
    while ArraySize(this.log) > 500 {
      ArrayErase(this.log, 0);
    }
  }
}
