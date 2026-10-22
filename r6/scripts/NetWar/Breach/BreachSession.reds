// NET War — uma invasão por turnos numa torre de andares.
// A sessão não mexe no estado do mundo: ao terminar, o NetWarSystem lê o resultado e aplica.
module NetWar.Breach

import NetWar.Data.*

public abstract class NWBreachAction {
  public static func Scan() -> Int32 { return 0; }
  public static func Descend() -> Int32 { return 1; }
  public static func Backdoor() -> Int32 { return 2; }
  public static func Control() -> Int32 { return 3; }
  public static func Zap() -> Int32 { return 4; }
  public static func Cloak() -> Int32 { return 5; }
  public static func Disconnect() -> Int32 { return 6; }
  public static func EndTurn() -> Int32 { return 7; }
  public static func DescendRight() -> Int32 { return 8; }
  public static func EyeDee() -> Int32 { return 9; }
  public static func Slide() -> Int32 { return 10; }

  public static func Name(a: Int32) -> String {
    switch a {
      case 0: return NWL.T("Escanear", "Scan");
      case 1: return NWL.T("Descer", "Descend");
      case 2: return "Backdoor";
      case 3: return NWL.T("Controlar", "Control");
      case 4: return "Zap";
      case 5: return NWL.T("Camuflar", "Cloak");
      case 6: return NWL.T("Desconectar", "Disconnect");
      case 7: return NWL.T("Encerrar turno", "End turn");
      case 8: return NWL.T("Descer pela direita", "Descend right");
      case 9: return "Eye-Dee";
      case 10: return "Slide";
      default: return "?";
    }
  }
}

public abstract class NWBreachResult {
  public static func Running() -> Int32 { return 0; }
  public static func Captured() -> Int32 { return 1; }
  public static func Disconnected() -> Int32 { return 2; }
  public static func Kicked() -> Int32 { return 3; }
}

public class NWBreachSession {
  public let nodeIndex: Int32;
  public let def: ref<NWNodeDef>;
  public let floors: array<ref<NWFloor>>;
  public let current: Int32;
  public let deepest: Int32;
  public let hp: Int32;
  public let hpMax: Int32;
  public let netInterface: Int32;
  public let actionsPerTurn: Int32;
  public let actionsLeft: Int32;
  public let turn: Int32;
  public let cloaked: Bool;
  public let isBlackwall: Bool;
  public let result: Int32;
  public let traceGained: Int32;
  public let eddiesGained: Int32;
  public let log: array<String>;

  // Arquitetura: estilo da facção dona e modificadores sorteados.
  public let style: Int32;
  public let mods: array<Int32>;
  public let traceMultiplier: Int32;
  public let iceSpeedBonus: Int32;
  public let iceAttackBonus: Int32;

  // RAM do deck (vem do V; volta ao mapa ao fim da sessão) e daemons equipados.
  public let ram: Int32;
  public let equippedIds: array<Int32>;
  public let equippedRarity: array<Int32>;
  // Efeitos ativos dos daemons.
  public let zapBonus: Int32;
  public let mirror: Bool;
  public let wormTurns: Int32;
  public let ghostFloor: Int32;
  public let overloadTurn: Int32;
  public let anchor: Bool;
  public let fragment: Bool;

  // Efeitos do Black ICE no V.
  public let skipActions: Int32;
  public let interfacePenalty: Int32;
  public let burnTurns: Int32;
  public let lockedTurns: Int32;
  public let derezzed: array<Int32>;

  // Minigame de defesa: com ele ligado, o ataque de fim de turno pausa a sessão até o resultado.
  public let useDefenseGame: Bool;
  public let pendingDefense: Bool;

  // Daemons coletados nesta sessão (perdidos se o V for expulso).
  public let lootIds: array<Int32>;
  public let lootRarity: array<Int32>;

  // Última rolagem do jogador, para a tela animar o d10. rollSerial muda a cada rolagem.
  public let rollSerial: Int32;
  public let lastRollLabel: String;
  public let lastRollDie: Int32;
  public let lastRollBonus: Int32;
  public let lastRollTotal: Int32;
  public let lastRollDV: Int32;
  public let lastRollOk: Bool;

  public func Start(def: ref<NWNodeDef>, nodeIndex: Int32, netInterface: Int32, preScanned: Bool, faction: Int32) -> Void {
    this.def = def;
    this.nodeIndex = nodeIndex;
    this.netInterface = netInterface;
    let arch = NWArchitectureGen.Generate(def, faction);
    this.floors = arch.floors;
    this.style = arch.style;
    this.mods = arch.mods;
    this.traceMultiplier = NWArchStyle.TraceMultiplier(faction);
    this.iceSpeedBonus = NWArchStyle.IceSpeedBonus(faction);
    this.iceAttackBonus = this.HasMod(NWArchMod.ColdChamber()) ? 1 : 0;
    this.ghostFloor = -1;
    this.overloadTurn = -1;
    this.isBlackwall = def.startOwner == NWFaction.Blackwall();
    this.hpMax = 15 + netInterface * 2;
    this.hp = this.hpMax;
    this.actionsPerTurn = NWBreachSession.ActionsFor(netInterface);
    this.actionsLeft = this.actionsPerTurn;
    this.turn = 1;
    this.current = 0;
    this.deepest = 0;
    this.result = NWBreachResult.Running();
    this.Log(NWL.T(s"JACK-IN em \(NWText.Upper(def.Name())) — \(ArraySize(this.floors)) andares, Interface \(netInterface).", s"JACK-IN at \(NWText.Upper(def.Name())) — \(ArraySize(this.floors)) floors, Interface \(netInterface)."));
    this.Log(NWL.T(s"Arquitetura: \(NWArchStyle.Name(this.style)). \(this.ModsText())", s"Architecture: \(NWArchStyle.Name(this.style)). \(this.ModsText())"));
    this.Reveal(0, preScanned ? 2 : 0);
    this.Arrive();
  }

  // Ações de NET por turno, tabela do RED: Interface 1–3 = 2, 4–6 = 3, 7–9 = 4, 10+ = 5.
  public static func ActionsFor(netInterface: Int32) -> Int32 {
    if netInterface <= 3 { return 2; }
    if netInterface <= 6 { return 3; }
    if netInterface <= 9 { return 4; }
    return 5;
  }

  public func HasMod(m: Int32) -> Bool {
    return ArrayContains(this.mods, m);
  }

  public func ModsText() -> String {
    if ArraySize(this.mods) == 0 {
      return NWL.T("Sem modificadores.", "No modifiers.");
    }
    let text = "";
    for m in this.mods {
      text = text + (StrLen(text) > 0 ? " · " : "") + NWArchMod.Name(m);
    }
    return text;
  }

  public func HasForkAhead() -> Bool {
    let next = this.current + 1;
    return next < ArraySize(this.floors) && IsDefined(this.floors[next].alt);
  }

  public func IsRunning() -> Bool {
    return this.result == NWBreachResult.Running();
  }

  public func Floor() -> ref<NWFloor> {
    return this.floors[this.current];
  }

  public func Log(text: String) -> Void {
    ArrayPush(this.log, s"T\(this.turn) · \(text)");
    while ArraySize(this.log) > 80 {
      ArrayErase(this.log, 0);
    }
  }

  // Executa uma ação. Devolve false se a ação não foi possível (não gasta ação de NET).
  public func Act(a: Int32) -> Bool {
    if !this.IsRunning() || this.pendingDefense {
      return false;
    }
    let done = false;
    switch a {
      case 0: done = this.DoScan(); break;
      case 1: done = this.DoDescend(false); break;
      case 8: done = this.DoDescend(true); break;
      case 2: done = this.DoBackdoor(); break;
      case 3: done = this.DoControl(); break;
      case 4: done = this.DoZap(); break;
      case 5: done = this.DoCloak(); break;
      case 9: done = this.DoEyeDee(); break;
      case 10: done = this.DoSlide(); break;
      case 6:
        if this.lockedTurns > 0 {
          this.Log(NWL.T("Preso pelo ICE: não dá para desconectar neste turno.", "Held by ICE: can't disconnect this turn."));
          return false;
        }
        // Saída insegura: Black ICE ativo no andar ataca uma última vez.
        let here = this.Floor();
        if here.kind == NWFloorKind.Ice() && !here.cleared {
          this.Log(NWL.T(s"Saída insegura: \(NWIce.Name(here.iceId)) ataca antes do jack-out.", s"Unsafe exit: \(NWIce.Name(here.iceId)) attacks before the jack-out."));
          this.IceAttack(here);
          if !this.IsRunning() {
            return true;
          }
        }
        this.Log(NWL.T("Desconectado por vontade própria.", "Disconnected voluntarily."));
        this.result = NWBreachResult.Disconnected();
        return true;
      case 7:
        this.EndTurn();
        return true;
      default:
        return false;
    }
    if done && this.IsRunning() {
      this.actionsLeft -= 1;
      if this.actionsLeft <= 0 {
        this.EndTurn();
      }
    }
    return done;
  }

  // Se a ação pode ser usada agora (mesmas condições de Act, sem registrar nada).
  public func CanAct(a: Int32) -> Bool {
    if !this.IsRunning() || this.pendingDefense {
      return false;
    }
    let f = this.Floor();
    let last = this.current >= ArraySize(this.floors) - 1;
    switch a {
      case 0: return true;
      case 1: return this.lockedTurns == 0 && this.CanDescend(last, f);
      case 8: return this.lockedTurns == 0 && this.CanDescend(last, f) && this.HasForkAhead();
      case 9: return f.kind == NWFloorKind.File() && !f.cleared;
      case 10: return this.lockedTurns == 0 && !last && f.kind == NWFloorKind.Ice() && !f.cleared && this.NextFloorVisible();
      case 2: return f.kind == NWFloorKind.Password() && !f.cleared;
      case 3: return f.kind == NWFloorKind.ControlNode();
      case 4: return f.kind == NWFloorKind.Ice() && !f.cleared;
      case 5: return !this.cloaked;
      case 6: return this.lockedTurns == 0;
      case 7: return true;
      default: return false;
    }
  }

  private func NextFloorVisible() -> Bool {
    return !this.HasMod(NWArchMod.DenseFog()) || this.floors[this.current + 1].revealed;
  }

  private func CanDescend(last: Bool, f: ref<NWFloor>) -> Bool {
    if last || (!f.cleared && (f.kind == NWFloorKind.Password() || f.kind == NWFloorKind.Ice())) {
      return false;
    }
    // Névoa densa: só desce para andares já escaneados.
    return !this.HasMod(NWArchMod.DenseFog()) || this.floors[this.current + 1].revealed;
  }

  private func Reveal(start: Int32, extra: Int32) -> Void {
    let last = Min(ArraySize(this.floors) - 1, start + extra);
    let k = start;
    while k <= last {
      this.floors[k].revealed = true;
      if IsDefined(this.floors[k].alt) {
        this.floors[k].alt.revealed = true;
      }
      k += 1;
    }
  }

  private func Arrive() -> Void {
    let f = this.Floor();
    f.revealed = true;
    this.deepest = Max(this.deepest, this.current);
    this.cloaked = false;
    let n = this.current + 1;
    if f.kind == NWFloorKind.File() && !f.cleared {
      this.Log(NWL.T(s"Andar \(n): arquivo de €$ \(f.fileEddies). Eye-Dee (DV \(f.dv)) para baixar, ou siga em frente.", s"Floor \(n): €$ \(f.fileEddies) file. Eye-Dee (DV \(f.dv)) to download, or move on."));
      return;
    }
    if f.kind == NWFloorKind.DaemonCache() && !f.cleared {
      f.cleared = true;
      ArrayPush(this.lootIds, f.daemonId);
      ArrayPush(this.lootRarity, f.daemonRarity);
      this.Log(NWL.T(s"Andar \(n): cache de daemon — \(NWDaemon.Name(f.daemonId)) (\(NWDaemon.RarityName(f.daemonRarity))).", s"Floor \(n): daemon cache — \(NWDaemon.Name(f.daemonId)) (\(NWDaemon.RarityName(f.daemonRarity)))."));
      return;
    }
    if f.kind == NWFloorKind.Ice() {
      this.Log(NWL.T(s"Andar \(n): \(NWIce.Name(f.iceId)) bloqueia o caminho!", s"Floor \(n): \(NWIce.Name(f.iceId)) blocks the way!"));
      return;
    }
    this.Log(NWL.T(s"Andar \(n): \(f.Label()).", s"Floor \(n): \(f.Label())."));
  }

  // Ponto único dos testes do V (d10 + Interface contra um DV). O futuro minigame de habilidade
  // entra aqui: troca o d10 pelo desempenho do jogador, sem mexer nas regras em volta.
  private func Roll(label: String, dv: Int32) -> Bool {
    let d = NWDice.D10();
    let total = d + this.netInterface;
    let ok = total >= dv;
    let verdict = ok ? NWL.T("SUCESSO", "SUCCESS") : NWL.T("FALHA", "FAIL");
    this.rollSerial += 1;
    this.lastRollLabel = label;
    this.lastRollDie = d;
    this.lastRollBonus = this.netInterface;
    this.lastRollTotal = total;
    this.lastRollDV = dv;
    this.lastRollOk = ok;
    this.Log(s"\(label): d10(\(d)) + \(this.netInterface) = \(total) vs DV \(dv): \(verdict)");
    return ok;
  }

  private func Fail(trace: Int32) -> Void {
    if this.IsGhosted() {
      return;
    }
    let value = trace * this.traceMultiplier;
    this.traceGained += this.cloaked ? Max(1, value / 2) : value;
  }

  // Resultado do Escanear vindo do sonar: sempre revela a base (o andar atual + 3, como o d10);
  // os pontos revelam andares extras em proporção, e atingir a meta revela a torre inteira.
  public func ResolveScan(score: Int32, goal: Int32) -> Void {
    if !this.IsRunning() {
      return;
    }
    this.Reveal(this.current, 3);
    let beyond = (ArraySize(this.floors) - 1) - (this.current + 3);
    let extra = 0;
    if beyond > 0 && score > 0 {
      extra = score >= goal ? beyond : Min(beyond, (beyond * score + goal / 2) / Max(1, goal));
    }
    if extra > 0 {
      this.Reveal(this.current, 3 + extra);
    }
    if beyond > 0 && extra >= beyond {
      this.Log(NWL.T(s"Escanear (sonar): \(score)/\(goal) pontos: a torre inteira foi revelada.", s"Scan (sonar): \(score)/\(goal) points: the whole tower was revealed."));
    } else {
      this.Log(NWL.T(s"Escanear (sonar): \(score)/\(goal) pontos: base + \(extra) andar(es).", s"Scan (sonar): \(score)/\(goal) points: base + \(extra) floor(s)."));
    }
    this.actionsLeft -= 1;
    if this.actionsLeft <= 0 {
      this.EndTurn();
    }
  }

  private func DoScan() -> Bool {
    this.Reveal(this.current, 3);
    this.Log(NWL.T("Escaneamento revelou os próximos andares.", "Scan revealed the next floors."));
    return true;
  }

  private func DoDescend(right: Bool) -> Bool {
    let f = this.Floor();
    if this.current >= ArraySize(this.floors) - 1 {
      this.Log(NWL.T("Este é o último andar. Use Controlar.", "This is the last floor. Use Control."));
      return false;
    }
    if !f.cleared && (f.kind == NWFloorKind.Password() || f.kind == NWFloorKind.Ice()) {
      this.Log(NWL.T(s"Não dá para descer: \(NWFloorKind.Name(f.kind)) ativo.", s"Can't descend: \(NWFloorKind.Name(f.kind)) active."));
      return false;
    }
    let next = this.current + 1;
    if this.HasMod(NWArchMod.DenseFog()) && !this.floors[next].revealed {
      this.Log(NWL.T("Névoa densa: escaneie antes de descer.", "Dense fog: scan before descending."));
      return false;
    }
    return this.MoveDown(right);
  }

  private func MoveDown(right: Bool) -> Bool {
    let next = this.current + 1;
    // Bifurcação: o caminho escolhido fica; o outro é descartado.
    let alt = this.floors[next].alt;
    if IsDefined(alt) {
      if right {
        this.floors[next] = alt;
        this.Log(NWL.T("Bifurcação: caminho da direita.", "Fork: right path."));
      } else {
        this.Log(NWL.T("Bifurcação: caminho da esquerda.", "Fork: left path."));
      }
      this.floors[next].alt = null;
    } else {
      if right {
        this.Log(NWL.T("Não há bifurcação à frente.", "No fork ahead."));
        return false;
      }
    }
    this.current = next;
    this.Arrive();
    return true;
  }

  // Resultado do Eye-Dee vindo do minigame. Cada erro além dos gratuitos dá rastreio.
  public func ResolveEyeDee(ok: Bool, detail: String, paidErrors: Int32) -> Void {
    let f = this.Floor();
    if !this.IsRunning() || f.kind != NWFloorKind.File() || f.cleared {
      return;
    }
    let k = 0;
    while k < paidErrors {
      this.Fail(1);
      k += 1;
    }
    if ok {
      f.cleared = true;
      this.eddiesGained += f.fileEddies;
      this.Log(NWL.T(s"Eye-Dee (minigame): \(detail): arquivo baixado (+€$ \(f.fileEddies)).", s"Eye-Dee (minigame): \(detail): file downloaded (+€$ \(f.fileEddies))."));
    } else {
      this.Log(NWL.T(s"Eye-Dee (minigame): \(detail): FALHA", s"Eye-Dee (minigame): \(detail): FAIL"));
      this.Fail(2);
    }
    this.actionsLeft -= 1;
    if this.actionsLeft <= 0 {
      this.EndTurn();
    }
  }

  // Eye-Dee (RED): identificar e baixar o arquivo do andar. Falha: rastreio, pode tentar de novo.
  private func DoEyeDee() -> Bool {
    let f = this.Floor();
    if f.kind != NWFloorKind.File() || f.cleared {
      this.Log(NWL.T("Nenhum arquivo para baixar neste andar.", "No file to download on this floor."));
      return false;
    }
    if this.Roll("Eye-Dee", f.dv) {
      f.cleared = true;
      this.eddiesGained += f.fileEddies;
      this.Log(NWL.T(s"Arquivo baixado (+€$ \(f.fileEddies)).", s"File downloaded (+€$ \(f.fileEddies))."));
    } else {
      this.Fail(2);
    }
    return true;
  }

  // Slide (RED): d10 + Interface contra d10 + Percepção do ICE. Sucesso: passa para o andar
  // de baixo sem derrubar o ICE. Falha: o ICE percebe e ataca na hora.
  // Resultado do Slide vindo do minigame: escapou = desce sem derrubar o ICE; senão o ICE ataca.
  public func ResolveSlide(ok: Bool, detail: String) -> Void {
    let f = this.Floor();
    if !this.IsRunning() || f.kind != NWFloorKind.Ice() || f.cleared || this.current >= ArraySize(this.floors) - 1 {
      return;
    }
    if ok {
      this.Log(NWL.T(s"Slide (minigame): \(detail): \(NWIce.Name(f.iceId)) perdeu o rastro do V.", s"Slide (minigame): \(detail): \(NWIce.Name(f.iceId)) lost V's trail."));
      this.MoveDown(false);
    } else {
      this.Log(NWL.T(s"Slide (minigame): \(detail): FALHA", s"Slide (minigame): \(detail): FAIL"));
      this.Fail(2);
      this.IceAttack(f);
    }
    if this.IsRunning() {
      this.actionsLeft -= 1;
      if this.actionsLeft <= 0 {
        this.EndTurn();
      }
    }
  }

  private func DoSlide() -> Bool {
    let f = this.Floor();
    if f.kind != NWFloorKind.Ice() || f.cleared || this.current >= ArraySize(this.floors) - 1 {
      this.Log(NWL.T("Nada para deslizar neste andar.", "Nothing to slide past on this floor."));
      return false;
    }
    let per = NWIce.Perception(f.iceId);
    let dv = NWDice.D10() + per;
    if this.Roll(NWL.T(s"Slide por \(NWIce.Name(f.iceId)) (PER \(per))", s"Slide past \(NWIce.Name(f.iceId)) (PER \(per))"), dv) {
      this.Log(NWL.T(s"Slide: \(NWIce.Name(f.iceId)) perdeu o rastro do V.", s"Slide: \(NWIce.Name(f.iceId)) lost V's trail."));
      this.MoveDown(false);
    } else {
      this.Fail(2);
      this.IceAttack(f);
    }
    return true;
  }

  // Resultado do Backdoor vindo do minigame (substitui o d10 de Roll; mesmas consequências).
  public func ResolveBackdoor(ok: Bool, detail: String) -> Void {
    let f = this.Floor();
    if !this.IsRunning() || f.kind != NWFloorKind.Password() || f.cleared {
      return;
    }
    if ok {
      f.cleared = true;
      this.Log(NWL.T(s"Backdoor (minigame): \(detail): SUCESSO", s"Backdoor (minigame): \(detail): SUCCESS"));
    } else {
      this.Log(NWL.T(s"Backdoor (minigame): \(detail): FALHA", s"Backdoor (minigame): \(detail): FAIL"));
      this.Fail(3);
    }
    this.actionsLeft -= 1;
    if this.actionsLeft <= 0 {
      this.EndTurn();
    }
  }

  private func DoBackdoor() -> Bool {
    let f = this.Floor();
    if f.kind != NWFloorKind.Password() || f.cleared {
      this.Log(NWL.T("Nenhuma senha para quebrar neste andar.", "No password to break on this floor."));
      return false;
    }
    let dv = this.wormTurns > 0 ? f.dv - 2 : f.dv;
    if this.Roll("Backdoor", dv) {
      f.cleared = true;
    } else {
      this.Fail(3);
    }
    return true;
  }

  // Resultado do Controlar vindo do minigame: circuito ligado toma o nó; senão, falha com rastreio.
  public func ResolveControl(ok: Bool, detail: String) -> Void {
    let f = this.Floor();
    if !this.IsRunning() || f.kind != NWFloorKind.ControlNode() {
      return;
    }
    if ok {
      f.cleared = true;
      this.result = NWBreachResult.Captured();
      this.Log(NWL.T(s"Controlar (minigame): \(detail).", s"Control (minigame): \(detail)."));
      this.Log(NWL.T(s"NÓ DE CONTROLE TOMADO. \(NWText.Upper(this.def.Name())) é do V.", s"CONTROL NODE TAKEN. \(NWText.Upper(this.def.Name())) belongs to V."));
      return;
    }
    this.Log(NWL.T(s"Controlar (minigame): \(detail): FALHA", s"Control (minigame): \(detail): FAIL"));
    this.Fail(3);
    this.actionsLeft -= 1;
    if this.actionsLeft <= 0 {
      this.EndTurn();
    }
  }

  private func DoControl() -> Bool {
    let f = this.Floor();
    if f.kind != NWFloorKind.ControlNode() {
      this.Log(NWL.T("O Nó de Controle fica no último andar.", "The Control Node is on the last floor."));
      return false;
    }
    if this.Roll(NWL.T("Controlar", "Control"), f.dv) {
      f.cleared = true;
      this.result = NWBreachResult.Captured();
      this.Log(NWL.T(s"NÓ DE CONTROLE TOMADO. \(NWText.Upper(this.def.Name())) é do V.", s"CONTROL NODE TAKEN. \(NWText.Upper(this.def.Name())) belongs to V."));
    } else {
      this.Fail(3);
    }
    return true;
  }

  // Resultado do Zap vindo do minigame: crítico vale o 6 do d6, acerto vale 3, erro dá rastreio.
  public func ResolveZap(quality: Int32, detail: String) -> Void {
    let f = this.Floor();
    if !this.IsRunning() || f.kind != NWFloorKind.Ice() || f.cleared {
      return;
    }
    if quality > 0 {
      let dmg = (quality == 2 ? 6 : 3) + 2 + this.netInterface / 3 + this.zapBonus;
      f.iceRez = Max(0, f.iceRez - dmg);
      this.Log(NWL.T(s"Zap (minigame): \(detail): \(dmg) de dano (REZ \(f.iceRez)).", s"Zap (minigame): \(detail): \(dmg) damage (REZ \(f.iceRez))."));
      if f.iceRez <= 0 {
        f.cleared = true;
        this.Log(NWL.T(s"\(NWIce.Name(f.iceId)) derezzado.", s"\(NWIce.Name(f.iceId)) derezzed."));
      }
    } else {
      this.Log(NWL.T(s"Zap (minigame): \(detail): FALHA", s"Zap (minigame): \(detail): FAIL"));
      this.Fail(2);
    }
    this.actionsLeft -= 1;
    if this.actionsLeft <= 0 {
      this.EndTurn();
    }
  }

  private func DoZap() -> Bool {
    let f = this.Floor();
    if f.kind != NWFloorKind.Ice() || f.cleared {
      this.Log(NWL.T("Nenhum Black ICE ativo para atacar.", "No active Black ICE to attack."));
      return false;
    }
    if this.Roll(NWL.T(s"Zap em \(NWIce.Name(f.iceId))", s"Zap on \(NWIce.Name(f.iceId))"), NWIce.Defense(f.iceId)) {
      let dmg = NWDice.D6() + 2 + this.netInterface / 3 + this.zapBonus;
      f.iceRez = Max(0, f.iceRez - dmg);
      this.Log(NWL.T(s"Zap causou \(dmg) de dano (REZ \(f.iceRez)).", s"Zap dealt \(dmg) damage (REZ \(f.iceRez))."));
      if f.iceRez <= 0 {
        f.cleared = true;
        this.Log(NWL.T(s"\(NWIce.Name(f.iceId)) derezzado.", s"\(NWIce.Name(f.iceId)) derezzed."));
      }
    } else {
      this.Fail(2);
    }
    return true;
  }

  private func DoCloak() -> Bool {
    if this.cloaked {
      this.Log(NWL.T("Já camuflado neste andar.", "Already cloaked on this floor."));
      return false;
    }
    this.cloaked = true;
    this.Log(NWL.T("Camuflagem ativa: ICE com −3 no ataque, rastreio reduzido.", "Cloak active: ICE −3 to attack, reduced trace."));
    return true;
  }

  public func EndTurn() -> Void {
    if !this.IsRunning() {
      return;
    }
    let f = this.Floor();
    if f.kind == NWFloorKind.Ice() && !f.cleared {
      if this.useDefenseGame && this.mirror {
        this.mirror = false;
        this.Log(NWL.T(s"Espelho anulou o ataque de \(NWIce.Name(f.iceId)).", s"Mirror negated \(NWIce.Name(f.iceId))'s attack."));
      } else {
        if this.useDefenseGame {
          // Pausa: o resto do turno roda em ResolveIceDefense.
          this.pendingDefense = true;
          this.Log(NWL.T(s"\(NWIce.Name(f.iceId)) ataca: defenda-se!", s"\(NWIce.Name(f.iceId)) attacks: defend yourself!"));
          return;
        }
        this.IceAttack(f);
      }
    }
    this.FinishEndTurn();
  }

  // Segunda metade do fim de turno (depois do ataque do ICE).
  private func FinishEndTurn() -> Void {
    if this.IsRunning() {
      this.ApplyTurnModifiers();
    }
    if this.IsRunning() {
      this.turn += 1;
      this.actionsLeft = this.actionsPerTurn;
      if this.skipActions > 0 {
        this.actionsLeft = Max(1, this.actionsPerTurn - this.skipActions);
        this.Log(NWL.T(s"Efeito do ICE: \(this.actionsLeft) ação(ões) neste turno.", s"ICE effect: \(this.actionsLeft) action(s) this turn."));
        this.skipActions = 0;
      }
    }
  }

  private func Damage(dmg: Int32, source: String) -> Void {
    this.hp = Max(0, this.hp - dmg);
    this.Log(s"\(source): -\(dmg) HP (\(this.hp)/\(this.hpMax)).");
    if this.hp <= 0 {
      if this.anchor {
        this.anchor = false;
        this.result = NWBreachResult.Disconnected();
        this.Log(NWL.T("ÂNCORA: desconexão de emergência. Controle parcial e daemons mantidos.", "ANCHOR: emergency disconnect. Partial control and daemons kept."));
        return;
      }
      this.result = NWBreachResult.Kicked();
      this.Log(NWL.T("HP DA SESSÃO ZERADO. O V foi expulso da rede.", "SESSION HP DEPLETED. V was kicked out of the net."));
    }
  }

  // Derrezza um daemon equipado ainda inteiro (fica inutilizável nesta sessão; continua no inventário).
  private func DerezzDaemon(source: String) -> Void {
    let options: array<Int32>;
    for id in this.equippedIds {
      if !ArrayContains(this.derezzed, id) {
        ArrayPush(options, id);
      }
    }
    if ArraySize(options) == 0 {
      return;
    }
    let id = options[RandRange(0, ArraySize(options))];
    ArrayPush(this.derezzed, id);
    switch id {
      case 0: this.zapBonus = 0; break;
      case 1: this.mirror = false; break;
      case 2: this.wormTurns = 0; break;
      case 3: this.ghostFloor = -1; break;
      case 5: this.anchor = false; break;
      default: break;
    }
    this.Log(NWL.T(s"\(source) derrezzou o daemon \(NWDaemon.Name(id)) nesta sessão.", s"\(source) derezzed the \(NWDaemon.Name(id)) daemon for this session."));
  }

  private func LowerInterface(source: String) -> Void {
    if this.interfacePenalty >= 3 {
      return;
    }
    this.interfacePenalty += 1;
    this.netInterface -= 1;
    this.Log(NWL.T(s"\(source): Interface -1 na sessão (\(this.netInterface)).", s"\(source): Interface -1 this session (\(this.netInterface))."));
  }

  private func BurnRam(amount: Int32, source: String) -> Void {
    let lost = Min(amount, this.ram);
    this.ram -= lost;
    if lost > 0 {
      this.Log(NWL.T(s"\(source) queimou \(lost) de RAM.", s"\(source) burned \(lost) RAM."));
    }
  }

  // Efeito especial de cada ICE ao acertar (ver NWIce.EffectText). Devolve dano extra.
  private func ApplyIceEffect(f: ref<NWFloor>) -> Int32 {
    let name = NWIce.Name(f.iceId);
    switch f.iceId {
      case 0:
        this.skipActions = 1;
        return 0;
      case 1:
        this.DerezzDaemon(name);
        return 0;
      case 2:
        return 3;
      case 3:
        if this.current > 0 {
          this.current -= 1;
          this.Log(NWL.T(s"\(name) empurrou o V para o andar \(this.current + 1).", s"\(name) pushed V back to floor \(this.current + 1)."));
          this.Arrive();
        }
        return 0;
      case 4:
        this.LowerInterface(name);
        return 0;
      case 5:
        this.burnTurns = 2;
        return 0;
      case 6:
        return 2;
      case 7:
        this.BurnRam(2, name);
        return 0;
      case 8:
        this.skipActions = 1;
        this.traceGained += 1;
        return 0;
      case 9:
        this.lockedTurns = 2;
        this.Log(NWL.T(s"\(name) prendeu o V: sem descer, deslizar ou desconectar no próximo turno.", s"\(name) holds V: no descending, sliding or disconnecting next turn."));
        return 0;
      case 10:
        this.traceGained += 3;
        this.skipActions = 1;
        return 0;
      case 11:
        this.LowerInterface(name);
        this.DerezzDaemon(name);
        return 0;
      case 12:
        this.DerezzDaemon(name);
        this.BurnRam(2, name);
        return 0;
      case 13:
        this.traceGained += 3;
        this.lockedTurns = 2;
        this.Log(NWL.T(s"\(name) prendeu o V.", s"\(name) holds V."));
        return 0;
      default:
        return 0;
    }
  }

  // Resumo dos efeitos ativos no V, para a tela.
  public func StatusText() -> String {
    let parts = "";
    if this.lockedTurns > 0 { parts = parts + NWL.T("PRESO ", "HELD"); }
    if this.burnTurns > 0 { parts = parts + NWL.T("QUEIMANDO ", "BURNING"); }
    if this.skipActions > 0 { parts = parts + NWL.T("-1 AÇÃO ", "-1 ACTION"); }
    if this.interfacePenalty > 0 { parts = parts + s"INTERFACE -\(this.interfacePenalty) "; }
    return parts;
  }

  private func ApplyTurnModifiers() -> Void {
    if this.lockedTurns > 0 {
      this.lockedTurns -= 1;
    }
    if this.burnTurns > 0 {
      this.burnTurns -= 1;
      this.Damage(2, NWL.T("Queimadura do ICE", "ICE burn"));
      if !this.IsRunning() {
        return;
      }
    }
    if this.wormTurns > 0 {
      this.wormTurns -= 1;
    }
    if this.fragment && !this.IsGhosted() {
      this.traceGained += 2;
    }
    if this.HasMod(NWArchMod.TraceEcho()) && !this.IsGhosted() {
      this.traceGained += 1;
    }
    if this.HasMod(NWArchMod.RotatingPasswords()) && this.turn % 3 == 0 {
      for floor in this.floors {
        if floor.kind == NWFloorKind.Password() && !floor.cleared {
          floor.dv += 1;
        }
      }
      this.Log(NWL.T("Senhas rotativas: DV das senhas +1.", "Rotating passwords: password DV +1."));
    }
    if this.HasMod(NWArchMod.Unstable()) && RandRange(0, 100) < 30 {
      // Reconfigura um andar à frente ainda não liberado (nunca o Nó de Controle).
      let candidates: array<Int32>;
      let k = this.current + 1;
      while k < ArraySize(this.floors) - 1 {
        if !this.floors[k].cleared {
          ArrayPush(candidates, k);
        }
        k += 1;
      }
      if ArraySize(candidates) > 0 {
        let slot = candidates[RandRange(0, ArraySize(candidates))];
        let kind = NWArchitectureGen.RollKind(this.style);
        this.floors[slot] = NWArchitectureGen.MakeFloor(this.def, kind, -1, this.floors[slot].dv, this.HasMod(NWArchMod.ColdChamber()));
        this.Log(NWL.T(s"A Blackwall reconfigurou o andar \(slot + 1).", s"The Blackwall reconfigured floor \(slot + 1)."));
      }
    }
  }

  // Resultado da defesa vinda do minigame: o dano é proporcional aos códigos errados, a
  // Constituição tira um pouco, e o efeito especial do ICE só pega se errou metade ou mais.
  public func ResolveIceDefense(hits: Int32, total: Int32, bodyCut: Int32) -> Void {
    if !this.pendingDefense {
      return;
    }
    this.pendingDefense = false;
    let f = this.Floor();
    if this.IsRunning() && f.kind == NWFloorKind.Ice() && !f.cleared {
      let name = NWIce.Name(f.iceId);
      let misses = Max(0, total - hits);
      if misses == 0 {
        this.Log(NWL.T(s"Defesa (minigame): \(hits)/\(total): esquiva total do \(name).", s"Defense (minigame): \(hits)/\(total): full dodge from \(name)."));
      } else {
        if !this.IsGhosted() {
          this.traceGained += this.cloaked ? 1 : 2;
        }
        let extra = misses * 2 >= total ? this.ApplyIceEffect(f) : 0;
        let full = NWDice.D6() + NWIce.Attack(f.iceId) + this.iceAttackBonus + (this.isBlackwall ? 2 : 0);
        let dmg = Max(1, (full * misses + total / 2) / Max(1, total) + extra - bodyCut);
        this.Log(NWL.T(s"Defesa (minigame): \(hits)/\(total) códigos.", s"Defense (minigame): \(hits)/\(total) codes."));
        this.Damage(dmg, name);
      }
    }
    this.FinishEndTurn();
  }

  private func IceAttack(f: ref<NWFloor>) -> Void {
    let id = f.iceId;
    let name = NWIce.Name(id);
    let cloakCut = this.cloaked && id != 6 ? 3 : 0;
    let attack = NWDice.D10() + NWIce.Attack(id) + this.iceAttackBonus + (NWIce.Speed(id) + this.iceSpeedBonus) / 3 - cloakCut;
    let defense = NWDice.D10() + this.netInterface;
    if attack < defense {
      this.Log(NWL.T(s"\(name) atacou (\(attack) vs \(defense)) e errou.", s"\(name) attacked (\(attack) vs \(defense)) and missed."));
      return;
    }
    if this.mirror {
      this.mirror = false;
      this.Log(NWL.T(s"Espelho anulou o acerto de \(name) (\(attack) vs \(defense)).", s"Mirror negated \(name)'s hit (\(attack) vs \(defense))."));
      return;
    }
    if !this.IsGhosted() {
      this.traceGained += this.cloaked ? 1 : 2;
    }
    this.Log(NWL.T(s"\(name) acertou (\(attack) vs \(defense)).", s"\(name) hit (\(attack) vs \(defense))."));
    let extra = this.ApplyIceEffect(f);
    let dmg = NWDice.D6() + NWIce.Attack(id) + this.iceAttackBonus + (this.isBlackwall ? 2 : 0) + extra;
    this.Damage(dmg, name);
  }

  // ------------------------------------------------------------ daemons

  public func SetupDaemons(ram: Int32, ids: array<Int32>, rarities: array<Int32>) -> Void {
    this.ram = ram;
    this.equippedIds = ids;
    this.equippedRarity = rarities;
  }

  public func IsGhosted() -> Bool {
    return this.ghostFloor == this.current;
  }

  public func DaemonCost(id: Int32) -> Int32 {
    let k = 0;
    while k < ArraySize(this.equippedIds) {
      if this.equippedIds[k] == id {
        return NWDaemon.RamCost(id, this.equippedRarity[k]);
      }
      k += 1;
    }
    return 99;
  }

  // Se o daemon está em efeito (para a tela marcar "ATIVO").
  public func IsDaemonActive(id: Int32) -> Bool {
    switch id {
      case 0: return this.zapBonus > 0;
      case 1: return this.mirror;
      case 2: return this.wormTurns > 0;
      case 3: return this.IsGhosted();
      case 4: return this.overloadTurn == this.turn;
      case 5: return this.anchor;
      case 6: return this.fragment;
      default: return false;
    }
  }

  public func CanUseDaemon(id: Int32) -> Bool {
    if !this.IsRunning() || !ArrayContains(this.equippedIds, id) || ArrayContains(this.derezzed, id) || this.ram < this.DaemonCost(id) {
      return false;
    }
    return !this.IsDaemonActive(id);
  }

  // Ativar um daemon é ação livre: só gasta RAM.
  public func UseDaemon(id: Int32) -> Bool {
    if !this.CanUseDaemon(id) {
      return false;
    }
    let cost = this.DaemonCost(id);
    this.ram -= cost;
    switch id {
      case 0: this.zapBonus = 3; break;
      case 1: this.mirror = true; break;
      case 2: this.wormTurns = 3; break;
      case 3: this.ghostFloor = this.current; break;
      case 4:
        this.overloadTurn = this.turn;
        this.actionsLeft += 1;
        break;
      case 5: this.anchor = true; break;
      case 6:
        this.fragment = true;
        this.netInterface += 3;
        break;
      default: break;
    }
    this.Log(NWL.T(s"Daemon \(NWDaemon.Name(id)) ativado (−\(cost) RAM): \(NWDaemon.Description(id)).", s"Daemon \(NWDaemon.Name(id)) activated (−\(cost) RAM): \(NWDaemon.Description(id))."));
    return true;
  }

  // Controle conquistado numa saída parcial: proporcional à profundidade alcançada.
  public func PartialControl() -> Int32 {
    if this.result != NWBreachResult.Disconnected() || this.deepest <= 0 {
      return 0;
    }
    return (this.deepest * 80) / ArraySize(this.floors);
  }
}
