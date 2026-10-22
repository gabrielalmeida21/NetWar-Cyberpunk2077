// NET War — sistema principal. Guarda o estado e expõe a API pública usada pelo painel de
// debug (CET) e, nas fases 4–5, pelas telas em ink. A UI só lê o estado e envia ações.
//
// Acesso:   GameInstance.GetScriptableSystemsContainer(gi).Get(n"NetWar.NetWarSystem")
// No CET:   Game.GetScriptableSystemsContainer():Get(CName.new("NetWar.NetWarSystem"))
module NetWar

import NetWar.Data.*
import NetWar.Core.*
import NetWar.Sim.*
import NetWar.Breach.*

public class NetWarSystem extends ScriptableSystem {
  private let state: ref<NWWorldState>;
  private let breach: ref<NWBreachSession>;
  // RAM com que a invasão começou (deck real + bônus de nós), para descontar o gasto do deck no fim.
  private let breachRamStart: Int32;
  // Sub-nó sendo invadido (−1 = nó do mundo).
  private let breachSub: Int32;
  private let tickIntervalHours: Float;
  private let lastGameStamp: Float;

  // ---- Persistência (fase 2). Só tipos simples; definições estáticas ficam no código.
  // Nós são identificados por NWNodeDef.code, não pela posição na lista.
  private persistent let saveSchema: Int32;
  private persistent let saveCodes: array<Int32>;
  private persistent let saveOwner: array<Int32>;
  private persistent let saveControl: array<Int32>;
  private persistent let saveIceLevel: array<Int32>;
  private persistent let saveFlags: array<Int32>;   // bit 1 = escaneado, bit 2 = bônus obtido
  private persistent let saveInts: array<Int32>;    // ordem em WriteSave()
  private persistent let saveFloats: array<Float>;  // ordem em WriteSave()
  // Computadores registrados como ponto de acesso (hash do EntityID). Independe da guerra:
  // ResetState não apaga.
  private persistent let saveAccessPoints: array<Int32>;
  // Códigos dos sub-nós tomados pelo V (NWSubDef.code).
  private persistent let saveSubTaken: array<Int32>;
  // Opções do jogador (bit 1 = testes no d10 em vez dos minigames).
  private persistent let saveOptions: Int32;
  // Minigame em andamento (não vai para o save).
  private let miniGame: ref<NWBufferGame>;
  private let headerGame: ref<NWHeaderGame>;
  private let zapGame: ref<NWZapGame>;
  private let slideGame: ref<NWSlideGame>;
  private let defenseGame: ref<NWDefenseGame>;
  private let circuitGame: ref<NWCircuitGame>;
  private let sonarGame: ref<NWSonarGame>;
  // Treino pela aba TUTORIAL: mesmo minigame, sem invasão nem consequências.
  private let practice: Bool;
  private let miniLastText: String;
  // Defesas (3 por nó, na ordem de saveCodes) e inteligência por nó.
  private persistent let saveLayers: array<Int32>;
  private persistent let saveIntelStyle: array<Int32>;
  private persistent let saveIntelMods: array<Int32>;
  private persistent let saveIntelFloors: array<Int32>;
  private persistent let saveIntelDepth: array<Int32>;
  private persistent let saveIntelVisits: array<Int32>;
  // Daemons (por id de NWDaemon) e equipados.
  private persistent let saveDaemonRarity: array<Int32>;
  private persistent let saveDaemonCopies: array<Int32>;
  private persistent let saveEquipped: array<Int32>;
  // Tempo de jogo (TimeSystem.GetGameTimeStamp, segundos) da última atualização da rede. 0 = nunca.
  private persistent let saveGameStamp: Float;

  // Ponto de acesso (fase 3), fora do save.
  private let lastComputerHash: Int32;
  private let lastComputerPath: String;
  private let hasLastComputer: Bool;
  private let accessEverywhere: Bool;
  private let connectCount: Int32;
  private let uiDebug: String;

  // Tela aberta no modo menu (NetWarMapPopup; guardada aqui para não ser coletada).
  private let menuScreen: ref<IScriptable>;
  // false = abrir como popup curvo do Codeware (alternativa caso o modo menu falhe).
  private let popupMode: Bool;

  public func SetMenuScreen(screen: ref<IScriptable>) -> Void { this.menuScreen = screen; }
  public func GetMenuScreen() -> ref<IScriptable> { return this.menuScreen; }
  public func UseMenuMode() -> Bool { return !this.popupMode; }
  public func SetMenuMode(value: Bool) -> Void { this.popupMode = !value; }


  // Interface: 0 = calculada do V (Inteligência + cyberdeck); > 0 = valor fixo do painel de debug.
  private let interfaceOverride: Int32;
  private let interfaceSource: String;

  public static func Version() -> String { return "0.6.0"; }
  public static func SchemaVersion() -> Int32 { return 1; }

  public static func GetInstance(gi: GameInstance) -> ref<NetWarSystem> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"NetWar.NetWarSystem") as NetWarSystem;
  }

  // A ordem entre OnAttach e OnRestored não é garantida aqui: os dois carregam do save,
  // e OnRestored sempre reaplica (os campos persistentes já foram lidos nesse ponto).
  private func OnAttach() -> Void {
    this.tickIntervalHours = 6.0;
    this.lastGameStamp = -1.0;
    if !IsDefined(this.state) {
      this.LoadOrDefault();
    }
    NWLog(s"NetWarSystem registrado (v\(NetWarSystem.Version()), esquema \(NetWarSystem.SchemaVersion())).");
  }

  private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
    this.lastGameStamp = -1.0;
    this.LoadOrDefault();
    NWLog(s"Save carregado (saveVersion \(saveVersion), gameVersion \(gameVersion), esquema NET War \(this.saveSchema)).");
  }

  // ---------------------------------------------------------------- estado geral

  public func ResetState() -> Void {
    this.state = new NWWorldState();
    this.state.Init();
    this.breach = null;
    this.WriteSave();
  }

  // ---------------------------------------------------------------- persistência

  private func LoadOrDefault() -> Void {
    this.breach = null;
    this.state = new NWWorldState();
    this.state.Init();
    if this.saveSchema <= 0 || ArraySize(this.saveCodes) == 0 {
      // Save sem dados do mod: estado padrão.
      this.WriteSave();
      return;
    }
    this.MigrateSave();
    this.ApplySave();
    this.state.AddLog(NWL.T("Estado da rede restaurado do save.", "Network state restored from the save."));
  }

  // Ponto único para converter esquemas antigos quando o formato mudar.
  private func MigrateSave() -> Void {
    if this.saveSchema < NetWarSystem.SchemaVersion() {
      NWLog(s"Migrando save do esquema \(this.saveSchema) para \(NetWarSystem.SchemaVersion()).");
      this.saveSchema = NetWarSystem.SchemaVersion();
    }
  }

  private func ApplySave() -> Void {
    let s = this.state;
    let k = 0;
    let n = ArraySize(this.saveCodes);
    while k < n {
      let i = this.IndexOfCode(this.saveCodes[k]);
      if i >= 0 {
        if k < ArraySize(this.saveOwner) { s.owner[i] = Clamp(this.saveOwner[k], 0, NWFaction.Count() - 1); }
        if k < ArraySize(this.saveControl) { s.control[i] = Clamp(this.saveControl[k], 0, 100); }
        let slots = NWDefense.SlotsPerNode();
        if ArraySize(this.saveLayers) >= (k + 1) * slots {
          let l = 0;
          while l < slots {
            s.SetLayer(i, l, Clamp(this.saveLayers[k * slots + l], 0, 3));
            l += 1;
          }
        } else {
          // Migração: o "Reforçar" antigo (iceLevel 0..3) vira camadas de Black ICE.
          if k < ArraySize(this.saveIceLevel) {
            let old = Clamp(this.saveIceLevel[k], 0, slots);
            let l = 0;
            while l < old {
              s.SetLayer(i, l, NWDefense.BlackIce());
              l += 1;
            }
          }
        }
        if k < ArraySize(this.saveIntelStyle) { s.intelStyle[i] = this.saveIntelStyle[k]; }
        if k < ArraySize(this.saveIntelMods) { s.intelMods[i] = this.saveIntelMods[k]; }
        if k < ArraySize(this.saveIntelFloors) { s.intelFloors[i] = this.saveIntelFloors[k]; }
        if k < ArraySize(this.saveIntelDepth) { s.intelDepth[i] = this.saveIntelDepth[k]; }
        if k < ArraySize(this.saveIntelVisits) { s.intelVisits[i] = this.saveIntelVisits[k]; }
        if k < ArraySize(this.saveFlags) {
          s.scanned[i] = (this.saveFlags[k] & 1) != 0;
          s.bonusClaimed[i] = (this.saveFlags[k] & 2) != 0;
        }
      }
      k += 1;
    }
    let ints = this.saveInts;
    if ArraySize(ints) >= 11 {
      s.trace = Clamp(ints[0], 0, 100);
      s.ram = ints[1];
      s.ramMax = ints[2];
      s.interfaceBase = ints[3];
      s.interfaceBonus = ints[4];
      s.eddies = ints[5];
      s.daemonSlots = ints[6];
      s.traceReductionPct = ints[7];
      s.pendingHealthPenalty = ints[8];
      s.lastIncomeDay = ints[9];
      s.incomeToday = ints[10];
    }
    if ArraySize(this.saveDaemonRarity) == NWDaemon.Count() && ArraySize(this.saveDaemonCopies) == NWDaemon.Count() {
      s.daemonRarity = this.saveDaemonRarity;
      s.daemonCopies = this.saveDaemonCopies;
    }
    ArrayClear(s.equipped);
    for id in this.saveEquipped {
      if id >= 0 && id < NWDaemon.Count() && s.daemonRarity[id] >= 0 && !ArrayContains(s.equipped, id) {
        ArrayPush(s.equipped, id);
      }
    }
    let floats = this.saveFloats;
    if ArraySize(floats) >= 6 {
      s.simHours = floats[0];
      s.tickAccum = floats[1];
      s.incomeAccum = floats[2];
      s.traceDecayAccum = floats[3];
      s.ramRegenAccum = floats[4];
      s.lockoutHours = floats[5];
    }
    let si = 0;
    while si < ArraySize(s.subs) {
      s.subTaken[si] = ArrayContains(this.saveSubTaken, s.subs[si].code);
      si += 1;
    }
  }

  // Chamado depois de toda mudança de estado, para o próximo save do jogo já levar tudo.
  // Uma invasão em andamento não é salva: se o jogo salvar no meio, ela é descartada.
  private func WriteSave() -> Void {
    let s = this.state;
    if !IsDefined(s) {
      return;
    }
    ArrayClear(this.saveCodes);
    ArrayClear(this.saveOwner);
    ArrayClear(this.saveControl);
    ArrayClear(this.saveIceLevel);
    ArrayClear(this.saveLayers);
    ArrayClear(this.saveIntelStyle);
    ArrayClear(this.saveIntelMods);
    ArrayClear(this.saveIntelFloors);
    ArrayClear(this.saveIntelDepth);
    ArrayClear(this.saveIntelVisits);
    ArrayClear(this.saveFlags);
    ArrayClear(this.saveSubTaken);
    let si = 0;
    while si < ArraySize(s.subs) {
      if s.subTaken[si] {
        ArrayPush(this.saveSubTaken, s.subs[si].code);
      }
      si += 1;
    }
    let i = 0;
    let n = s.NodeCount();
    while i < n {
      ArrayPush(this.saveCodes, s.defs[i].code);
      ArrayPush(this.saveOwner, s.owner[i]);
      ArrayPush(this.saveControl, s.control[i]);
      ArrayPush(this.saveIceLevel, s.CountLayers(i, NWDefense.BlackIce()));
      let l = 0;
      while l < NWDefense.SlotsPerNode() {
        ArrayPush(this.saveLayers, s.Layer(i, l));
        l += 1;
      }
      ArrayPush(this.saveIntelStyle, s.intelStyle[i]);
      ArrayPush(this.saveIntelMods, s.intelMods[i]);
      ArrayPush(this.saveIntelFloors, s.intelFloors[i]);
      ArrayPush(this.saveIntelDepth, s.intelDepth[i]);
      ArrayPush(this.saveIntelVisits, s.intelVisits[i]);
      ArrayPush(this.saveFlags, (s.scanned[i] ? 1 : 0) + (s.bonusClaimed[i] ? 2 : 0));
      i += 1;
    }
    ArrayClear(this.saveInts);
    ArrayPush(this.saveInts, s.trace);
    ArrayPush(this.saveInts, s.ram);
    ArrayPush(this.saveInts, s.ramMax);
    ArrayPush(this.saveInts, s.interfaceBase);
    ArrayPush(this.saveInts, s.interfaceBonus);
    ArrayPush(this.saveInts, s.eddies);
    ArrayPush(this.saveInts, s.daemonSlots);
    ArrayPush(this.saveInts, s.traceReductionPct);
    ArrayPush(this.saveInts, s.pendingHealthPenalty);
    ArrayPush(this.saveInts, s.lastIncomeDay);
    ArrayPush(this.saveInts, s.incomeToday);
    this.saveDaemonRarity = s.daemonRarity;
    this.saveDaemonCopies = s.daemonCopies;
    this.saveEquipped = s.equipped;
    ArrayClear(this.saveFloats);
    ArrayPush(this.saveFloats, s.simHours);
    ArrayPush(this.saveFloats, s.tickAccum);
    ArrayPush(this.saveFloats, s.incomeAccum);
    ArrayPush(this.saveFloats, s.traceDecayAccum);
    ArrayPush(this.saveFloats, s.ramRegenAccum);
    ArrayPush(this.saveFloats, s.lockoutHours);
    this.saveSchema = NetWarSystem.SchemaVersion();
  }

  private func IndexOfCode(code: Int32) -> Int32 {
    let i = 0;
    let n = this.state.NodeCount();
    while i < n {
      if this.state.defs[i].code == code {
        return i;
      }
      i += 1;
    }
    return -1;
  }

  public func GetSaveSchema() -> Int32 { return this.saveSchema; }

  public func GetModVersion() -> String { return NetWarSystem.Version(); }
  public func GetTrace() -> Int32 { return this.state.trace; }
  // RAM = memória real do cyberdeck do V (StatPoolsSystem, gamedataStatPoolType.Memory; conferido
  // no código-fonte em quickHackableHelper.script). O jogo regenera sozinho. Sem jogador: estado do mod.
  public func GetRam() -> Int32 {
    let player = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject();
    if !IsDefined(player) { return this.state.ram; }
    let pools = GameInstance.GetStatPoolsSystem(this.GetGameInstance());
    return Cast<Int32>(pools.GetStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Memory, false));
  }

  public func GetRamMax() -> Int32 {
    let player = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject();
    if !IsDefined(player) { return this.state.ramMax; }
    let pools = GameInstance.GetStatPoolsSystem(this.GetGameInstance());
    return RoundF(pools.GetStatPoolMaxPointValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Memory));
  }

  // RAM extra por jack-in, dada por nós dominados (Tóquio +2). Guardada como ramMax − 12 (base antiga).
  public func GetRamBonus() -> Int32 { return Max(0, this.state.ramMax - 12); }

  private func SpendDeckRam(amount: Int32) -> Void {
    if amount <= 0 { return; }
    let player = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject();
    if !IsDefined(player) {
      this.state.ram = Max(0, this.state.ram - amount);
      return;
    }
    let id = Cast<StatsObjectID>(player.GetEntityID());
    let pools = GameInstance.GetStatPoolsSystem(this.GetGameInstance());
    let current = pools.GetStatPoolValue(id, gamedataStatPoolType.Memory, false);
    let loss = MinF(Cast<Float>(amount), current);
    if loss > 0.0 {
      pools.RequestChangingStatPoolValue(id, gamedataStatPoolType.Memory, -loss, player, false, false);
    }
  }
  // Interface = 2 + Inteligência/4 + raridade do cyberdeck (+1..+3) + Canto Mk.6 (+2)
  //             + bônus de nós (Hong Kong, Brecha Sibéria).
  public func GetInterface() -> Int32 {
    let base = this.interfaceOverride > 0 ? this.interfaceOverride : this.ComputeInterfaceFromPlayer();
    return Clamp(base + this.state.interfaceBonus, 1, 20);
  }

  public func GetInterfaceSource() -> String {
    if this.interfaceOverride > 0 {
      return s"valor fixo do painel: \(this.interfaceOverride)";
    }
    this.ComputeInterfaceFromPlayer();
    return this.interfaceSource;
  }

  public func IsInterfaceAuto() -> Bool { return this.interfaceOverride <= 0; }
  public func SetInterfaceAuto() -> Void { this.interfaceOverride = 0; }

  // APIs conferidas no código-fonte dos scripts: StatsSystem.GetStatValue, EquipmentSystem.GetData
  // (...).GetActiveItem(SystemReplacementCW), TransactionSystem.GetItemData, RPGManager.GetItemQuality.
  private func ComputeInterfaceFromPlayer() -> Int32 {
    let gi = this.GetGameInstance();
    let player = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject();
    if !IsDefined(player) {
      this.interfaceSource = "jogador indisponível (padrão 6)";
      return 6;
    }
    let intel = Cast<Int32>(GameInstance.GetStatsSystem(gi).GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatType.Intelligence));
    let fromInt = 2 + intel / 4;
    let deckBonus = 0;
    let cantoBonus = 0;
    let deckText = "sem cyberdeck";
    let deckId = EquipmentSystem.GetData(player).GetActiveItem(gamedataEquipmentArea.SystemReplacementCW);
    if ItemID.IsValid(deckId) {
      let data = GameInstance.GetTransactionSystem(gi).GetItemData(player, deckId);
      let quality = RPGManager.GetItemQuality(data);
      deckBonus = NetWarSystem.DeckQualityBonus(quality);
      deckText = s"cyberdeck \(NetWarSystem.QualityName(quality)) +\(deckBonus)";
      if NetWarSystem.IsCantoDeck(deckId) {
        cantoBonus = 2;
        deckText = deckText + " · Canto Mk.6 +2";
      }
    }
    this.interfaceSource = s"INT \(intel) → \(fromInt) · \(deckText)";
    return fromInt + deckBonus + cantoBonus;
  }

  public static func DeckQualityBonus(q: gamedataQuality) -> Int32 {
    switch q {
      case gamedataQuality.Legendary:
      case gamedataQuality.LegendaryPlus:
      case gamedataQuality.LegendaryPlusPlus:
      case gamedataQuality.Iconic:
        return 3;
      case gamedataQuality.Rare:
      case gamedataQuality.RarePlus:
      case gamedataQuality.Epic:
      case gamedataQuality.EpicPlus:
        return 2;
      default:
        return 1;
    }
  }

  public static func QualityName(q: gamedataQuality) -> String {
    switch q {
      case gamedataQuality.Uncommon:
      case gamedataQuality.UncommonPlus:
        return "incomum";
      case gamedataQuality.Rare:
      case gamedataQuality.RarePlus:
        return "raro";
      case gamedataQuality.Epic:
      case gamedataQuality.EpicPlus:
        return "épico";
      case gamedataQuality.Legendary:
      case gamedataQuality.LegendaryPlus:
      case gamedataQuality.LegendaryPlusPlus:
        return "lendário";
      case gamedataQuality.Iconic:
        return "icônico";
      default:
        return "comum";
    }
  }

  // Militech Canto Mk.6: registros Items.HauntedCyberdeck* (mesmo critério do mod Blackwall Overdrive).
  public static func IsCantoDeck(deckId: ItemID) -> Bool {
    let tdb = ItemID.GetTDBID(deckId);
    if StrContains(StrLower(TDBID.ToStringDEBUG(tdb)), "hauntedcyberdeck") {
      return true;
    }
    let record = TweakDBInterface.GetItemRecord(tdb);
    return IsDefined(record) && StrContains(StrLower(record.FriendlyName()), "haunted");
  }
  public func GetEddies() -> Int32 { return this.state.eddies; }
  public func GetDaemonSlots() -> Int32 { return this.state.daemonSlots; }
  public func GetTerritoryCount() -> Int32 { return this.state.TerritoryCount(); }
  public func GetLockoutHours() -> Int32 { return Cast<Int32>(this.state.lockoutHours); }
  public func GetTimeLabel() -> String { return this.state.TimeLabel(); }
  public func GetPendingHealthPenalty() -> Int32 { return this.state.pendingHealthPenalty; }
  public func GetTickInterval() -> Float { return this.tickIntervalHours; }

  public func SetTickInterval(hours: Float) -> Void { this.tickIntervalHours = MaxF(1.0, hours); }
  public func SetInterfaceBase(value: Int32) -> Void { this.interfaceOverride = Clamp(value, 1, 20); }

  // ---------------------------------------------------------------- tempo

  public func AdvanceHours(hours: Float) -> Void {
    NWTerritorySim.Advance(this.state, hours, this.tickIntervalHours);
    this.WriteSave();
  }

  // Recebe o timestamp de jogo em segundos (quem chama decide de onde ele vem).
  // Saltos negativos (save carregado) ou enormes só reposicionam a base, sem simular.
  public func SyncGameTime(stampSeconds: Float) -> Void {
    if this.lastGameStamp < 0.0 {
      this.lastGameStamp = stampSeconds;
      return;
    }
    let hours = (stampSeconds - this.lastGameStamp) / 3600.0;
    this.lastGameStamp = stampSeconds;
    if hours <= 0.0 || hours > 72.0 {
      return;
    }
    this.AdvanceHours(hours);
  }

  // ---------------------------------------------------------------- nós

  public func GetNodeCount() -> Int32 { return this.state.NodeCount(); }

  public func GetNodeId(i: Int32) -> String { return this.state.IsValid(i) ? this.state.defs[i].id : ""; }
  public func GetNodeName(i: Int32) -> String { return this.state.IsValid(i) ? this.state.defs[i].Name() : ""; }
  public func GetNodeSubtitle(i: Int32) -> String { return this.state.IsValid(i) ? this.state.defs[i].Subtitle() : ""; }
  public func GetNodeOwner(i: Int32) -> Int32 { return this.state.IsValid(i) ? this.state.owner[i] : -1; }
  public func GetNodeControl(i: Int32) -> Int32 { return this.state.IsValid(i) ? this.state.control[i] : 0; }
  // Número de camadas de defesa montadas (compatível com o antigo "nível de ICE").
  public func GetNodeIceLevel(i: Int32) -> Int32 { return this.state.IsValid(i) ? this.state.LayerCount(i) : 0; }
  public func GetNodeX(i: Int32) -> Float { return this.state.IsValid(i) ? NWProjection.X(this.state.defs[i].lon) : 0.0; }
  public func GetNodeY(i: Int32) -> Float { return this.state.IsValid(i) ? NWProjection.Y(this.state.defs[i].lat) : 0.0; }
  public func IsNodeReachable(i: Int32) -> Bool { return this.state.IsReachable(i); }
  public func IsNodeScanned(i: Int32) -> Bool { return this.state.IsValid(i) && this.state.scanned[i]; }

  public func GetNodeOwnerName(i: Int32) -> String {
    if !this.state.IsValid(i) { return ""; }
    let f = this.state.owner[i];
    return f == NWFaction.V() ? NWL.T("Você", "You") : NWFaction.Name(f);
  }

  // Blackwall esconde andares e DV até ser escaneada.
  private func IsHidden(i: Int32) -> Bool {
    return this.state.owner[i] == NWFaction.Blackwall() && !this.state.scanned[i];
  }

  public func GetNodeFloorsText(i: Int32) -> String {
    if !this.state.IsValid(i) { return ""; }
    return this.IsHidden(i) ? "??" : s"\(this.state.defs[i].floors)";
  }

  public func GetNodeDVText(i: Int32) -> String {
    if !this.state.IsValid(i) { return ""; }
    if this.IsHidden(i) { return "??"; }
    let cut = this.state.VRegionCount(i);
    let dv = this.state.defs[i].dvBase;
    return cut > 0 && this.state.owner[i] != NWFaction.V() ? s"\(Max(3, dv - cut)) (-\(cut))" : s"\(dv)";
  }

  public func GetNodeIceText(i: Int32) -> String {
    if !this.state.IsValid(i) { return ""; }
    let def = this.state.defs[i];
    if this.state.owner[i] == NWFaction.V() {
      return NWL.T(s"Nenhum (suas defesas: \(this.state.LayerCount(i))/3)", s"None (your defenses: \(this.state.LayerCount(i))/3)");
    }
    let text = "";
    let k = 0;
    for ice in def.ice {
      let name = NWIce.Name(ice);
      if !this.state.scanned[i] && k >= 2 {
        name = NWL.T("[desconhecido]", "[unknown]");
      }
      text = k == 0 ? name : text + ", " + name;
      k += 1;
    }
    return text;
  }

  public func GetNodeRewardText(i: Int32) -> String {
    if !this.state.IsValid(i) { return ""; }
    let def = this.state.defs[i];
    let text = def.RewardText();
    if def.dailyIncome > 0 && !def.isHome {
      text = text + NWL.T(s" · renda €$ \(def.dailyIncome)/dia", s" · income €$ \(def.dailyIncome)/day");
    }
    if this.state.bonusClaimed[i] && def.bonusType != NWBonus.None() {
      text = text + NWL.T(" · bônus já obtido", " · bonus already claimed");
    }
    return text;
  }

  public func GetNodeCTA(i: Int32) -> String {
    if !this.state.IsValid(i) { return ""; }
    let f = this.state.owner[i];
    if f == NWFaction.V() {
      return this.state.control[i] >= 100 ? NWL.T("MONTAR DEFESAS", "SET UP DEFENSES") : NWL.T("RETOMAR INVASÃO", "RESUME BREACH");
    }
    return f == NWFaction.Blackwall() ? NWL.T("ARRISCAR JACK-IN", "RISK JACK-IN") : "JACK-IN";
  }

  // Conexões entre nós (para desenhar o mapa).
  public func GetEdgeCount() -> Int32 { return ArraySize(this.state.edgeA); }
  public func GetEdgeA(k: Int32) -> Int32 { return this.state.edgeA[k]; }
  public func GetEdgeB(k: Int32) -> Int32 { return this.state.edgeB[k]; }

  // ---------------------------------------------------------------- facções

  public func GetFactionCount() -> Int32 { return NWFaction.Count(); }
  public func GetFactionName(f: Int32) -> String { return NWFaction.Name(f); }
  public func GetFactionColor(f: Int32) -> String { return NWFaction.ColorHex(f); }
  public func GetFactionShape(f: Int32) -> String { return NWFaction.Shape(f); }

  // ---------------------------------------------------------------- registro da rede

  public func GetLogCount() -> Int32 { return ArraySize(this.state.log); }

  // 0 = evento mais recente.
  public func GetLogLine(k: Int32) -> String {
    let n = ArraySize(this.state.log);
    if k < 0 || k >= n { return ""; }
    return this.state.log[n - 1 - k];
  }

  // ---------------------------------------------------------------- ações no mapa

  public func ScanNode(i: Int32) -> String {
    if !this.state.IsValid(i) { return NWL.T("Nó inválido.", "Invalid node."); }
    if this.state.lockoutHours > 0.0 { return NWL.T("Acesso bloqueado pela Netwatch.", "Access locked by Netwatch."); }
    if this.state.scanned[i] { return NWL.T("Nó já escaneado.", "Node already scanned."); }
    if this.GetRam() < 2 { return NWL.T("RAM do cyberdeck insuficiente (precisa de 2).", "Not enough cyberdeck RAM (needs 2)."); }
    this.SpendDeckRam(2);
    this.state.scanned[i] = true;
    if this.state.intelStyle[i] < 0 {
      this.state.intelStyle[i] = this.state.owner[i];
      this.state.intelFloors[i] = Max(3, this.state.defs[i].floors + NWArchStyle.FloorsDelta(this.state.owner[i]));
    }
    this.state.AddLog(NWL.T(s"V escaneou \(NWText.Upper(this.state.defs[i].Name())).", s"V scanned \(NWText.Upper(this.state.defs[i].Name()))."));
    this.WriteSave();
    return NWL.T("Escaneamento concluído.", "Scan complete.");
  }

  public func ReinforceCost(i: Int32) -> Int32 {
    if !this.state.IsValid(i) { return 0; }
    return NWDefense.Cost(NWDefense.BlackIce());
  }

  public func ReinforceNode(i: Int32) -> String {
    if !this.state.IsValid(i) { return NWL.T("Nó inválido.", "Invalid node."); }
    if this.state.owner[i] != NWFaction.V() { return NWL.T("Só é possível reforçar nós do V.", "Only V's nodes can be reinforced."); }
    if this.state.LayerCount(i) >= NWDefense.SlotsPerNode() { return NWL.T("Todas as camadas de defesa estão ocupadas.", "All defense layers are taken."); }
    let cost = this.ReinforceCost(i);
    if this.state.eddies < cost { return NWL.T(s"Eddies insuficientes (precisa de €$ \(cost)).", s"Not enough eddies (needs €$ \(cost))."); }
    this.state.eddies -= cost;
    this.state.SetLayer(i, this.FirstFreeLayer(i), NWDefense.BlackIce());
    this.state.AddLog(NWL.T(s"V instalou Black ICE em \(NWText.Upper(this.state.defs[i].Name())).", s"V installed Black ICE at \(NWText.Upper(this.state.defs[i].Name()))."));
    this.WriteSave();
    return NWL.T("Nó reforçado.", "Node reinforced.");
  }

  // ---------------------------------------------------------------- invasão

  public func CanStartBreach(i: Int32) -> String {
    if !this.state.IsValid(i) { return NWL.T("Nó inválido.", "Invalid node."); }
    if this.IsBreachActive() { return NWL.T("Já existe uma invasão em andamento.", "A breach is already in progress."); }
    if this.state.lockoutHours > 0.0 { return NWL.T("Acesso bloqueado pela Netwatch.", "Access locked by Netwatch."); }
    if this.state.owner[i] == NWFaction.V() && this.state.control[i] >= 100 { return NWL.T("Nó já está sob seu controle total.", "Node is already under your full control."); }
    if !this.state.IsReachable(i) { return NWL.T("Nó fora de alcance: conecte-se a partir de um nó vizinho seu.", "Node out of reach: connect from one of your neighboring nodes."); }
    return "";
  }

  public func StartBreach(i: Int32) -> String {
    let reason = this.CanStartBreach(i);
    if StrLen(reason) > 0 { return reason; }
    this.breach = new NWBreachSession();
    this.breachSub = -1;
    let def = this.state.defs[i];
    let cut = this.state.VRegionCount(i);
    if cut > 0 {
      def = NWNodes.Clone(def);
      def.dvBase = Max(3, def.dvBase - cut);
    }
    this.breach.Start(def, i, this.GetInterface(), this.state.scanned[i], this.state.owner[i]);
    this.SetupBreachDaemons();
    if this.state.owner[i] == NWFaction.Netwatch() {
      this.state.AddTrace(5);
    }
    this.state.AddLog(NWL.T(s"V iniciou invasão em \(NWText.Upper(this.state.defs[i].Name())).", s"V started a breach at \(NWText.Upper(this.state.defs[i].Name()))."));
    this.WriteSave();
    return NWL.T("Invasão iniciada.", "Breach started.");
  }

  private func SetupBreachDaemons() -> Void {
    let rarities: array<Int32>;
    for id in this.state.equipped {
      ArrayPush(rarities, this.state.daemonRarity[id]);
    }
    this.breachRamStart = this.GetRam() + this.GetRamBonus();
    this.breach.SetupDaemons(this.breachRamStart, this.state.equipped, rarities);
  }

  public func IsBreachActive() -> Bool {
    return IsDefined(this.breach) && this.breach.IsRunning();
  }

  public func BreachAction(a: Int32) -> String {
    if !this.IsBreachActive() { return NWL.T("Nenhuma invasão em andamento.", "No breach in progress."); }
    if this.HasMiniGame() { return NWL.T("Termine o minigame primeiro.", "Finish the minigame first."); }
    this.breach.useDefenseGame = this.UseMinigames();
    this.miniLastText = "";
    if a == NWBreachAction.Backdoor() && this.UseMinigames() && this.breach.CanAct(a) {
      this.miniGame = NWBufferGame.Create(this.BackdoorParams(this.breach.Floor().dv));
      this.miniLastText = "";
      return "";
    }
    if a == NWBreachAction.Scan() && this.UseMinigames() && this.breach.CanAct(a) {
      this.sonarGame = NWSonarGame.Create(this.SonarParams());
      this.miniLastText = "";
      return "";
    }
    if a == NWBreachAction.Control() && this.UseMinigames() && this.breach.CanAct(a) {
      this.circuitGame = NWCircuitGame.Create(this.ControlParams(this.breach.Floor().dv));
      this.miniLastText = "";
      return "";
    }
    if a == NWBreachAction.Slide() && this.UseMinigames() && this.breach.CanAct(a) {
      this.slideGame = NWSlideGame.Create(this.SlideParams());
      this.miniLastText = "";
      return "";
    }
    if a == NWBreachAction.Zap() && this.UseMinigames() && this.breach.CanAct(a) {
      this.zapGame = NWZapGame.Create(this.ZapParams());
      this.miniLastText = "";
      return "";
    }
    if a == NWBreachAction.EyeDee() && this.UseMinigames() && this.breach.CanAct(a) {
      this.headerGame = NWHeaderGame.Create(this.EyeDeeParams(this.breach.Floor().dv));
      this.miniLastText = "";
      return "";
    }
    let ok = this.breach.Act(a);
    if !this.breach.IsRunning() {
      this.FinishBreach();
    }
    this.CheckPendingDefense();
    return ok ? "" : NWL.T(s"\(NWBreachAction.Name(a)): ação indisponível.", s"\(NWBreachAction.Name(a)): action unavailable.");
  }

  // ---------------------------------------------------------------- minigames (fase 6)
  // Atributos, Interface e equipamento mudam parâmetros diferentes (design de 2026-10-18):
  // Interface = tamanho do desafio; INT = dicas; Hab. técnica = buffer; cyberdeck = tempo;
  // Canto Mk.6 = +tempo; Verme = dicas em todos os passos. Stats conferidos nos scripts oficiais.

  public func UseMinigames() -> Bool { return (this.saveOptions & 1) == 0; }

  public func SetUseMinigames(on: Bool) -> Void {
    let dice = (this.saveOptions & 1) != 0;
    if on && dice { this.saveOptions -= 1; }
    if !on && !dice { this.saveOptions += 1; }
  }

  private func PlayerStat(stat: gamedataStatType) -> Int32 {
    let player = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject();
    if !IsDefined(player) {
      return 3;
    }
    return Cast<Int32>(GameInstance.GetStatsSystem(this.GetGameInstance()).GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), stat));
  }

  // Raridade do cyberdeck (0 sem deck / comum .. 3) e se é o Canto Mk.6.
  private func DeckRank(out canto: Bool) -> Int32 {
    canto = false;
    let gi = this.GetGameInstance();
    let player = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject();
    if !IsDefined(player) {
      return 0;
    }
    let deckId = EquipmentSystem.GetData(player).GetActiveItem(gamedataEquipmentArea.SystemReplacementCW);
    if !ItemID.IsValid(deckId) {
      return 0;
    }
    canto = NetWarSystem.IsCantoDeck(deckId);
    let data = GameInstance.GetTransactionSystem(gi).GetItemData(player, deckId);
    return Clamp(NetWarSystem.DeckQualityBonus(RPGManager.GetItemQuality(data)), 0, 3);
  }

  public func BackdoorParams(dv: Int32) -> ref<NWMiniParams> {
    let p = new NWMiniParams();
    let iface = this.MiniIface();
    let intel = this.PlayerStat(gamedataStatType.Intelligence);
    let tech = this.PlayerStat(gamedataStatType.TechnicalAbility);
    let canto: Bool;
    let rank = this.DeckRank(canto);

    // Interface: sequência mais curta (DV alto pede mais símbolos).
    p.seqLen = Clamp(2 + (dv - iface / 2) / 2, 2, 5);
    p.size = p.seqLen <= 3 ? 5 : 6;
    ArrayPush(p.notes, NWL.T(s"Interface \(iface) vs DV \(dv): sequência de \(p.seqLen)", s"Interface \(iface) vs DV \(dv): sequence of \(p.seqLen)"));
    // Habilidade técnica: buffer maior (+1 a cada 6, até +3).
    let techBonus = Min(3, tech / 6);
    p.bufferMax = p.seqLen + 2 + techBonus;
    ArrayPush(p.notes, NWL.T(s"Hab. técnica \(tech): buffer \(p.bufferMax) (+\(techBonus))", s"Technical Ability \(tech): buffer \(p.bufferMax) (+\(techBonus))"));
    // Inteligência: dicas nos primeiros passos (1 a cada 5, até 4).
    p.hints = Min(4, intel / 5);
    ArrayPush(p.notes, NWL.T(s"Inteligência \(intel): dica em \(p.hints) passo(s)", s"Intelligence \(intel): hints on \(p.hints) step(s)"));
    // Cyberdeck: tempo base; Canto Mk.6 soma tempo.
    p.timeLimit = 10.0 + 3.0 * Cast<Float>(rank) + (canto ? 4.0 : 0.0);
    ArrayPush(p.notes, NWL.T(s"Cyberdeck (raridade +\(rank)): \(RoundF(p.timeLimit)) s", s"Cyberdeck (rarity +\(rank)): \(RoundF(p.timeLimit)) s"));
    if canto {
      ArrayPush(p.notes, NWL.T("Canto Mk.6: +4 s e caminho verdadeiro em vermelho", "Canto Mk.6: +4 s and the true path in red"));
    }
    // Verme ativo: mostra o caminho inteiro.
    p.truePath = canto;
    p.fullHints = this.MiniWorm();
    if p.fullHints {
      ArrayPush(p.notes, NWL.T("Verme ativo: caminho completo", "Worm active: full path"));
    }
    return p;
  }

  // Eye-Dee: Interface = corrente mais curta; INT = próximo bloco destacado; Hab. técnica = erros
  // sem rastreio; Cool = o tempo só corre depois do 1º clique; cyberdeck = blocos já encaixados.
  public func EyeDeeParams(dv: Int32) -> ref<NWHeaderParams> {
    let p = new NWHeaderParams();
    let iface = this.MiniIface();
    let intel = this.PlayerStat(gamedataStatType.Intelligence);
    let tech = this.PlayerStat(gamedataStatType.TechnicalAbility);
    let cool = this.PlayerStat(gamedataStatType.Cool);
    let canto: Bool;
    let rank = this.DeckRank(canto);

    p.chainLen = Clamp(3 + (dv - iface / 2) / 3, 3, 6);
    p.decoys = p.chainLen >= 5 ? 3 : 2;
    ArrayPush(p.notes, NWL.T(s"Interface \(iface) vs DV \(dv): corrente de \(p.chainLen) blocos", s"Interface \(iface) vs DV \(dv): chain of \(p.chainLen) blocks"));
    p.hints = Min(3, intel / 6);
    ArrayPush(p.notes, NWL.T(s"Inteligência \(intel): próximo bloco destacado em \(p.hints) passo(s)", s"Intelligence \(intel): next block highlighted for \(p.hints) step(s)"));
    p.freeErrors = Min(2, tech / 7);
    ArrayPush(p.notes, NWL.T(s"Hab. técnica \(tech): \(p.freeErrors) erro(s) sem rastreio", s"Technical Ability \(tech): \(p.freeErrors) error(s) without trace"));
    p.startOnClick = cool >= 8;
    ArrayPush(p.notes, p.startOnClick
      ? NWL.T(s"Sangue-frio \(cool): o tempo só corre depois do 1º clique", s"Cool \(cool): the clock only runs after the first click")
      : NWL.T(s"Sangue-frio \(cool): o tempo já está correndo (8+ para esperar o 1º clique)", s"Cool \(cool): the clock is already running (8+ waits for the first click)"));
    p.preplaced = rank;
    ArrayPush(p.notes, NWL.T(s"Cyberdeck (raridade +\(rank)): \(rank) bloco(s) já encaixado(s)", s"Cyberdeck (rarity +\(rank)): \(rank) block(s) already placed"));
    p.timeLimit = 10.0 + 2.0 * Cast<Float>(p.chainLen) + (canto ? 4.0 : 0.0);
    if canto {
      ArrayPush(p.notes, NWL.T("Canto Mk.6: +4 s", "Canto Mk.6: +4 s"));
    }
    return p;
  }

  // Zap: Reflexos alargam a zona; Defesa do ICE estreita; Velocidade do ICE acelera o anel;
  // raridade do cyberdeck dá voltas; Canto Mk.6 +1 volta; Lâmina cria a 2ª zona; Interface soma no dano.
  public func ZapParams() -> ref<NWZapParams> {
    let p = new NWZapParams();
    let ice = this.MiniIceId();
    let refl = this.PlayerStat(gamedataStatType.Reflexes);
    let def = NWIce.Defense(ice);
    let spd = NWIce.Speed(ice) + this.MiniIceSpeedBonus();
    let canto: Bool;
    let rank = this.DeckRank(canto);

    p.zoneHalf = ClampF(14.0 + Cast<Float>(refl) * 1.2 - Cast<Float>(def - 8) * 1.5, 8.0, 40.0);
    ArrayPush(p.notes, NWL.T(s"Reflexos \(refl) vs DEF \(def) do ICE: zona de \(RoundF(p.zoneHalf * 2.0))°", s"Reflexes \(refl) vs ICE DEF \(def): \(RoundF(p.zoneHalf * 2.0))° zone"));
    p.speed = 150.0 + Cast<Float>(spd) * 20.0;
    ArrayPush(p.notes, NWL.T(s"Velocidade do ICE \(spd): anel a \(RoundF(p.speed))°/s", s"ICE speed \(spd): ring at \(RoundF(p.speed))°/s"));
    // A zona sempre tem pelo menos 1,2 passo do marcador (0,05 s): ele cai nela em toda volta.
    p.zoneHalf = MaxF(p.zoneHalf, p.speed * 0.05 * 0.6);
    p.laps = 2 + rank + (canto ? 1 : 0);
    ArrayPush(p.notes, NWL.T(s"Cyberdeck (raridade +\(rank)): \(p.laps) volta(s)", s"Cyberdeck (rarity +\(rank)): \(p.laps) lap(s)"));
    if canto {
      ArrayPush(p.notes, NWL.T("Canto Mk.6: +1 volta", "Canto Mk.6: +1 lap"));
    }
    p.double = this.MiniZapBonus() > 0;
    if p.double {
      ArrayPush(p.notes, NWL.T("Lâmina ativa: segunda zona do lado oposto", "Blade active: second zone on the opposite side"));
    }
    let iface = this.MiniIface();
    ArrayPush(p.notes, NWL.T(s"Interface \(iface): +\(iface / 3) de dano", s"Interface \(iface): +\(iface / 3) damage"));
    return p;
  }

  // Slide (corredor de scanners): Interface tira faixas; Sangue-frio deixa os feixes lentos;
  // Percepção do ICE deixa mais largos e rápidos; Inteligência 8+ mostra o rastro em 0,5 s;
  // cyberdeck e Canto Mk.6 dão tempo; Camuflagem/Fantasma fazem o feixe piscar.
  public func SlideParams() -> ref<NWSlideParams> {
    let p = new NWSlideParams();
    let cool = this.PlayerStat(gamedataStatType.Cool);
    let intel = this.PlayerStat(gamedataStatType.Intelligence);
    let per = NWIce.Perception(this.MiniIceId());
    let iface = this.MiniIface();
    let canto: Bool;
    let rank = this.DeckRank(canto);

    p.lanes = Clamp(5 - iface / 6, 3, 5);
    ArrayPush(p.notes, NWL.T(s"Interface \(iface): \(p.lanes) faixas", s"Interface \(iface): \(p.lanes) lanes"));
    p.speed = ClampF(0.45 + Cast<Float>(per) * 0.05 - Cast<Float>(cool) * 0.02, 0.25, 0.9);
    ArrayPush(p.notes, NWL.T(s"Sangue-frio \(cool) vs PER \(per): feixes a \(RoundF(p.speed * 100.0))% por s", s"Cool \(cool) vs PER \(per): beams at \(RoundF(p.speed * 100.0))% per s"));
    // Inteligência deixa os feixes mais estreitos (−0,003 por ponto acima de 5, até −0,03).
    let narrow = MinF(0.03, Cast<Float>(Max(0, intel - 5)) * 0.003);
    p.beamHalf = 0.07 + Cast<Float>(per) * 0.008 - narrow;
    p.ghost = false;
    ArrayPush(p.notes, NWL.T(s"Inteligência \(intel) vs PER \(per): feixe de \(RoundF(p.beamHalf * 200.0))% da faixa", s"Intelligence \(intel) vs PER \(per): beam \(RoundF(p.beamHalf * 200.0))% of the lane"));
    p.timeLimit = 8.0 + 2.0 * Cast<Float>(p.lanes) + 2.0 * Cast<Float>(rank) + (canto ? 3.0 : 0.0);
    ArrayPush(p.notes, NWL.T(s"Cyberdeck (raridade +\(rank)): \(RoundF(p.timeLimit)) s", s"Cyberdeck (rarity +\(rank)): \(RoundF(p.timeLimit)) s"));
    if canto {
      ArrayPush(p.notes, NWL.T("Canto Mk.6: +3 s", "Canto Mk.6: +3 s"));
    }
    p.blink = this.MiniStealth();
    if p.blink {
      ArrayPush(p.notes, NWL.T("Camuflagem/Fantasma: feixes piscam", "Cloak/Ghost: beams blink"));
    }
    return p;
  }

  public func GetSlideLanes() -> Int32 { return IsDefined(this.slideGame) ? this.slideGame.lanes : 0; }
  public func GetSlideLane() -> Int32 { return IsDefined(this.slideGame) ? this.slideGame.lane : 0; }
  public func GetSlideBeamPos(k: Int32) -> Float { return IsDefined(this.slideGame) ? this.slideGame.pos[k] : 0.0; }
  public func GetSlideBeamHalf() -> Float { return IsDefined(this.slideGame) ? this.slideGame.beamHalf : 0.0; }
  public func IsSlideBeamOn(k: Int32) -> Bool { return IsDefined(this.slideGame) && this.slideGame.IsBeamOn(k); }
  public func HasSlideGhost() -> Bool { return IsDefined(this.slideGame) && this.slideGame.ghost; }
  public func GetSlideGhostPos(k: Int32) -> Float { return IsDefined(this.slideGame) ? this.slideGame.FuturePos(k, 0.5) : 0.0; }

  public func SlideAdvance() -> Bool {
    if !IsDefined(this.slideGame) {
      return false;
    }
    this.slideGame.Advance();
    return this.ResolveMiniIfDone();
  }

  // 0 nenhum, 1 Backdoor (sequência de buffer), 2 Eye-Dee (cabeçalho), 3 Zap (anel), 4 Slide (grade),
  // 5 defesa contra o ataque do ICE, 6 Controlar (circuito), 7 Escanear (sonar).
  public func GetMiniKind() -> Int32 {
    if IsDefined(this.sonarGame) { return 7; }
    if IsDefined(this.circuitGame) { return 6; }
    if IsDefined(this.defenseGame) { return 5; }
    if IsDefined(this.slideGame) { return 4; }
    if IsDefined(this.miniGame) { return 1; }
    if IsDefined(this.headerGame) { return 2; }
    if IsDefined(this.zapGame) { return 3; }
    return 0;
  }

  // Intervalo do relógio da tela: o anel do Zap precisa de passos menores.
  public func GetMiniTickInterval() -> Float { return IsDefined(this.zapGame) || IsDefined(this.defenseGame) || IsDefined(this.slideGame) || IsDefined(this.sonarGame) ? 0.05 : 0.1; }

  public func GetZapAngle() -> Float { return IsDefined(this.zapGame) ? this.zapGame.angle : 0.0; }
  public func GetZapZoneAt(a: Float) -> Int32 { return IsDefined(this.zapGame) ? this.zapGame.ZoneAt(a) : 0; }
  public func GetZapLapsLeft() -> Int32 { return IsDefined(this.zapGame) ? this.zapGame.LapsLeft() : 0; }
  public func GetZapLaps() -> Int32 { return IsDefined(this.zapGame) ? this.zapGame.laps : 0; }

  public func ZapStrike() -> Bool {
    if !IsDefined(this.zapGame) {
      return false;
    }
    this.zapGame.Strike();
    return this.ResolveMiniIfDone();
  }

  public func GetHeaderBlockCount() -> Int32 { return IsDefined(this.headerGame) ? ArraySize(this.headerGame.first) : 0; }
  public func GetHeaderBlockText(b: Int32) -> String { return IsDefined(this.headerGame) ? this.headerGame.BlockText(b) : ""; }
  public func IsHeaderBlockGone(b: Int32) -> Bool { return IsDefined(this.headerGame) && this.headerGame.gone[b]; }
  public func IsHeaderBlockDecoy(b: Int32) -> Bool { return IsDefined(this.headerGame) && this.headerGame.decoy[b]; }
  public func IsHeaderHint(b: Int32) -> Bool { return IsDefined(this.headerGame) && this.headerGame.IsHint(b); }
  public func GetHeaderLastWrong() -> Int32 { return IsDefined(this.headerGame) ? this.headerGame.lastWrong : -1; }
  public func GetHeaderChainLen() -> Int32 { return IsDefined(this.headerGame) ? this.headerGame.chainLen : 0; }
  public func GetHeaderPlacedCount() -> Int32 { return IsDefined(this.headerGame) ? ArraySize(this.headerGame.order) : 0; }
  public func GetHeaderPlacedText(k: Int32) -> String { return IsDefined(this.headerGame) ? this.headerGame.BlockText(this.headerGame.order[k]) : ""; }
  public func GetHeaderPreplaced() -> Int32 { return IsDefined(this.headerGame) ? this.headerGame.preplaced : 0; }
  public func GetHeaderStartText() -> String { return IsDefined(this.headerGame) ? NWHeaderGame.CharText(this.headerGame.startChar) : ""; }
  public func GetHeaderEndText() -> String { return IsDefined(this.headerGame) ? NWHeaderGame.CharText(this.headerGame.endChar) : ""; }
  public func GetHeaderNeedText() -> String { return IsDefined(this.headerGame) ? NWHeaderGame.CharText(this.headerGame.Need()) : ""; }
  public func GetHeaderErrors() -> Int32 { return IsDefined(this.headerGame) ? this.headerGame.errors : 0; }
  public func GetHeaderFreeErrors() -> Int32 { return IsDefined(this.headerGame) ? this.headerGame.freeErrors : 0; }
  public func GetHeaderMaxErrors() -> Int32 { return IsDefined(this.headerGame) ? this.headerGame.maxErrors : 3; }

  // Devolve true se o minigame terminou com esta escolha.
  public func HeaderChoose(b: Int32) -> Bool {
    if !IsDefined(this.headerGame) {
      return false;
    }
    if !this.headerGame.Choose(b) && this.headerGame.IsRunning() {
      this.PlayUISound(n"ui_hacking_press_fail");
    }
    return this.ResolveMiniIfDone();
  }

  // ---------------------------------------------------------------- contexto dos minigames
  private func InBreachContext() -> Bool { return !this.practice && this.IsBreachActive(); }
  private func MiniIface() -> Int32 { return this.InBreachContext() ? this.breach.netInterface : this.GetInterface(); }
  // ICE do andar na invasão; no treino, o Ashjaw (atributos médios).
  private func MiniIceId() -> Int32 {
    if this.InBreachContext() && this.breach.Floor().kind == NWFloorKind.Ice() {
      return this.breach.Floor().iceId;
    }
    return 5;
  }
  private func MiniIceSpeedBonus() -> Int32 { return this.InBreachContext() ? this.breach.iceSpeedBonus : 0; }
  private func MiniIceAttackBonus() -> Int32 { return this.InBreachContext() ? this.breach.iceAttackBonus : 0; }
  private func MiniZapBonus() -> Int32 { return this.InBreachContext() ? this.breach.zapBonus : 0; }
  private func MiniWorm() -> Bool { return this.InBreachContext() && this.breach.wormTurns > 0; }
  private func MiniStealth() -> Bool { return this.InBreachContext() && (this.breach.cloaked || this.breach.IsGhosted()); }
  private func MiniOverload() -> Bool { return this.InBreachContext() && this.breach.IsDaemonActive(4); }

  public func IsPractice() -> Bool { return this.practice; }
  public func GetMiniIceName() -> String { return NWIce.Name(this.MiniIceId()); }
  public func GetMiniIceRezText() -> String {
    if this.InBreachContext() {
      let k = this.GetBreachCurrentFloor();
      return s"REZ \(this.GetBreachFloorRez(k)) / \(this.GetBreachFloorRezMax(k))";
    }
    return NWL.T("REZ (treino)", "REZ (practice)");
  }

  // Treino: 1 Backdoor, 2 Eye-Dee, 3 Zap, 4 Slide, 5 defesa, 6 Controlar, 7 Escanear.
  // DVs de exemplo médios; atributos, Interface e cyberdeck são os do V.
  public func StartPractice(kind: Int32) -> String {
    if this.HasMiniGame() {
      return NWL.T("Termine o minigame aberto primeiro.", "Finish the open minigame first.");
    }
    this.practice = true;
    this.miniLastText = "";
    switch kind {
      case 1: this.miniGame = NWBufferGame.Create(this.BackdoorParams(10)); break;
      case 2: this.headerGame = NWHeaderGame.Create(this.EyeDeeParams(8)); break;
      case 3: this.zapGame = NWZapGame.Create(this.ZapParams()); break;
      case 4: this.slideGame = NWSlideGame.Create(this.SlideParams()); break;
      case 5: this.defenseGame = NWDefenseGame.Create(this.DefenseParams()); break;
      case 6: this.circuitGame = NWCircuitGame.Create(this.ControlParams(12)); break;
      default: this.sonarGame = NWSonarGame.Create(this.SonarParams()); break;
    }
    return "";
  }

  public func HasMiniGame() -> Bool { return IsDefined(this.miniGame) || IsDefined(this.headerGame) || IsDefined(this.zapGame) || IsDefined(this.slideGame) || IsDefined(this.defenseGame) || IsDefined(this.circuitGame) || IsDefined(this.sonarGame); }

  // Escanear (sonar): Reflexos alargam a faixa; Interface e cyberdeck deixam o eco mais lento;
  // Inteligência baixa a meta para revelar tudo; Canto Mk.6 dá +1 pulso.
  public func SonarParams() -> ref<NWSonarParams> {
    let p = new NWSonarParams();
    let refl = this.PlayerStat(gamedataStatType.Reflexes);
    let intel = this.PlayerStat(gamedataStatType.Intelligence);
    let iface = this.MiniIface();
    let canto: Bool;
    let rank = this.DeckRank(canto);

    p.pulses = 3 + (canto ? 1 : 0);
    // Faixa mínima de 0,06: o eco anda ~0,04 por passo de 0,05 s e sempre cai nela.
    p.bandHalf = ClampF(0.06 + Cast<Float>(refl) * 0.003, 0.06, 0.12);
    ArrayPush(p.notes, NWL.T(s"Reflexos \(refl): faixa de \(RoundF(p.bandHalf * 200.0))% do raio", s"Reflexes \(refl): band \(RoundF(p.bandHalf * 200.0))% of the radius"));
    p.travel = ClampF(1.0 + Cast<Float>(iface) * 0.04 + Cast<Float>(rank) * 0.1, 1.0, 2.2);
    ArrayPush(p.notes, NWL.T(s"Interface \(iface) e deck (+\(rank)): eco em \(RoundF(p.travel * 10.0) / 10).\(RoundF(p.travel * 10.0) % 10) s", s"Interface \(iface) and deck (+\(rank)): echo in \(RoundF(p.travel * 10.0) / 10).\(RoundF(p.travel * 10.0) % 10) s"));
    p.goal = Max(2, 2 * p.pulses - Min(2, intel / 8));
    ArrayPush(p.notes, NWL.T(s"Inteligência \(intel): \(p.goal) pontos revelam a torre inteira", s"Intelligence \(intel): \(p.goal) points reveal the whole tower"));
    if canto {
      ArrayPush(p.notes, NWL.T("Canto Mk.6: +1 pulso", "Canto Mk.6: +1 pulse"));
    }
    return p;
  }

  public func GetSonarRadius() -> Float { return IsDefined(this.sonarGame) ? this.sonarGame.radius : 0.0; }
  public func GetSonarBandCenter() -> Float { return IsDefined(this.sonarGame) ? this.sonarGame.bandCenter : 0.0; }
  public func GetSonarBandHalf() -> Float { return IsDefined(this.sonarGame) ? this.sonarGame.bandHalf : 0.0; }
  public func GetSonarPulses() -> Int32 { return IsDefined(this.sonarGame) ? this.sonarGame.pulses : 0; }
  public func GetSonarMark(k: Int32) -> Int32 { return IsDefined(this.sonarGame) ? this.sonarGame.marks[k] : 0; }
  public func GetSonarScore() -> Int32 { return IsDefined(this.sonarGame) ? this.sonarGame.Score() : 0; }
  public func GetSonarGoal() -> Int32 { return IsDefined(this.sonarGame) ? this.sonarGame.goal : 0; }
  public func IsSonarWaiting() -> Bool { return IsDefined(this.sonarGame) && this.sonarGame.IsWaiting(); }

  public func SonarPing() -> Bool {
    if !IsDefined(this.sonarGame) {
      return false;
    }
    this.sonarGame.Ping();
    return this.ResolveMiniIfDone();
  }

  // Controlar: Interface (vs DV) diminui a grade; Hab. técnica trava peças do caminho no lugar;
  // Inteligência destaca casas do caminho; cyberdeck e Canto Mk.6 dão tempo; Sobrecarga +6 s.
  public func ControlParams(dv: Int32) -> ref<NWCircuitParams> {
    let p = new NWCircuitParams();
    let iface = this.MiniIface();
    let intel = this.PlayerStat(gamedataStatType.Intelligence);
    let tech = this.PlayerStat(gamedataStatType.TechnicalAbility);
    let canto: Bool;
    let rank = this.DeckRank(canto);

    p.size = Clamp(4 + (dv - iface) / 3, 4, 6);
    ArrayPush(p.notes, NWL.T(s"Interface \(iface) vs DV \(dv): grade \(p.size)x\(p.size)", s"Interface \(iface) vs DV \(dv): \(p.size)x\(p.size) grid"));
    p.locked = Min(3, tech / 6);
    ArrayPush(p.notes, NWL.T(s"Hab. técnica \(tech): \(p.locked) peça(s) já no lugar", s"Technical Ability \(tech): \(p.locked) piece(s) already in place"));
    p.hints = Min(4, intel / 5);
    ArrayPush(p.notes, NWL.T(s"Inteligência \(intel): \(p.hints) casa(s) do caminho marcadas", s"Intelligence \(intel): \(p.hints) path cell(s) marked"));
    p.timeLimit = 12.0 + 3.0 * Cast<Float>(p.size) + 4.0 * Cast<Float>(rank) + (canto ? 5.0 : 0.0);
    ArrayPush(p.notes, NWL.T(s"Cyberdeck (raridade +\(rank)): \(RoundF(p.timeLimit)) s", s"Cyberdeck (rarity +\(rank)): \(RoundF(p.timeLimit)) s"));
    if canto {
      ArrayPush(p.notes, NWL.T("Canto Mk.6: +5 s", "Canto Mk.6: +5 s"));
    }
    if this.MiniOverload() {
      p.timeLimit += 6.0;
      ArrayPush(p.notes, NWL.T("Sobrecarga ativa: +6 s", "Overload active: +6 s"));
    }
    return p;
  }

  public func GetCircuitSize() -> Int32 { return IsDefined(this.circuitGame) ? this.circuitGame.size : 0; }
  public func GetCircuitMask(i: Int32) -> Int32 { return IsDefined(this.circuitGame) ? this.circuitGame.masks[i] : 0; }
  public func IsCircuitLocked(i: Int32) -> Bool { return IsDefined(this.circuitGame) && this.circuitGame.locked[i]; }
  public func IsCircuitHint(i: Int32) -> Bool { return IsDefined(this.circuitGame) && this.circuitGame.IsHint(i); }
  public func GetCircuitSrcRow() -> Int32 { return IsDefined(this.circuitGame) ? this.circuitGame.srcRow : 0; }
  public func GetCircuitDstRow() -> Int32 { return IsDefined(this.circuitGame) ? this.circuitGame.dstRow : 0; }
  public func GetCircuitPowered() -> array<Bool> {
    let none: array<Bool>;
    return IsDefined(this.circuitGame) ? this.circuitGame.Powered() : none;
  }

  public func CircuitTurn(i: Int32) -> Bool {
    if !IsDefined(this.circuitGame) || !this.circuitGame.Turn(i) {
      return false;
    }
    return this.ResolveMiniIfDone();
  }

  // A sessão pausou no ataque do ICE: abre o minigame de defesa.
  private func CheckPendingDefense() -> Void {
    if this.IsBreachActive() && this.breach.pendingDefense && !IsDefined(this.defenseGame) {
      this.defenseGame = NWDefenseGame.Create(this.DefenseParams());
      this.miniLastText = "";
    }
  }

  // Defesa: Reflexos dão tempo; Ataque do ICE alonga a sequência; Interface 10+ tira um código;
  // Constituição reduz o dano que passa; raridade do cyberdeck e Canto Mk.6 dão um pouco de tempo.
  public func DefenseParams() -> ref<NWDefenseParams> {
    let p = new NWDefenseParams();
    let atk = NWIce.Attack(this.MiniIceId()) + this.MiniIceAttackBonus();
    let refl = this.PlayerStat(gamedataStatType.Reflexes);
    let body = this.PlayerStat(gamedataStatType.Strength);
    let iface = this.MiniIface();
    let canto: Bool;
    let rank = this.DeckRank(canto);

    p.total = Clamp(2 + atk / 2 - (iface >= 10 ? 1 : 0), 2, 5);
    ArrayPush(p.notes, NWL.T(s"Ataque do ICE \(atk), Interface \(iface): \(p.total) códigos", s"ICE attack \(atk), Interface \(iface): \(p.total) codes"));
    p.timeLimit = ClampF(1.6 + Cast<Float>(refl) * 0.12 + Cast<Float>(rank) * 0.2 + (canto ? 0.5 : 0.0), 1.5, 5.0);
    ArrayPush(p.notes, NWL.T(s"Reflexos \(refl) e deck (+\(rank)): \(RoundF(p.timeLimit * 10.0) / 10).\(RoundF(p.timeLimit * 10.0) % 10) s", s"Reflexes \(refl) and deck (+\(rank)): \(RoundF(p.timeLimit * 10.0) / 10).\(RoundF(p.timeLimit * 10.0) % 10) s"));
    p.bodyCut = body / 6;
    ArrayPush(p.notes, NWL.T(s"Constituição \(body): -\(p.bodyCut) de dano se o golpe passar", s"Body \(body): -\(p.bodyCut) damage if the hit lands"));
    ArrayPush(p.notes, NWL.T("Efeito do ICE só pega se errar metade ou mais", "ICE effect only lands if you miss half or more"));
    return p;
  }

  public func GetDefenseTotal() -> Int32 { return IsDefined(this.defenseGame) ? this.defenseGame.Total() : 0; }
  public func GetDefenseSeqText(k: Int32) -> String { return IsDefined(this.defenseGame) ? NWBufferGame.CodeText(this.defenseGame.seq[k]) : ""; }
  public func GetDefenseMark(k: Int32) -> Int32 { return IsDefined(this.defenseGame) ? this.defenseGame.marks[k] : 0; }
  public func GetDefenseIndex() -> Int32 { return IsDefined(this.defenseGame) ? this.defenseGame.index : 0; }
  public func GetDefensePoolCode(k: Int32) -> Int32 { return IsDefined(this.defenseGame) ? this.defenseGame.pool[k] : 0; }

  public func DefenseChoose(code: Int32) -> Bool {
    if !IsDefined(this.defenseGame) {
      return false;
    }
    this.defenseGame.Choose(code);
    return this.ResolveMiniIfDone();
  }
  public func GetMiniSize() -> Int32 { return IsDefined(this.miniGame) ? this.miniGame.size : 0; }
  public func GetMiniCellText(i: Int32) -> String { return IsDefined(this.miniGame) ? NWBufferGame.CodeText(this.miniGame.codes[i]) : ""; }
  public func IsMiniCellUsed(i: Int32) -> Bool { return IsDefined(this.miniGame) && this.miniGame.used[i]; }
  public func CanMiniPick(i: Int32) -> Bool { return IsDefined(this.miniGame) && this.miniGame.CanPick(i); }
  public func IsMiniCellActiveLine(i: Int32) -> Bool { return IsDefined(this.miniGame) && this.miniGame.IsRunning() && this.miniGame.InActiveLine(i); }
  public func IsMiniHint(i: Int32) -> Bool { return IsDefined(this.miniGame) && this.miniGame.IsHint(i); }
  public func IsMiniBestNext(i: Int32) -> Bool { return IsDefined(this.miniGame) && this.miniGame.IsBestNext(i); }
  public func GetMiniSeqLen() -> Int32 { return IsDefined(this.miniGame) ? ArraySize(this.miniGame.seq) : 0; }
  public func GetMiniSeqText(k: Int32) -> String { return IsDefined(this.miniGame) ? NWBufferGame.CodeText(this.miniGame.seq[k]) : ""; }
  public func GetMiniMatched() -> Int32 { return IsDefined(this.miniGame) ? this.miniGame.Matched() : 0; }
  public func GetMiniBufferMax() -> Int32 { return IsDefined(this.miniGame) ? this.miniGame.bufferMax : 0; }
  public func GetMiniPickCount() -> Int32 { return IsDefined(this.miniGame) ? ArraySize(this.miniGame.picks) : 0; }
  public func GetMiniPickText(k: Int32) -> String { return IsDefined(this.miniGame) ? NWBufferGame.CodeText(this.miniGame.codes[this.miniGame.picks[k]]) : ""; }
  public func GetMiniTimeLeft() -> Float {
    if IsDefined(this.slideGame) { return this.slideGame.timeLeft; }
    if IsDefined(this.circuitGame) { return this.circuitGame.timeLeft; }
    if IsDefined(this.defenseGame) { return this.defenseGame.timeLeft; }
    if IsDefined(this.miniGame) { return this.miniGame.timeLeft; }
    return IsDefined(this.headerGame) ? this.headerGame.timeLeft : 0.0;
  }
  public func GetMiniTimeLimit() -> Float {
    if IsDefined(this.slideGame) { return this.slideGame.timeLimit; }
    if IsDefined(this.circuitGame) { return this.circuitGame.timeLimit; }
    if IsDefined(this.defenseGame) { return this.defenseGame.timeLimit; }
    if IsDefined(this.miniGame) { return this.miniGame.timeLimit; }
    return IsDefined(this.headerGame) ? this.headerGame.timeLimit : 1.0;
  }
  public func IsMiniStarted() -> Bool {
    if IsDefined(this.slideGame) { return true; }
    if IsDefined(this.circuitGame) { return this.circuitGame.started; }
    if IsDefined(this.defenseGame) { return true; }
    return (IsDefined(this.miniGame) && this.miniGame.started) || (IsDefined(this.headerGame) && this.headerGame.started);
  }
  public func GetMiniNoteCount() -> Int32 {
    if IsDefined(this.sonarGame) { return ArraySize(this.sonarGame.notes); }
    if IsDefined(this.circuitGame) { return ArraySize(this.circuitGame.notes); }
    if IsDefined(this.defenseGame) { return ArraySize(this.defenseGame.notes); }
    if IsDefined(this.slideGame) { return ArraySize(this.slideGame.notes); }
    if IsDefined(this.zapGame) { return ArraySize(this.zapGame.notes); }
    if IsDefined(this.miniGame) { return ArraySize(this.miniGame.notes); }
    return IsDefined(this.headerGame) ? ArraySize(this.headerGame.notes) : 0;
  }
  public func GetMiniNote(k: Int32) -> String {
    if IsDefined(this.sonarGame) { return this.sonarGame.notes[k]; }
    if IsDefined(this.circuitGame) { return this.circuitGame.notes[k]; }
    if IsDefined(this.defenseGame) { return this.defenseGame.notes[k]; }
    if IsDefined(this.slideGame) { return this.slideGame.notes[k]; }
    if IsDefined(this.zapGame) { return this.zapGame.notes[k]; }
    if IsDefined(this.miniGame) { return this.miniGame.notes[k]; }
    return IsDefined(this.headerGame) ? this.headerGame.notes[k] : "";
  }
  public func GetMiniLastText() -> String { return this.miniLastText; }

  // Devolve true se o minigame terminou com esta escolha.
  public func MiniPick(i: Int32) -> Bool {
    if !IsDefined(this.miniGame) || !this.miniGame.Pick(i) {
      return false;
    }
    return this.ResolveMiniIfDone();
  }

  public func TickMiniGame(dt: Float) -> Bool {
    if IsDefined(this.sonarGame) {
      this.sonarGame.Tick(dt);
      return this.ResolveMiniIfDone();
    }
    if IsDefined(this.circuitGame) {
      this.circuitGame.Tick(dt);
      return this.ResolveMiniIfDone();
    }
    if IsDefined(this.defenseGame) {
      this.defenseGame.Tick(dt);
      return this.ResolveMiniIfDone();
    }
    if IsDefined(this.slideGame) {
      this.slideGame.Tick(dt);
      return this.ResolveMiniIfDone();
    }
    if IsDefined(this.zapGame) {
      this.zapGame.Tick(dt);
      return this.ResolveMiniIfDone();
    }
    if IsDefined(this.miniGame) {
      this.miniGame.Tick(dt);
    } else {
      if !IsDefined(this.headerGame) {
        return false;
      }
      this.headerGame.Tick(dt);
    }
    return this.ResolveMiniIfDone();
  }

  // Desistir, fechar a tela ou trocar de aba conta como falha.
  public func AbortMiniGame() -> Void {
    if IsDefined(this.miniGame) {
      this.miniGame.Abort();
    }
    if IsDefined(this.headerGame) {
      this.headerGame.Abort();
    }
    if IsDefined(this.zapGame) {
      this.zapGame.Abort();
    }
    if IsDefined(this.slideGame) {
      this.slideGame.Abort();
    }
    if IsDefined(this.defenseGame) {
      this.defenseGame.Abort();
    }
    if IsDefined(this.circuitGame) {
      this.circuitGame.Abort();
    }
    if IsDefined(this.sonarGame) {
      this.sonarGame.Abort();
    }
    this.ResolveMiniIfDone();
  }

  private func ResolveMiniIfDone() -> Bool {
    let done = this.ResolveMiniCore();
    if done {
      if this.practice {
        this.practice = false;
        this.miniLastText = NWL.T(s"TREINO: \(this.miniLastText)", s"PRACTICE: \(this.miniLastText)");
      }
      this.CheckPendingDefense();
    }
    return done;
  }

  private func ResolveMiniCore() -> Bool {
    if IsDefined(this.sonarGame) {
      return this.ResolveSonarIfDone();
    }
    if IsDefined(this.circuitGame) {
      return this.ResolveCircuitIfDone();
    }
    if IsDefined(this.defenseGame) {
      return this.ResolveDefenseIfDone();
    }
    if IsDefined(this.slideGame) {
      return this.ResolveSlideIfDone();
    }
    if IsDefined(this.zapGame) {
      return this.ResolveZapIfDone();
    }
    if IsDefined(this.headerGame) {
      return this.ResolveHeaderIfDone();
    }
    if !IsDefined(this.miniGame) {
      return false;
    }
    let g = this.miniGame;
    if g.IsRunning() {
      return false;
    }
    let ok = g.result == NWBufferResult.Success();
    let detail = NWL.T("sequência completa", "sequence complete");
    if g.result == NWBufferResult.TimeOut() { detail = NWL.T("tempo esgotado", "time ran out"); }
    if g.result == NWBufferResult.BufferFull() { detail = NWL.T("buffer cheio", "buffer full"); }
    if g.result == NWBufferResult.Aborted() { detail = NWL.T("conexão abandonada", "connection dropped"); }
    this.miniLastText = ok ? NWL.T("SENHA QUEBRADA", "PASSWORD BROKEN") : NWL.T(s"FALHA: \(detail)", s"FAILED: \(detail)");
    this.miniGame = null;
    if !this.practice && this.IsBreachActive() {
      this.breach.ResolveBackdoor(ok, detail);
      if !this.breach.IsRunning() {
        this.FinishBreach();
      }
    }
    this.PlayUISound(ok ? n"ui_focus_mode_quickhack" : n"ui_hacking_press_fail");
    return true;
  }

  private func ResolveSonarIfDone() -> Bool {
    let g = this.sonarGame;
    if g.IsRunning() {
      return false;
    }
    let score = g.Score();
    let goal = g.goal;
    this.miniLastText = score >= goal ? NWL.T("SONAR: TORRE INTEIRA", "SONAR: WHOLE TOWER")
      : NWL.T(s"SONAR: \(score)/\(goal) PONTOS", s"SONAR: \(score)/\(goal) POINTS");
    this.sonarGame = null;
    if !this.practice && this.IsBreachActive() {
      this.breach.ResolveScan(score, goal);
      if !this.breach.IsRunning() {
        this.FinishBreach();
      }
    }
    this.PlayUISound(n"ui_focus_mode_quickhack");
    return true;
  }

  private func ResolveCircuitIfDone() -> Bool {
    let g = this.circuitGame;
    if g.IsRunning() {
      return false;
    }
    let ok = g.result == NWCircuitResult.Linked();
    let detail = NWL.T("circuito ligado ao núcleo", "circuit linked to the core");
    if g.result == NWCircuitResult.TimeOut() { detail = NWL.T("tempo esgotado", "time ran out"); }
    if g.result == NWCircuitResult.Aborted() { detail = NWL.T("conexão abandonada", "connection dropped"); }
    this.miniLastText = ok ? NWL.T("NÚCLEO LIGADO", "CORE LINKED") : NWL.T(s"FALHA: \(detail)", s"FAILED: \(detail)");
    this.circuitGame = null;
    if !this.practice && this.IsBreachActive() {
      this.breach.ResolveControl(ok, detail);
      if !this.breach.IsRunning() {
        this.FinishBreach();
      }
    }
    this.PlayUISound(ok ? n"ui_focus_mode_quickhack" : n"ui_hacking_press_fail");
    return true;
  }

  private func ResolveDefenseIfDone() -> Bool {
    let g = this.defenseGame;
    if g.IsRunning() {
      return false;
    }
    let total = g.Total();
    this.miniLastText = g.hits >= total ? NWL.T("ESQUIVA TOTAL", "FULL DODGE")
      : NWL.T(s"DEFESA: \(g.hits)/\(total) CÓDIGOS", s"DEFENSE: \(g.hits)/\(total) CODES");
    let hits = g.hits;
    let cut = g.bodyCut;
    this.defenseGame = null;
    if !this.practice && this.IsBreachActive() {
      this.breach.ResolveIceDefense(hits, total, cut);
      if !this.breach.IsRunning() {
        this.FinishBreach();
      }
    }
    this.PlayUISound(hits >= total ? n"ui_focus_mode_quickhack" : n"ui_hacking_press_fail");
    return true;
  }

  private func ResolveSlideIfDone() -> Bool {
    let g = this.slideGame;
    if g.IsRunning() {
      return false;
    }
    let ok = g.result == NWSlideResult.Escaped();
    let detail = NWL.T("atravessou os scanners sem ser visto", "crossed the scanners unseen");
    if g.result == NWSlideResult.Detected() { detail = NWL.T("tocado por um feixe do ICE", "touched by an ICE beam"); }
    if g.result == NWSlideResult.TimeOut() { detail = NWL.T("tempo esgotado", "time ran out"); }
    if g.result == NWSlideResult.Aborted() { detail = NWL.T("conexão abandonada", "connection dropped"); }
    this.miniLastText = ok ? NWL.T("SLIDE: PASSOU PELO ICE", "SLIDE: GOT PAST THE ICE") : NWL.T(s"FALHA: \(detail)", s"FAILED: \(detail)");
    this.slideGame = null;
    if !this.practice && this.IsBreachActive() {
      this.breach.ResolveSlide(ok, detail);
      if !this.breach.IsRunning() {
        this.FinishBreach();
      }
    }
    this.PlayUISound(ok ? n"ui_focus_mode_quickhack" : n"ui_hacking_press_fail");
    return true;
  }

  private func ResolveZapIfDone() -> Bool {
    let g = this.zapGame;
    if g.IsRunning() {
      return false;
    }
    let quality = 0;
    let detail = NWL.T("fora da zona", "outside the zone");
    if g.result == NWZapResult.Critical() { quality = 2; detail = NWL.T("crítico", "critical"); }
    if g.result == NWZapResult.Hit() { quality = 1; detail = NWL.T("acerto", "hit"); }
    if g.result == NWZapResult.OutOfLaps() { detail = NWL.T("as voltas acabaram", "out of laps"); }
    if g.result == NWZapResult.Aborted() { detail = NWL.T("conexão abandonada", "connection dropped"); }
    this.miniLastText = quality == 2 ? NWL.T("ZAP CRÍTICO", "CRITICAL ZAP")
      : (quality == 1 ? NWL.T("ZAP ACERTOU", "ZAP HIT") : NWL.T(s"FALHA: \(detail)", s"FAILED: \(detail)"));
    this.zapGame = null;
    if !this.practice && this.IsBreachActive() {
      this.breach.ResolveZap(quality, detail);
      if !this.breach.IsRunning() {
        this.FinishBreach();
      }
    }
    this.PlayUISound(quality > 0 ? n"ui_focus_mode_quickhack" : n"ui_hacking_press_fail");
    return true;
  }

  private func ResolveHeaderIfDone() -> Bool {
    let g = this.headerGame;
    if g.IsRunning() {
      return false;
    }
    let ok = g.result == NWHeaderResult.Success();
    let detail = NWL.T("cabeçalho decifrado", "header decoded");
    if g.result == NWHeaderResult.TimeOut() { detail = NWL.T("tempo esgotado", "time ran out"); }
    if g.result == NWHeaderResult.Corrupted() { detail = NWL.T("arquivo corrompido (3 erros)", "file corrupted (3 errors)"); }
    if g.result == NWHeaderResult.Aborted() { detail = NWL.T("conexão abandonada", "connection dropped"); }
    this.miniLastText = ok ? NWL.T("ARQUIVO BAIXADO", "FILE DOWNLOADED") : NWL.T(s"FALHA: \(detail)", s"FAILED: \(detail)");
    let paid = g.PaidErrors();
    this.headerGame = null;
    if !this.practice && this.IsBreachActive() {
      this.breach.ResolveEyeDee(ok, detail, paid);
      if !this.breach.IsRunning() {
        this.FinishBreach();
      }
    }
    this.PlayUISound(ok ? n"ui_focus_mode_quickhack" : n"ui_hacking_press_fail");
    return true;
  }

  private func FinishBreach() -> Void {
    let b = this.breach;
    let i = b.nodeIndex;
    let def = b.def;
    let place = NWText.Upper(def.Name());
    let eddies = b.eddiesGained;
    let sub = this.breachSub;
    this.breachSub = -1;

    if sub >= 0 {
      if b.result == NWBreachResult.Captured() {
        eddies += def.rewardEddies;
        if b.isBlackwall {
          this.state.AddLog(NWL.T(s"V voltou vivo de \(place) com dados de além da Blackwall.", s"V came back alive from \(place) with data from beyond the Blackwall."));
        } else {
          this.state.subTaken[sub] = true;
          this.state.AddLog(NWL.T(s"V dominou \(place).", s"V took over \(place)."));
          if this.state.owner[i] != NWFaction.V() {
            this.ApplyPartialControl(i, NWSubNodes.ParentControlGain(this.state.subs[sub].level));
          }
        }
      }
    } else {
      if b.result == NWBreachResult.Captured() {
        if b.isBlackwall {
          let payout = this.state.bonusClaimed[i] ? def.rewardEddies / 4 : def.rewardEddies;
          eddies += payout;
          this.state.AddLog(NWL.T(s"V voltou vivo de \(place) com dados de além da Blackwall.", s"V came back alive from \(place) with data from beyond the Blackwall."));
        } else {
          this.state.owner[i] = NWFaction.V();
          this.state.control[i] = 100;
          eddies += def.rewardEddies;
          this.state.AddLog(NWL.T(s"V dominou \(place).", s"V took over \(place)."));
        }
        this.ClaimBonus(i);
      }

      if b.result == NWBreachResult.Disconnected() && !b.isBlackwall {
        let gained = b.PartialControl();
        if gained > 0 {
          this.ApplyPartialControl(i, gained);
        }
      }
    }

    // RAM gasta sai primeiro do bônus de nós; o resto sai da memória real do cyberdeck.
    this.SpendDeckRam(this.breachRamStart - b.ram - this.GetRamBonus());

    // Inteligência: o que foi visto desta arquitetura (só nós do mundo).
    if sub < 0 {
      let mask = 0;
      for m in b.mods {
        mask += NWDefense.Bit(m);
      }
      this.state.intelStyle[i] = b.style;
      this.state.intelMods[i] = mask;
      this.state.intelFloors[i] = ArraySize(b.floors);
      this.state.intelDepth[i] = Max(this.state.intelDepth[i], b.deepest + 1);
      this.state.intelVisits[i] += 1;
    }

    // Daemons coletados: garantidos ao dominar ou desconectar; perdidos se expulso.
    if b.result == NWBreachResult.Kicked() {
      if ArraySize(b.lootIds) > 0 {
        this.state.AddLog(NWL.T(s"\(ArraySize(b.lootIds)) daemon(s) coletado(s) perdido(s) na expulsão.", s"\(ArraySize(b.lootIds)) collected daemon(s) lost in the kick-out."));
      }
    } else {
      let li = 0;
      while li < ArraySize(b.lootIds) {
        this.GrantDaemon(b.lootIds[li], b.lootRarity[li]);
        li += 1;
      }
    }
    if b.result == NWBreachResult.Captured() {
      // Bônus ao dominar: 50% nos nós comuns, garantido na Blackwall.
      let chance = sub >= 0 ? (b.isBlackwall ? 50 : 20) : (b.isBlackwall ? 100 : 50);
      if RandRange(0, 100) < chance {
        this.GrantDaemon(NWDaemon.RollId(b.isBlackwall), NWDaemon.RollRarity(def.dvBase, b.isBlackwall));
      }
    }

    if b.result == NWBreachResult.Kicked() {
      this.state.AddTrace(15);
      if b.isBlackwall {
        this.state.pendingHealthPenalty += 1;
        this.ApplyBlackwallPenalty();
        this.state.AddLog(NWL.T(s"A Blackwall feriu o V em \(place).", s"The Blackwall hurt V at \(place)."));
      } else {
        this.state.AddLog(NWL.T(s"V foi expulso da rede em \(place).", s"V was kicked out of the net at \(place)."));
      }
    }

    this.state.AddTrace(b.traceGained);
    if eddies > 0 {
      this.state.eddies += eddies;
      this.state.AddLog(NWL.T(s"Invasão rendeu €$ \(eddies).", s"Breach yielded €$ \(eddies)."));
    }
    if this.state.trace >= 100 {
      NWTerritorySim.NetwatchOffensive(this.state);
    }
    this.WriteSave();
  }

  // ---------------------------------------------------------------- sub-nós (zoom REGIÃO e CIDADE)

  // Estado criado antes dos sub-nós existirem (ex.: scripts recarregados sem carregar o save):
  // monta a lista na hora e aplica o que o save já tem.
  private func EnsureSubs() -> Void {
    if ArraySize(this.state.subs) > 0 {
      return;
    }
    this.state.subs = NWSubNodes.Build(this.state.defs);
    ArrayClear(this.state.subTaken);
    for sub in this.state.subs {
      ArrayPush(this.state.subTaken, ArrayContains(this.saveSubTaken, sub.code));
    }
  }

  public func GetSubCount() -> Int32 {
    this.EnsureSubs();
    return ArraySize(this.state.subs);
  }

  // Primeiro sub-nó de um nível com aquele pai (região: parentSub −1; local: índice da região).
  public func GetFirstSub(parent: Int32, level: Int32, parentSub: Int32) -> Int32 {
    this.EnsureSubs();
    let s = 0;
    while s < ArraySize(this.state.subs) {
      let sub = this.state.subs[s];
      if sub.level == level && sub.parent == parent && (level == 1 || sub.parentSub == parentSub) {
        return s;
      }
      s += 1;
    }
    return -1;
  }
  public func GetSubLevel(s: Int32) -> Int32 { return this.state.IsValidSub(s) ? this.state.subs[s].level : 0; }
  public func GetSubParent(s: Int32) -> Int32 { return this.state.IsValidSub(s) ? this.state.subs[s].parent : -1; }
  public func GetSubParentSub(s: Int32) -> Int32 { return this.state.IsValidSub(s) ? this.state.subs[s].parentSub : -1; }
  public func GetSubName(s: Int32) -> String { return this.state.IsValidSub(s) ? this.state.subs[s].Name() : ""; }
  public func GetSubFullName(s: Int32) -> String { return this.state.IsValidSub(s) ? this.state.subs[s].FullName() : ""; }
  public func GetSubSubtitle(s: Int32) -> String { return this.state.IsValidSub(s) ? this.state.subs[s].def.Subtitle() : ""; }
  public func GetSubX(s: Int32) -> Float { return this.state.IsValidSub(s) ? this.state.subs[s].x : 0.0; }
  public func GetSubY(s: Int32) -> Float { return this.state.IsValidSub(s) ? this.state.subs[s].y : 0.0; }
  public func GetSubOwner(s: Int32) -> Int32 { return this.state.IsValidSub(s) ? this.state.SubOwner(s) : NWFaction.Neutral(); }
  public func IsSubTaken(s: Int32) -> Bool { return this.state.IsValidSub(s) && this.state.subTaken[s]; }

  public func GetSubOwnerName(s: Int32) -> String {
    if !this.state.IsValidSub(s) { return ""; }
    let f = this.state.SubOwner(s);
    return f == NWFaction.V() ? NWL.T("Você", "You") : NWFaction.Name(f);
  }

  private func IsSubHidden(s: Int32) -> Bool {
    return this.state.SubOwner(s) == NWFaction.Blackwall() && !this.state.scanned[this.state.subs[s].parent];
  }

  public func GetSubFloorsText(s: Int32) -> String {
    if !this.state.IsValidSub(s) { return ""; }
    return this.IsSubHidden(s) ? "??" : s"\(this.state.subs[s].def.floors)";
  }

  public func GetSubDVText(s: Int32) -> String {
    if !this.state.IsValidSub(s) { return ""; }
    return this.IsSubHidden(s) ? "??" : s"\(this.state.subs[s].def.dvBase)";
  }

  public func GetSubIceText(s: Int32) -> String {
    if !this.state.IsValidSub(s) { return ""; }
    if this.state.SubOwner(s) == NWFaction.V() { return NWL.T("Nenhum (sob seu controle)", "None (under your control)"); }
    let text = "";
    let k = 0;
    for ice in this.state.subs[s].def.ice {
      text = k == 0 ? NWIce.Name(ice) : text + ", " + NWIce.Name(ice);
      k += 1;
    }
    return text;
  }

  public func GetSubRewardText(s: Int32) -> String {
    if !this.state.IsValidSub(s) { return ""; }
    let sub = this.state.subs[s];
    let parentName = this.state.defs[sub.parent].Name();
    if sub.level == 1 {
      return NWL.T(s"€$ \(sub.def.rewardEddies) · +\(NWSubNodes.ParentControlGain(1))% de controle em \(parentName) e -1 DV na invasão a \(parentName)", s"€$ \(sub.def.rewardEddies) · +\(NWSubNodes.ParentControlGain(1))% control over \(parentName) and -1 DV when breaching \(parentName)");
    }
    return NWL.T(s"€$ \(sub.def.rewardEddies) · +\(NWSubNodes.ParentControlGain(2))% de controle em \(parentName)", s"€$ \(sub.def.rewardEddies) · +\(NWSubNodes.ParentControlGain(2))% control over \(parentName)");
  }

  public func CanStartSubBreach(s: Int32) -> String {
    if !this.state.IsValidSub(s) { return NWL.T("Nó inválido.", "Invalid node."); }
    if this.IsBreachActive() { return NWL.T("Já existe uma invasão em andamento.", "A breach is already in progress."); }
    if this.state.lockoutHours > 0.0 { return NWL.T("Acesso bloqueado pela Netwatch.", "Access locked by Netwatch."); }
    if this.state.SubOwner(s) == NWFaction.V() { return NWL.T("Sub-nó já está sob seu controle.", "Sub-node is already under your control."); }
    let sub = this.state.subs[s];
    if !this.state.IsReachable(sub.parent) { return NWL.T("Fora de alcance: conecte-se a um nó vizinho seu primeiro.", "Out of reach: connect to one of your neighboring nodes first."); }
    if sub.level == 2 && this.state.SubOwner(sub.parentSub) != NWFaction.V() {
      return NWL.T(s"Domine antes a região \(this.state.subs[sub.parentSub].Name()).", s"Take the \(this.state.subs[sub.parentSub].Name()) region first.");
    }
    return "";
  }

  public func GetSubCTA(s: Int32) -> String {
    if !this.state.IsValidSub(s) { return ""; }
    if this.state.SubOwner(s) == NWFaction.V() { return NWL.T("SOB SEU CONTROLE", "UNDER YOUR CONTROL"); }
    return StrLen(this.CanStartSubBreach(s)) == 0 ? NWL.T("INICIAR INVASÃO", "START BREACH") : NWL.T("BLOQUEADO", "LOCKED");
  }

  public func StartSubBreach(s: Int32) -> String {
    let reason = this.CanStartSubBreach(s);
    if StrLen(reason) > 0 { return reason; }
    let sub = this.state.subs[s];
    let i = sub.parent;
    this.breach = new NWBreachSession();
    this.breachSub = s;
    this.breach.Start(sub.def, i, this.GetInterface(), this.state.scanned[i], this.state.SubOwner(s));
    this.SetupBreachDaemons();
    this.state.AddLog(NWL.T(s"V iniciou invasão em \(NWText.Upper(sub.FullName())).", s"V started a breach at \(NWText.Upper(sub.FullName()))."));
    this.WriteSave();
    return "";
  }

  // ---------------------------------------------------------------- defesas (aba ARQUITETURAS)

  private func FirstFreeLayer(i: Int32) -> Int32 {
    let slot = 0;
    while slot < NWDefense.SlotsPerNode() {
      if this.state.Layer(i, slot) == NWDefense.None() {
        return slot;
      }
      slot += 1;
    }
    return -1;
  }

  public func GetDefenseLayer(i: Int32, slot: Int32) -> Int32 { return this.state.IsValid(i) ? this.state.Layer(i, slot) : 0; }
  public func GetDefenseName(t: Int32) -> String { return NWDefense.Name(t); }
  public func GetDefenseDescription(t: Int32) -> String { return NWDefense.Description(t); }
  public func GetDefenseCost(t: Int32) -> Int32 { return NWDefense.Cost(t); }

  public func BuildDefense(i: Int32, slot: Int32, t: Int32) -> String {
    if !this.state.IsValid(i) || slot < 0 || slot >= NWDefense.SlotsPerNode() { return NWL.T("Camada inválida.", "Invalid layer."); }
    if this.state.owner[i] != NWFaction.V() { return NWL.T("Só é possível montar defesas em nós do V.", "Defenses can only be set up on V's nodes."); }
    if this.state.Layer(i, slot) != NWDefense.None() { return NWL.T("Camada ocupada: remova antes.", "Layer taken: remove it first."); }
    let cost = NWDefense.Cost(t);
    if this.state.eddies < cost { return NWL.T(s"Banco NetWatch sem saldo (precisa de €$ \(cost)).", s"Not enough funds in the NetWatch Bank (needs €$ \(cost))."); }
    this.state.eddies -= cost;
    this.state.SetLayer(i, slot, t);
    this.state.AddLog(NWL.T(s"V instalou \(NWDefense.Name(t)) em \(NWText.Upper(this.state.defs[i].Name())).", s"V installed \(NWDefense.Name(t)) at \(NWText.Upper(this.state.defs[i].Name()))."));
    this.WriteSave();
    return NWL.T(s"\(NWDefense.Name(t)) instalada (−€$ \(cost)).", s"\(NWDefense.Name(t)) installed (−€$ \(cost)).");
  }

  public func RemoveDefense(i: Int32, slot: Int32) -> String {
    if !this.state.IsValid(i) || slot < 0 || slot >= NWDefense.SlotsPerNode() { return NWL.T("Camada inválida.", "Invalid layer."); }
    let t = this.state.Layer(i, slot);
    if t == NWDefense.None() { return NWL.T("Camada já está vazia.", "Layer is already empty."); }
    this.state.SetLayer(i, slot, NWDefense.None());
    this.WriteSave();
    return NWL.T(s"\(NWDefense.Name(t)) removida.", s"\(NWDefense.Name(t)) removed.");
  }

  public func GetNodeDefenseSummary(i: Int32) -> String {
    if !this.state.IsValid(i) { return ""; }
    let decoys = this.state.CountLayers(i, NWDefense.Decoy());
    let miss = 100;
    let n = 0;
    while n < decoys {
      miss = (miss * 65) / 100;
      n += 1;
    }
    let bonus = 2 + this.state.DefenseBonus(i) + (this.state.defs[i].isHome ? 4 : 0);
    return NWL.T(s"Defesa +\(bonus) no d10 · Black ICE absorve \(this.state.CountLayers(i, NWDefense.BlackIce())) ataque(s) · iscas desviam \(100 - miss)%", s"Defense +\(bonus) on the d10 · Black ICE absorbs \(this.state.CountLayers(i, NWDefense.BlackIce())) attack(s) · decoys divert \(100 - miss)%");
  }

  // Inteligência dos nós (escanear revela o estilo; invadir revela o resto).
  public func HasIntel(i: Int32) -> Bool { return this.state.IsValid(i) && this.state.intelStyle[i] >= 0; }
  public func GetIntelStyleName(i: Int32) -> String { return this.HasIntel(i) ? NWArchStyle.Name(this.state.intelStyle[i]) : ""; }
  public func GetIntelStyleDescription(i: Int32) -> String { return this.HasIntel(i) ? NWArchStyle.Description(this.state.intelStyle[i]) : ""; }
  public func GetLikelyStyleName(i: Int32) -> String {
    if !this.state.IsValid(i) { return ""; }
    return this.IsHidden(i) ? "??" : NWArchStyle.Name(this.state.owner[i]);
  }
  // O nó trocou de dono depois da inteligência: a arquitetura provavelmente foi refeita.
  public func IsIntelStale(i: Int32) -> Bool { return this.HasIntel(i) && this.state.intelStyle[i] != this.state.owner[i]; }
  public func GetNodeDefenseCount(i: Int32) -> Int32 { return this.state.IsValid(i) ? this.state.LayerCount(i) : 0; }
  public func GetIntelFloors(i: Int32) -> Int32 { return this.state.IsValid(i) ? this.state.intelFloors[i] : 0; }
  public func GetIntelDepth(i: Int32) -> Int32 { return this.state.IsValid(i) ? this.state.intelDepth[i] : 0; }
  public func GetIntelVisits(i: Int32) -> Int32 { return this.state.IsValid(i) ? this.state.intelVisits[i] : 0; }

  public func GetIntelModsText(i: Int32) -> String {
    if !this.state.IsValid(i) || this.state.intelVisits[i] == 0 { return NWL.T("Desconhecidos (invada para descobrir)", "Unknown (breach to find out)"); }
    let text = "";
    let m = 0;
    while m <= NWArchMod.Unstable() {
      if (this.state.intelMods[i] & NWDefense.Bit(m)) != 0 {
        text = text + (StrLen(text) > 0 ? ", " : "") + NWArchMod.Name(m);
      }
      m += 1;
    }
    return StrLen(text) > 0 ? text : NWL.T("Nenhum na última invasão", "None in the last breach");
  }

  // ---------------------------------------------------------------- daemons

  // Repetidos se fundem: 2 cópias sobem uma raridade; num lendário, cada cópia vira €$ 1.000 no banco.
  public func GrantDaemon(id: Int32, rarity: Int32) -> Void {
    let s = this.state;
    if id < 0 || id >= NWDaemon.Count() {
      return;
    }
    let name = NWDaemon.Name(id);
    let owned = s.daemonRarity[id];
    if owned < 0 {
      s.daemonRarity[id] = rarity;
      s.daemonCopies[id] = 0;
      s.AddLog(NWL.T(s"Novo daemon: \(name) (\(NWDaemon.RarityName(rarity))).", s"New daemon: \(name) (\(NWDaemon.RarityName(rarity)))."));
      return;
    }
    if rarity > owned {
      s.daemonRarity[id] = rarity;
      s.daemonCopies[id] = 0;
      s.AddLog(NWL.T(s"\(name) subiu para \(NWDaemon.RarityName(rarity)).", s"\(name) upgraded to \(NWDaemon.RarityName(rarity))."));
      return;
    }
    if owned >= NWDaemon.MaxRarity() {
      s.eddies += 1000;
      s.AddLog(NWL.T(s"\(name) já é lendário: cópia convertida em €$ 1000 no Banco NetWatch.", s"\(name) is already legendary: copy converted into €$ 1000 in the NetWatch Bank."));
      return;
    }
    s.daemonCopies[id] += 1;
    if s.daemonCopies[id] >= 2 {
      s.daemonRarity[id] = owned + 1;
      s.daemonCopies[id] = 0;
      s.AddLog(NWL.T(s"Fusão: \(name) subiu para \(NWDaemon.RarityName(owned + 1)).", s"Fusion: \(name) upgraded to \(NWDaemon.RarityName(owned + 1))."));
    } else {
      s.AddLog(NWL.T(s"Cópia de \(name) (1/2 para fundir).", s"Copy of \(name) (1/2 to fuse)."));
    }
  }

  public func GetDaemonCount() -> Int32 { return NWDaemon.Count(); }
  public func GetDaemonName(id: Int32) -> String { return NWDaemon.Name(id); }
  public func GetDaemonDescription(id: Int32) -> String { return NWDaemon.Description(id); }
  public func GetDaemonBaseRam(id: Int32) -> Int32 { return NWDaemon.BaseRam(id); }
  public func IsDaemonBlackwallOnly(id: Int32) -> Bool { return id == NWDaemon.BlackwallOnly(); }
  public func GetDaemonRarity(id: Int32) -> Int32 { return id >= 0 && id < NWDaemon.Count() ? this.state.daemonRarity[id] : -1; }
  public func GetDaemonRarityName(id: Int32) -> String { return NWDaemon.RarityName(this.GetDaemonRarity(id)); }
  public func GetDaemonCopies(id: Int32) -> Int32 { return id >= 0 && id < NWDaemon.Count() ? this.state.daemonCopies[id] : 0; }
  public func GetDaemonRamCost(id: Int32) -> Int32 { return NWDaemon.RamCost(id, Max(0, this.GetDaemonRarity(id))); }
  public func IsDaemonEquipped(id: Int32) -> Bool { return ArrayContains(this.state.equipped, id); }
  public func GetEquippedCount() -> Int32 { return ArraySize(this.state.equipped); }
  public func GetEquippedId(k: Int32) -> Int32 { return k >= 0 && k < ArraySize(this.state.equipped) ? this.state.equipped[k] : -1; }

  public func EquipDaemon(id: Int32) -> String {
    if this.GetDaemonRarity(id) < 0 { return NWL.T("Daemon ainda não encontrado.", "Daemon not found yet."); }
    if this.IsDaemonEquipped(id) { return NWL.T("Já equipado.", "Already equipped."); }
    if ArraySize(this.state.equipped) >= this.state.daemonSlots { return NWL.T(s"Slots cheios (\(this.state.daemonSlots)).", s"Slots full (\(this.state.daemonSlots))."); }
    ArrayPush(this.state.equipped, id);
    this.WriteSave();
    return NWL.T(s"\(NWDaemon.Name(id)) equipado.", s"\(NWDaemon.Name(id)) equipped.");
  }

  public func UnequipDaemon(id: Int32) -> String {
    if !this.IsDaemonEquipped(id) { return NWL.T("Não está equipado.", "Not equipped."); }
    ArrayRemove(this.state.equipped, id);
    this.WriteSave();
    return NWL.T(s"\(NWDaemon.Name(id)) removido.", s"\(NWDaemon.Name(id)) removed.");
  }

  public func DebugGiveDaemon(id: Int32, rarity: Int32) -> Void {
    this.GrantDaemon(id, Clamp(rarity, 0, NWDaemon.MaxRarity()));
    this.WriteSave();
  }

  // Daemons na sessão de invasão.
  public func GetBreachRam() -> Int32 { return IsDefined(this.breach) ? this.breach.ram : this.GetRam(); }
  public func GetBreachRamMax() -> Int32 { return this.GetRamMax() + this.GetRamBonus(); }
  public func GetBreachDaemonCount() -> Int32 { return IsDefined(this.breach) ? ArraySize(this.breach.equippedIds) : 0; }
  public func GetBreachDaemonId(k: Int32) -> Int32 { return IsDefined(this.breach) && k >= 0 && k < ArraySize(this.breach.equippedIds) ? this.breach.equippedIds[k] : -1; }
  public func GetBreachDaemonCost(id: Int32) -> Int32 { return IsDefined(this.breach) ? this.breach.DaemonCost(id) : 0; }
  public func CanBreachUseDaemon(id: Int32) -> Bool { return this.IsBreachActive() && this.breach.CanUseDaemon(id); }
  public func IsBreachDaemonActive(id: Int32) -> Bool { return IsDefined(this.breach) && this.breach.IsDaemonActive(id); }

  public func BreachUseDaemon(id: Int32) -> String {
    if !this.IsBreachActive() { return NWL.T("Nenhuma invasão em andamento.", "No breach in progress."); }
    if !this.breach.UseDaemon(id) {
      return NWL.T(s"\(NWDaemon.Name(id)): indisponível agora.", s"\(NWDaemon.Name(id)): unavailable right now.");
    }
    return "";
  }

  public func GetBreachLootCount() -> Int32 { return IsDefined(this.breach) ? ArraySize(this.breach.lootIds) : 0; }

  // ---------------------------------------------------------------- Banco NetWatch
  // O saldo da rede (state.eddies) fica no "Banco NetWatch": recebe arquivos, recompensas e renda,
  // paga os reforços. Saque/depósito movem eddies reais do V via TransactionSystem com
  // MarketSystem.Money() (GetItemQuantity/GiveItem/RemoveItem, conferidos no código-fonte).
  // Durante o bloqueio da Netwatch o banco fica congelado.

  public func GetPlayerMoney() -> Int32 {
    let gi = this.GetGameInstance();
    let player = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject();
    if !IsDefined(player) {
      return 0;
    }
    return GameInstance.GetTransactionSystem(gi).GetItemQuantity(player, MarketSystem.Money());
  }

  public func IsBankFrozen() -> Bool { return this.state.lockoutHours > 0.0; }

  // amount <= 0 saca o saldo inteiro.
  public func BankWithdraw(amount: Int32) -> String {
    if this.IsBankFrozen() { return NWL.T("Banco congelado pela Netwatch.", "Bank frozen by Netwatch."); }
    let value = amount <= 0 ? this.state.eddies : Min(amount, this.state.eddies);
    if value <= 0 { return NWL.T("Banco NetWatch sem saldo.", "NetWatch Bank has no funds."); }
    let gi = this.GetGameInstance();
    let player = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject();
    if !IsDefined(player) { return NWL.T("Jogador indisponível.", "Player unavailable."); }
    if !GameInstance.GetTransactionSystem(gi).GiveItem(player, MarketSystem.Money(), value) {
      return NWL.T("Saque recusado.", "Withdrawal refused.");
    }
    this.state.eddies -= value;
    this.state.AddLog(NWL.T(s"V sacou €$ \(value) do Banco NetWatch.", s"V withdrew €$ \(value) from the NetWatch Bank."));
    this.WriteSave();
    return NWL.T(s"Sacado: €$ \(value).", s"Withdrawn: €$ \(value).");
  }

  // amount <= 0 deposita todo o dinheiro do V.
  public func BankDeposit(amount: Int32) -> String {
    if this.IsBankFrozen() { return NWL.T("Banco congelado pela Netwatch.", "Bank frozen by Netwatch."); }
    let have = this.GetPlayerMoney();
    let value = amount <= 0 ? have : Min(amount, have);
    if value <= 0 { return NWL.T("V não tem eddies para depositar.", "V has no eddies to deposit."); }
    let gi = this.GetGameInstance();
    let player = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject();
    if !IsDefined(player) { return NWL.T("Jogador indisponível.", "Player unavailable."); }
    if !GameInstance.GetTransactionSystem(gi).RemoveItem(player, MarketSystem.Money(), value) {
      return NWL.T("Depósito recusado.", "Deposit refused.");
    }
    this.state.eddies += value;
    this.state.AddLog(NWL.T(s"V depositou €$ \(value) no Banco NetWatch.", s"V deposited €$ \(value) in the NetWatch Bank."));
    this.WriteSave();
    return NWL.T(s"Depositado: €$ \(value).", s"Deposited: €$ \(value).");
  }

  // Expulso de uma zona Blackwall: 35% da vida real do V, sem deixar abaixo de 5%.
  // StatPoolsSystem.RequestChangingStatPoolValue com perc = true (conferido no código-fonte).
  private func ApplyBlackwallPenalty() -> Void {
    let gi = this.GetGameInstance();
    let player = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject();
    if !IsDefined(player) {
      return;
    }
    let id = Cast<StatsObjectID>(player.GetEntityID());
    let pools = GameInstance.GetStatPoolsSystem(gi);
    let current = pools.GetStatPoolValue(id, gamedataStatPoolType.Health, true);
    let loss = MinF(35.0, current - 5.0);
    if loss > 0.0 {
      pools.RequestChangingStatPoolValue(id, gamedataStatPoolType.Health, -loss, player, true, true);
    }
    this.ShowScreenMessage(NWL.T("A BLACKWALL REVIDOU — DANO NEURAL", "THE BLACKWALL STRUCK BACK — NEURAL DAMAGE"));
  }

  private func ApplyPartialControl(i: Int32, gained: Int32) -> Void {
    let place = NWText.Upper(this.state.defs[i].Name());
    if this.state.owner[i] == NWFaction.V() {
      this.state.control[i] = Min(100, this.state.control[i] + gained);
      this.state.AddLog(NWL.T(s"V reforçou o controle de \(place): \(this.state.control[i])%.", s"V strengthened control of \(place): \(this.state.control[i])%."));
      return;
    }
    let remaining = this.state.control[i] - gained;
    if remaining < 0 {
      this.state.owner[i] = NWFaction.V();
      this.state.control[i] = Max(10, -remaining);
      this.state.AddLog(NWL.T(s"\(place) agora está em disputa sob o V: \(this.state.control[i])%.", s"\(place) is now contested under V: \(this.state.control[i])%."));
    } else {
      this.state.control[i] = Max(1, remaining);
      this.state.AddLog(NWL.T(s"V enfraqueceu \(place): \(this.state.control[i])% para \(NWFaction.Name(this.state.owner[i])).", s"V weakened \(place): \(this.state.control[i])% for \(NWFaction.Name(this.state.owner[i]))."));
    }
  }

  private func ClaimBonus(i: Int32) -> Void {
    if this.state.bonusClaimed[i] { return; }
    this.state.bonusClaimed[i] = true;
    let def = this.state.defs[i];
    switch def.bonusType {
      case 1:
        this.state.ramMax += def.bonusValue;
        this.state.AddLog(NWL.T(s"Bônus: +\(def.bonusValue) RAM extra a cada jack-in.", s"Bonus: +\(def.bonusValue) extra RAM per jack-in."));
        break;
      case 2:
        this.state.daemonSlots += def.bonusValue;
        this.state.AddLog(NWL.T(s"Bônus: +\(def.bonusValue) slot de daemon.", s"Bonus: +\(def.bonusValue) daemon slot."));
        break;
      case 3:
        this.state.traceReductionPct = Min(60, this.state.traceReductionPct + def.bonusValue);
        this.state.AddLog(NWL.T(s"Bônus: −\(def.bonusValue)% no ganho de rastreio.", s"Bonus: −\(def.bonusValue)% trace gain."));
        break;
      case 4:
        this.state.interfaceBonus += def.bonusValue;
        this.state.AddLog(NWL.T(s"Bônus: +\(def.bonusValue) Interface.", s"Bonus: +\(def.bonusValue) Interface."));
        break;
      case 5:
        this.state.AddLog(NWL.T(s"Intel obtida: \(def.RewardText()).", s"Intel acquired: \(def.RewardText())."));
        break;
      default:
        break;
    }
  }

  // Leitura da sessão para o painel / tela do minigame.
  public func GetBreachNodeName() -> String { return IsDefined(this.breach) ? this.breach.def.Name() : ""; }
  public func GetBreachResult() -> Int32 { return IsDefined(this.breach) ? this.breach.result : -1; }
  public func GetBreachFloorCount() -> Int32 { return IsDefined(this.breach) ? ArraySize(this.breach.floors) : 0; }
  public func GetBreachCurrentFloor() -> Int32 { return IsDefined(this.breach) ? this.breach.current : 0; }
  public func GetBreachHP() -> Int32 { return IsDefined(this.breach) ? this.breach.hp : 0; }
  public func GetBreachHPMax() -> Int32 { return IsDefined(this.breach) ? this.breach.hpMax : 0; }
  public func GetBreachActionsLeft() -> Int32 { return IsDefined(this.breach) ? this.breach.actionsLeft : 0; }
  public func GetBreachTurn() -> Int32 { return IsDefined(this.breach) ? this.breach.turn : 0; }
  public func GetBreachTraceGained() -> Int32 { return IsDefined(this.breach) ? this.breach.traceGained : 0; }
  public func IsBreachCloaked() -> Bool { return IsDefined(this.breach) && this.breach.cloaked; }
  public func GetBreachStatusText() -> String { return IsDefined(this.breach) ? this.breach.StatusText() : ""; }
  public func IsBreachDaemonDerezzed(id: Int32) -> Bool { return IsDefined(this.breach) && ArrayContains(this.breach.derezzed, id); }
  public func IsBreachFloorLobby(k: Int32) -> Bool { let f = this.BreachFloor(k); return IsDefined(f) && f.lobby; }

  public func GetBreachFloorLabel(k: Int32) -> String {
    if !IsDefined(this.breach) || k < 0 || k >= ArraySize(this.breach.floors) { return ""; }
    return this.breach.floors[k].Label();
  }

  public func GetBreachActionsPerTurn() -> Int32 { return IsDefined(this.breach) ? this.breach.actionsPerTurn : 0; }
  public func IsBreachBlackwall() -> Bool { return IsDefined(this.breach) && this.breach.isBlackwall; }
  public func CanBreachAct(a: Int32) -> Bool { return this.IsBreachActive() && this.breach.CanAct(a); }
  public func GetBreachActionName(a: Int32) -> String { return NWBreachAction.Name(a); }

  // Detalhes de um andar (k). Tipos: 0 senha, 1 arquivo, 2 nó de controle, 3 Black ICE.
  private func BreachFloor(k: Int32) -> ref<NWFloor> {
    if !IsDefined(this.breach) || k < 0 || k >= ArraySize(this.breach.floors) { return null; }
    return this.breach.floors[k];
  }
  public func IsBreachFloorRevealed(k: Int32) -> Bool { let f = this.BreachFloor(k); return IsDefined(f) && f.revealed; }
  public func IsBreachFloorCleared(k: Int32) -> Bool { let f = this.BreachFloor(k); return IsDefined(f) && f.cleared; }
  public func GetBreachFloorKind(k: Int32) -> Int32 { let f = this.BreachFloor(k); return IsDefined(f) ? f.kind : -1; }
  public func GetBreachFloorKindName(k: Int32) -> String { let f = this.BreachFloor(k); return IsDefined(f) ? NWFloorKind.Name(f.kind) : ""; }
  public func GetBreachFloorDV(k: Int32) -> Int32 { let f = this.BreachFloor(k); return IsDefined(f) ? f.dv : 0; }
  public func GetBreachFloorIce(k: Int32) -> Int32 { let f = this.BreachFloor(k); return IsDefined(f) ? f.iceId : -1; }
  public func GetBreachFloorRez(k: Int32) -> Int32 { let f = this.BreachFloor(k); return IsDefined(f) ? f.iceRez : 0; }
  public func GetBreachFloorRezMax(k: Int32) -> Int32 { let f = this.BreachFloor(k); return IsDefined(f) ? f.iceRezMax : 0; }
  public func BreachFloorHasAlt(k: Int32) -> Bool { let f = this.BreachFloor(k); return IsDefined(f) && IsDefined(f.alt); }
  public func GetBreachFloorAltLabel(k: Int32) -> String { let f = this.BreachFloor(k); return IsDefined(f) && IsDefined(f.alt) ? f.alt.Label() : ""; }

  // Arquitetura da sessão.
  public func GetBreachStyleName() -> String { return IsDefined(this.breach) ? NWArchStyle.Name(this.breach.style) : ""; }
  public func GetBreachStyleDescription() -> String { return IsDefined(this.breach) ? NWArchStyle.Description(this.breach.style) : ""; }
  public func GetBreachModCount() -> Int32 { return IsDefined(this.breach) ? ArraySize(this.breach.mods) : 0; }
  public func GetBreachModName(k: Int32) -> String { return IsDefined(this.breach) && k >= 0 && k < ArraySize(this.breach.mods) ? NWArchMod.Name(this.breach.mods[k]) : ""; }
  public func GetBreachModDescription(k: Int32) -> String { return IsDefined(this.breach) && k >= 0 && k < ArraySize(this.breach.mods) ? NWArchMod.Description(this.breach.mods[k]) : ""; }
  public func GetBreachFloorEddies(k: Int32) -> Int32 { let f = this.BreachFloor(k); return IsDefined(f) ? f.fileEddies : 0; }

  // Última rolagem do jogador na sessão.
  public func GetBreachRollSerial() -> Int32 { return IsDefined(this.breach) ? this.breach.rollSerial : 0; }
  public func GetBreachRollLabel() -> String { return IsDefined(this.breach) ? this.breach.lastRollLabel : ""; }
  public func GetBreachRollDie() -> Int32 { return IsDefined(this.breach) ? this.breach.lastRollDie : 0; }
  public func GetBreachRollBonus() -> Int32 { return IsDefined(this.breach) ? this.breach.lastRollBonus : 0; }
  public func GetBreachRollTotal() -> Int32 { return IsDefined(this.breach) ? this.breach.lastRollTotal : 0; }
  public func GetBreachRollDV() -> Int32 { return IsDefined(this.breach) ? this.breach.lastRollDV : 0; }
  public func IsBreachRollOk() -> Bool { return IsDefined(this.breach) && this.breach.lastRollOk; }

  public func GetBreachLogCount() -> Int32 { return IsDefined(this.breach) ? ArraySize(this.breach.log) : 0; }

  // 0 = linha mais recente.
  public func GetBreachLogLine(k: Int32) -> String {
    if !IsDefined(this.breach) { return ""; }
    let n = ArraySize(this.breach.log);
    if k < 0 || k >= n { return ""; }
    return this.breach.log[n - 1 - k];
  }

  // ---------------------------------------------------------------- ponto de acesso

  // Chamado pelo gancho em ComputerControllerPS.GetActions sempre que um computador monta
  // suas opções de interação (o jogador está olhando para ele).
  public func NoteComputerSeen(hash: Int32, path: String) -> Void {
    if this.hasLastComputer && this.lastComputerHash == hash {
      return;
    }
    this.lastComputerHash = hash;
    this.lastComputerPath = path;
    this.hasLastComputer = true;
    let tag = this.IsAccessPoint(hash, path) ? " [ponto de acesso]" : "";
    NWLog(s"Computador visto: \(path) hash \(hash)\(tag)");
  }

  // Ponto de acesso = computador de apartamento do V (pelo caminho da entidade ou pelo distrito)
  // ou um PC registrado à mão.
  public func IsAccessPoint(hash: Int32, path: String) -> Bool {
    return this.accessEverywhere
      || ArrayContains(this.saveAccessPoints, hash)
      || NetWarSystem.IsApartmentComputerPath(path)
      || this.IsInPlayerApartment();
  }

  // Os apartamentos compráveis vêm em prefabs "loc_dlc6_apart_<distrito>_..." (visto no jogo:
  // Corpo Plaza = loc_dlc6_apart_cct_dtn_.../computer_1_prefab). O distrito do PreventionSystem
  // nesses lugares é só o bairro ("CorpoPlaza"), por isso o caminho é o critério principal.
  public static func IsApartmentComputerPath(path: String) -> Bool {
    let lower = StrLower(path);
    return StrContains(lower, "_apart_") || StrContains(lower, "v_apartment");
  }

  // Distrito atual do jogador, pelo PreventionSystem (devolve o nome interno do registro, ex.: "Glen_Apartment").
  public func GetCurrentDistrictName() -> String {
    let ps = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"PreventionSystem") as PreventionSystem;
    if !IsDefined(ps) {
      return "";
    }
    let district = ps.GetCurrentDistrict();
    if !IsDefined(district) {
      return "";
    }
    let record = district.GetDistrictRecord();
    if !IsDefined(record) {
      return "";
    }
    return record.EnumName();
  }

  // Subdistritos dos apartamentos que o V possui ou pode comprar (gamedataDistrict).
  public static func IsPlayerApartmentDistrict(name: String) -> Bool {
    return Equals(name, "LittleChina_VApartment")
      || Equals(name, "Northside_Apartment")
      || Equals(name, "JapanTown_Apartment")
      || Equals(name, "Glen_Apartment")
      || Equals(name, "CorpoPlaza_Apartment");
  }

  public func IsInPlayerApartment() -> Bool {
    return NetWarSystem.IsPlayerApartmentDistrict(this.GetCurrentDistrictName());
  }

  public func HasLastComputer() -> Bool { return this.hasLastComputer; }
  public func GetLastComputerHash() -> Int32 { return this.lastComputerHash; }
  public func GetLastComputerPath() -> String { return this.lastComputerPath; }
  public func IsLastComputerAccessPoint() -> Bool { return this.hasLastComputer && ArrayContains(this.saveAccessPoints, this.lastComputerHash); }
  public func IsLastComputerApartment() -> Bool { return this.hasLastComputer && NetWarSystem.IsApartmentComputerPath(this.lastComputerPath); }
  public func GetAccessPointCount() -> Int32 { return ArraySize(this.saveAccessPoints); }
  public func GetAccessEverywhere() -> Bool { return this.accessEverywhere; }
  public func SetAccessEverywhere(value: Bool) -> Void { this.accessEverywhere = value; }
  public func GetConnectCount() -> Int32 { return this.connectCount; }
  public func GetUiDebug() -> String { return this.uiDebug; }

  public func SetUiDebug(text: String) -> Void { this.uiDebug = text; NWLog(text); }

  public func RegisterLastComputer() -> String {
    if !this.hasLastComputer { return "Olhe para um computador primeiro."; }
    if ArrayContains(this.saveAccessPoints, this.lastComputerHash) { return "Este computador já é um ponto de acesso."; }
    ArrayPush(this.saveAccessPoints, this.lastComputerHash);
    NWLog(s"Ponto de acesso registrado: \(this.lastComputerPath) hash \(this.lastComputerHash)");
    return "Ponto de acesso registrado. Olhe de novo para o computador.";
  }

  public func UnregisterLastComputer() -> String {
    if !this.hasLastComputer { return "Olhe para um computador primeiro."; }
    if !ArrayContains(this.saveAccessPoints, this.lastComputerHash) { return "Este computador não é um ponto de acesso."; }
    ArrayRemove(this.saveAccessPoints, this.lastComputerHash);
    return "Ponto de acesso removido.";
  }

  // Chamado quando o jogador escolhe "Conectar à NET". Na fase 4 isto abre a tela do mapa.
  // Simula as horas de jogo passadas desde a última atualização (no máximo 7 dias).
  // A rede só avança quando alguém olha para ela: ao conectar no PC ou pelo painel de debug.
  public func CatchUpGameTime() -> Void {
    let now = GameInstance.GetTimeSystem(this.GetGameInstance()).GetGameTimeStamp();
    if this.saveGameStamp <= 0.0 || now < this.saveGameStamp {
      this.saveGameStamp = now;
      return;
    }
    let hours = MinF((now - this.saveGameStamp) / 3600.0, 168.0);
    this.saveGameStamp = now;
    if hours <= 0.0 {
      return;
    }
    let before = this.state.simHours;
    NWTerritorySim.Advance(this.state, hours, this.tickIntervalHours);
    let advanced = Cast<Int32>(this.state.simHours - before);
    if advanced > 0 {
      this.state.AddLog(NWL.T(s"A rede avançou \(advanced)h desde a última conexão.", s"The net moved \(advanced)h since the last connection."));
    }
    this.WriteSave();
  }

  // Devolve true se a tela do mapa deve abrir.
  public func ConnectFromComputer() -> Bool {
    this.CatchUpGameTime();
    if this.state.lockoutHours > 0.0 {
      this.ShowScreenMessage(NWL.T(s"NET::ACESSO — bloqueado pela Netwatch por \(Cast<Int32>(this.state.lockoutHours))h", s"NET::ACCESS — locked by Netwatch for \(Cast<Int32>(this.state.lockoutHours))h"));
      return false;
    }
    this.connectCount += 1;
    this.PlayUISound(n"ui_menu_open");
    this.state.AddLog(NWL.T("V conectou-se à NET pelo PC de casa.", "V jacked into the NET from the home PC."));
    this.WriteSave();
    NWLog("Conexão à NET pelo computador.");
    NWLog("Idioma de texto do jogo: " + NWL.LanguageCode() + (NWL.IsEnglish() ? " (mod em inglês)" : " (mod em português)"));
    return true;
  }

  // Sons de interface do próprio jogo pelo tocador global (AudioSystem.Play, como os scripts do
  // jogo fazem com os eventos de hacking). Nomes conferidos em base\sound\event\eventsmetadata.json;
  // os usados estão em NWSound (UI/Theme.reds).
  private let hackMusicOn: Bool;

  public func PlayUISound(eventName: CName) -> Void {
    GameInstance.GetAudioSystem(this.GetGameInstance()).Play(eventName);
  }

  // Trilha do Breach Protocol durante a invasão: clima de hacking + loop de fundo.
  public func StartHackMusic() -> Void {
    if this.hackMusicOn {
      return;
    }
    this.hackMusicOn = true;
    let audio = GameInstance.GetAudioSystem(this.GetGameInstance());
    audio.Play(n"global_menu_hacking_open");
    audio.Play(n"ui_hacking_open");
    audio.Play(n"ui_hacking_loop_start");
  }

  public func StopHackMusic() -> Void {
    if !this.hackMusicOn {
      return;
    }
    this.hackMusicOn = false;
    let audio = GameInstance.GetAudioSystem(this.GetGameInstance());
    audio.Play(n"ui_hacking_loop_stop");
    audio.Play(n"global_menu_hacking_close");
  }

  // Aviso no centro da tela, como os avisos de apartamento/veículo do jogo
  // (UI_Notifications.WarningMessage + SimpleScreenMessage).
  public func ShowScreenMessage(text: String) -> Void {
    let msg: SimpleScreenMessage;
    msg.isShown = true;
    msg.duration = 4.0;
    msg.message = text;
    msg.type = SimpleMessageType.Neutral;
    let defs = GetAllBlackboardDefs();
    GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(defs.UI_Notifications).SetVariant(defs.UI_Notifications.WarningMessage, ToVariant(msg), true);
  }

  // ---------------------------------------------------------------- debug

  public func DebugAddEddies(amount: Int32) -> Void { this.state.eddies += amount; this.WriteSave(); }
  public func DebugAddTrace(amount: Int32) -> Void { this.state.trace = Clamp(this.state.trace + amount, 0, 100); this.WriteSave(); }
  public func DebugRunTick() -> Void { NWTerritorySim.RunTick(this.state, this.tickIntervalHours); this.WriteSave(); }
  public func DebugClearLockout() -> Void { this.state.lockoutHours = 0.0; this.WriteSave(); }
}

// Toda saída de log do mod passa por aqui. FTLog é nativo do jogo; o CET grava essa saída
// em bin/x64/plugins/cyber_engine_tweaks/gamelog.log. (LogChannel só existe com o CET.)
public func NWLog(text: String) -> Void {
  FTLog("[NetWar] " + text);
}
