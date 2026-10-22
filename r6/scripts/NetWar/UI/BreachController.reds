// NET War — tela da invasão (fase 5), dentro da mesma tela cheia do mapa.
// Torre de andares à esquerda, andar atual no centro com o defensor, ações à direita,
// d10 animado e registro da invasão. Só apresentação: lê o NetWarSystem e envia ações.
module NetWar.UI

import NetWar.*
import NetWar.Data.*
import NetWar.Breach.*

public class NWBreachView extends IScriptable {
  private let sys: wref<NetWarSystem>;
  private let owner: wref<NetWarMapPopup>;
  private let root: wref<inkCanvas>;
  private let dynamic: wref<inkCanvas>;

  private let dieBox: wref<inkCanvas>;
  private let dieFrame: wref<inkCanvas>;
  private let dieText: wref<inkText>;
  private let dieLabel: wref<inkText>;
  private let dieDetail: wref<inkText>;
  private let dieVerdict: wref<inkText>;
  private let lastSerial: Int32;

  // Minigames: painel compartilhado com a aba TUTORIAL (treino).
  private let mini: ref<NWMiniPanel>;

  public static func Create(sys: wref<NetWarSystem>, owner: wref<NetWarMapPopup>, parent: ref<inkCompoundWidget>) -> ref<NWBreachView> {
    let view = new NWBreachView();
    view.sys = sys;
    view.owner = owner;
    view.lastSerial = -1;
    view.Build(parent);
    return view;
  }

  public func SetVisible(visible: Bool) -> Void {
    this.root.SetVisible(visible);
  }

  public func IsShown() -> Bool {
    return this.root.IsVisible();
  }

  // ------------------------------------------------------------------ montagem fixa

  private func Build(parent: ref<inkCompoundWidget>) -> Void {
    let r = NWInk.Canvas(parent, n"breach_view", 0.0, 0.0, 1920.0, 1080.0);
    this.root = r;
    NWInk.Rect(r, 0.0, 0.0, 1920.0, 1080.0, NWTheme.Bg(), 0.97);
    let gx = 0.0;
    while gx < 1920.0 {
      NWInk.Rect(r, gx, 0.0, 1.0, 1080.0, NWTheme.Cyan(), 0.035);
      gx += 48.0;
    }
    let gy = 0.0;
    while gy < 1080.0 {
      NWInk.Rect(r, 0.0, gy, 1920.0, 1.0, NWTheme.Cyan(), 0.035);
      gy += 48.0;
    }
    NWInk.Rect(r, 0.0, 0.0, 1920.0, 96.0, NWTheme.Bg(), 0.92);
    NWInk.Rect(r, 0.0, 95.0, 1920.0, 1.0, NWTheme.Cyan(), 0.35);
    let title = NWInk.Text(r, 48.0, 14.0, NWL.T("NET::INVASÃO", "NET::BREACH"), 34, NWTheme.Red(), n"Semi-Bold");
    NWTheme.BindGameRed(title);
    NWInk.Text(r, 48.0, 56.0, NWL.T("ARQUITETURA DE REDE // SESSÃO ATIVA", "NET ARCHITECTURE // ACTIVE SESSION"), 16, NWTheme.Muted(), n"Medium");

    NWInk.Panel(r, 48.0, 136.0, 380.0, 820.0, NWTheme.Cyan(), 0.35);
    NWInk.Panel(r, 460.0, 136.0, 900.0, 540.0, NWTheme.Cyan(), 0.35);
    NWInk.Panel(r, 460.0, 700.0, 900.0, 256.0, NWTheme.Red(), 0.3);
    NWInk.Text(r, 484.0, 714.0, NWL.T("REGISTRO DA INVASÃO", "BREACH LOG"), 16, NWTheme.Red(), n"Semi-Bold");
    NWInk.Panel(r, 1392.0, 136.0, 480.0, 820.0, NWTheme.Cyan(), 0.35);

    this.dynamic = NWInk.Canvas(r, n"breach_dynamic", 0.0, 0.0, 1920.0, 1080.0);

    // d10: caixa persistente para a animação não ser recriada a cada atualização.
    let die = NWInk.Canvas(r, n"die", 1110.0, 200.0, 220.0, 260.0);
    this.dieBox = die;
    NWInk.Text(die, 0.0, 0.0, NWL.T("ÚLTIMA ROLAGEM", "LAST ROLL"), 14, NWTheme.Muted(), n"Medium");
    let frame = NWInk.Canvas(die, n"die_frame", 40.0, 28.0, 140.0, 140.0);
    frame.SetRenderTransformPivot(Vector2(0.5, 0.5));
    this.dieFrame = frame;
    NWInk.Rect(frame, 0.0, 0.0, 140.0, 140.0, NWTheme.Yellow(), 0.08);
    NWInk.Frame(frame, 0.0, 0.0, 140.0, 140.0, NWTheme.Yellow(), 1.0);
    NWInk.Text(frame, 8.0, 4.0, "d10", 14, NWTheme.Yellow(), n"Medium");
    this.dieText = NWInk.Text(frame, 40.0, 30.0, "-", 64, NWTheme.Yellow(), n"Semi-Bold");
    this.dieLabel = NWInk.Text(die, 0.0, 180.0, "", 16, NWTheme.Text(), n"Medium");
    this.dieDetail = NWInk.Text(die, 0.0, 204.0, "", 16, NWTheme.Muted(), n"Medium");
    this.dieVerdict = NWInk.Text(die, 0.0, 228.0, "", 20, NWTheme.Cyan(), n"Semi-Bold");

    this.mini = NWMiniPanel.Create(this.sys, r);
    this.mini.SetBreachHost(this);

    let keys: array<String> = ["LMB", "ESC"];
    let labels: array<String> = [NWL.T("Usar ação", "Use action"), NWL.T("Fechar (a invasão continua)", "Close (the breach goes on)")];
    let k = 0;
    while k < 2 {
      let y = 984.0 + Cast<Float>(k) * 40.0;
      let color = k == 1 ? NWTheme.Red() : NWTheme.Text();
      NWInk.Frame(r, 1392.0, y, 60.0, 28.0, color, 1.0);
      NWInk.Text(r, 1404.0, y + 2.0, keys[k], 16, color, n"Medium");
      NWInk.Text(r, 1466.0, y + 2.0, labels[k], 18, NWTheme.Text(), n"Medium");
      k += 1;
    }
  }

  // ------------------------------------------------------------------ atualização

  public func Refresh() -> Void {
    let sys = this.sys;
    if !IsDefined(sys) {
      return;
    }
    let d = this.dynamic;
    d.RemoveAllChildren();
    this.DrawHeader(d);
    this.DrawTower(d);
    this.DrawFloor(d);
    this.DrawLog(d);
    this.DrawActions(d);
    this.DrawModeToggle(d);
    this.UpdateDie();
    this.mini.Draw();
    this.dieBox.SetVisible(!this.sys.HasMiniGame());
  }

  // ------------------------------------------------------------------ minigame do Backdoor

  private func DrawModeToggle(d: ref<inkCanvas>) -> Void {
    let on = this.sys.UseMinigames();
    let label = on ? NWL.T("TESTES: MINIGAME", "CHECKS: MINIGAME") : NWL.T("TESTES: DADO d10", "CHECKS: d10 DIE");
    NWInk.Frame(d, 1660.0, 984.0, 212.0, 30.0, NWTheme.Yellow(), 0.6);
    NWInk.Text(d, 1672.0, 988.0, label, 15, NWTheme.Yellow(), n"Semi-Bold");
    let hit = NWInk.HitArea(d, n"mg_toggle", 1660.0, 984.0, 212.0, 30.0);
    hit.RegisterToCallback(n"OnRelease", this, n"OnActionRelease");
  }

  private func DrawHeader(d: ref<inkCanvas>) -> Void {
    let sys = this.sys;
    let name = NWText.Upper(sys.GetBreachNodeName());
    let color = sys.IsBreachBlackwall() ? NWTheme.Crimson() : NWTheme.Cyan();
    NWInk.Text(d, 420.0, 26.0, s"// \(name)", 34, color, n"Semi-Bold");
    let arch = NWText.Upper(sys.GetBreachStyleName());
    let k = 0;
    while k < sys.GetBreachModCount() {
      arch = arch + " · " + NWText.Upper(sys.GetBreachModName(k));
      k += 1;
    }
    NWInk.Text(d, 420.0, 66.0, arch, 16, sys.IsBreachBlackwall() ? NWTheme.Crimson() : NWTheme.Yellow(), n"Medium");
    NWInk.Text(d, 1392.0, 22.0, NWL.T(s"TURNO \(sys.GetBreachTurn())", s"TURN \(sys.GetBreachTurn())"), 22, NWTheme.Text(), n"Semi-Bold");
    NWInk.Text(d, 1392.0, 54.0, NWL.T(s"AÇÕES DE NET \(sys.GetBreachActionsLeft()) / \(sys.GetBreachActionsPerTurn())", s"NET ACTIONS \(sys.GetBreachActionsLeft()) / \(sys.GetBreachActionsPerTurn())"), 18, NWTheme.Yellow(), n"Medium");
    NWInk.Text(d, 1640.0, 22.0, s"INTERFACE \(sys.GetInterface())", 22, NWTheme.Yellow(), n"Semi-Bold");
  }

  private func DrawTower(d: ref<inkCanvas>) -> Void {
    let sys = this.sys;
    let count = sys.GetBreachFloorCount();
    let current = sys.GetBreachCurrentFloor();
    NWInk.Text(d, 68.0, 150.0, NWL.T(s"ARQUITETURA · \(count) ANDARES", s"ARCHITECTURE · \(count) FLOORS"), 16, NWTheme.Cyan(), n"Semi-Bold");
    let rowH = MinF(72.0, 760.0 / Cast<Float>(Max(1, count)));
    let k = 0;
    while k < count {
      let y = 184.0 + Cast<Float>(k) * rowH;
      let isCurrent = k == current;
      let revealed = sys.IsBreachFloorRevealed(k);
      let cleared = sys.IsBreachFloorCleared(k);
      let kind = sys.GetBreachFloorKind(k);
      let color = revealed ? this.KindColor(kind) : NWTheme.Muted();
      if isCurrent {
        NWInk.Rect(d, 64.0, y, 348.0, rowH - 8.0, NWTheme.Cyan(), 0.12);
        NWInk.Frame(d, 64.0, y, 348.0, rowH - 8.0, NWTheme.Cyan(), 1.0);
      } else {
        NWInk.Frame(d, 64.0, y, 348.0, rowH - 8.0, color, cleared ? 0.2 : 0.45);
      }
      // Conector vertical da torre.
      if k < count - 1 {
        NWInk.Rect(d, 84.0, y + rowH - 8.0, 2.0, 8.0, NWTheme.Cyan(), 0.5);
      }
      NWInk.Text(d, 78.0, y + 6.0, NWL.T(s"ANDAR \(k + 1)", s"FLOOR \(k + 1)"), 14, isCurrent ? NWTheme.Cyan() : NWTheme.Muted(), n"Medium");
      let label = revealed ? sys.GetBreachFloorLabel(k) : "???";
      if sys.BreachFloorHasAlt(k) {
        let altLabel = revealed ? sys.GetBreachFloorAltLabel(k) : "???";
        NWInk.Text(d, 160.0, y + 6.0, NWL.T("BIFURCAÇÃO", "FORK"), 14, NWTheme.Yellow(), n"Semi-Bold");
        label = "E: " + this.Clip(label, 12) + "  D: " + this.Clip(altLabel, 12);
      }
      NWInk.Text(d, 78.0, y + 24.0, this.Clip(label, 30), 18, cleared ? NWTheme.Muted() : color, n"Semi-Bold");
      if isCurrent {
        NWInk.Text(d, 360.0, y + 14.0, "V", 26, NWTheme.Cyan(), n"Semi-Bold");
      }
      k += 1;
    }
  }

  private func DrawFloor(d: ref<inkCanvas>) -> Void {
    let sys = this.sys;
    let k = sys.GetBreachCurrentFloor();
    let count = sys.GetBreachFloorCount();
    let kind = sys.GetBreachFloorKind(k);
    let cleared = sys.IsBreachFloorCleared(k);
    let color = this.KindColor(kind);
    NWInk.Text(d, 484.0, 152.0, NWL.T(s"ANDAR \(k + 1) / \(count)", s"FLOOR \(k + 1) / \(count)"), 18, NWTheme.Muted(), n"Medium");
    NWInk.Text(d, 484.0, 178.0, NWText.Upper(sys.GetBreachFloorKindName(k)), 40, color, n"Semi-Bold");
    if sys.IsBreachFloorLobby(k) {
      NWInk.Text(d, 640.0, 152.0, "LOBBY", 18, NWTheme.Cyan(), n"Semi-Bold");
    }

    let y = 244.0;
    if kind == NWFloorKind.Ice() {
      let ice = sys.GetBreachFloorIce(k);
      NWInk.Text(d, 484.0, y, NWText.Upper(NWIce.Name(ice)), 32, NWTheme.Red(), n"Semi-Bold");
      y += 48.0;
      NWInk.Text(d, 484.0, y, NWL.T(s"VEL \(NWIce.Speed(ice))   PER \(NWIce.Perception(ice))   ATQ \(NWIce.Attack(ice))   DEF \(NWIce.Defense(ice))", s"SPD \(NWIce.Speed(ice))   PER \(NWIce.Perception(ice))   ATK \(NWIce.Attack(ice))   DEF \(NWIce.Defense(ice))"), 20, NWTheme.Text(), n"Medium");
      y += 30.0;
      NWInk.Text(d, 484.0, y, NWL.T(s"EFEITO: \(NWIce.EffectText(ice))", s"EFFECT: \(NWIce.EffectText(ice))"), 16, NWTheme.Yellow(), n"Medium");
      y += 30.0;
      let rez = sys.GetBreachFloorRez(k);
      let rezMax = sys.GetBreachFloorRezMax(k);
      NWInk.Text(d, 484.0, y, s"REZ \(rez) / \(rezMax)", 18, NWTheme.Muted(), n"Medium");
      NWInk.Rect(d, 484.0, y + 28.0, 560.0, 10.0, NWTheme.Dark(), 1.0);
      NWInk.Rect(d, 484.0, y + 28.0, 560.0 * Cast<Float>(rez) / Cast<Float>(Max(1, rezMax)), 10.0, NWTheme.Red(), 1.0);
      y += 60.0;
      if !cleared {
        NWInk.Text(d, 484.0, y, NWL.T("Bloqueia a descida e ataca no fim do turno. Zap derruba; Slide passa por ele.", "Blocks the way down and attacks at end of turn. Zap takes it down; Slide gets past it."), 18, NWTheme.Text(), n"Medium");
      }
    }
    if kind == NWFloorKind.Password() {
      NWInk.Text(d, 484.0, y, s"DV \(sys.GetBreachFloorDV(k))", 32, NWTheme.Yellow(), n"Semi-Bold");
      y += 52.0;
      if !cleared {
        NWInk.Text(d, 484.0, y, NWL.T("Use Backdoor (d10 + Interface contra o DV) para quebrar.", "Use Backdoor (d10 + Interface vs DV) to break it."), 18, NWTheme.Text(), n"Medium");
      }
    }
    if kind == NWFloorKind.File() {
      NWInk.Text(d, 484.0, y, s"€$ \(sys.GetBreachFloorEddies(k))   DV \(sys.GetBreachFloorDV(k))", 32, NWTheme.Yellow(), n"Semi-Bold");
      y += 52.0;
      NWInk.Text(d, 484.0, y, cleared ? NWL.T("Arquivo baixado.", "File downloaded.") : NWL.T("Eye-Dee para baixar (falha dá rastreio). Pode pular e descer.", "Eye-Dee to download (failure adds trace). You can skip it and descend."), 18, NWTheme.Text(), n"Medium");
    }
    if kind == NWFloorKind.DaemonCache() {
      NWInk.Text(d, 484.0, y, sys.GetBreachFloorLabel(k), 28, NWTheme.Faction(4), n"Semi-Bold");
      y += 52.0;
      NWInk.Text(d, 484.0, y, NWL.T("Daemon coletado ao chegar. Fica com você se não for expulso.", "Daemon collected on arrival. You keep it unless you get kicked out."), 18, NWTheme.Text(), n"Medium");
    }
    if kind == NWFloorKind.ControlNode() {
      NWInk.Text(d, 484.0, y, s"DV \(sys.GetBreachFloorDV(k))", 32, NWTheme.Yellow(), n"Semi-Bold");
      y += 52.0;
      if !cleared {
        NWInk.Text(d, 484.0, y, NWL.T("Use Controlar para tomar o nó e dominar o território.", "Use Control to take the node and the territory."), 18, NWTheme.Text(), n"Medium");
      }
    }
    let mini = sys.GetMiniLastText();
    if StrLen(mini) > 0 && !sys.HasMiniGame() {
      NWInk.Text(d, 484.0, 524.0, mini, 20, (StrBeginsWith(mini, "SENHA") || StrBeginsWith(mini, "PASSWORD") || StrBeginsWith(mini, "ARQUIVO") || StrBeginsWith(mini, "FILE") || StrBeginsWith(mini, "ZAP") || StrBeginsWith(mini, "CRITICAL") || StrBeginsWith(mini, "SLIDE") || StrBeginsWith(mini, "ESQUIVA") || StrBeginsWith(mini, "FULL DODGE") || StrBeginsWith(mini, "NÚCLEO") || StrBeginsWith(mini, "CORE") || StrBeginsWith(mini, "SONAR")) ? NWTheme.Cyan() : NWTheme.Red(), n"Semi-Bold");
    }
    if cleared && kind != NWFloorKind.ControlNode() {
      NWInk.Text(d, 484.0, 560.0, NWL.T("ANDAR LIVRE — DESÇA PARA O PRÓXIMO", "FLOOR CLEAR — DESCEND TO THE NEXT ONE"), 20, NWTheme.Cyan(), n"Semi-Bold");
    }
    // Arquitetura: descrição do estilo e dos modificadores.
    let my = 470.0;
    NWInk.Text(d, 484.0, my, NWText.Upper(sys.GetBreachStyleName()) + ": " + sys.GetBreachStyleDescription(), 15, NWTheme.Muted(), n"Medium");
    let m = 0;
    while m < sys.GetBreachModCount() {
      my += 20.0;
      NWInk.Text(d, 484.0, my, NWText.Upper(sys.GetBreachModName(m)) + ": " + sys.GetBreachModDescription(m), 15, NWTheme.Yellow(), n"Medium");
      m += 1;
    }

    this.DrawDaemonBar(d);

    // Resultado da sessão.
    let result = sys.GetBreachResult();
    if result > 0 {
      let text = NWL.T("DESCONECTADO", "DISCONNECTED");
      let rc = NWTheme.Yellow();
      if result == 1 { text = sys.IsBreachBlackwall() ? NWL.T("SAIU VIVO DA BLACKWALL", "MADE IT OUT OF THE BLACKWALL") : NWL.T("NÓ DOMINADO", "NODE TAKEN"); rc = NWTheme.Cyan(); }
      if result == 3 { text = NWL.T("EXPULSO DA REDE", "KICKED OUT OF THE NET"); rc = NWTheme.Red(); }
      NWInk.Rect(d, 460.0, 470.0, 900.0, 206.0, NWTheme.Bg(), 0.94);
      NWInk.Frame(d, 460.0, 470.0, 900.0, 206.0, rc, 1.0);
      NWInk.Text(d, 484.0, 490.0, text, 44, rc, n"Semi-Bold");
      NWInk.Text(d, 484.0, 548.0, NWL.T(s"Rastreio ganho na sessão: +\(sys.GetBreachTraceGained())", s"Trace gained this session: +\(sys.GetBreachTraceGained())"), 18, NWTheme.Text(), n"Medium");
      this.Button(d, n"act_back", 484.0, 596.0, 320.0, 56.0, NWL.T("VOLTAR AO MAPA", "BACK TO THE MAP"), true, rc);
    }
  }

  // Daemons equipados: ação livre que gasta RAM do deck.
  private func DrawDaemonBar(d: ref<inkCanvas>) -> Void {
    let sys = this.sys;
    let count = sys.GetBreachDaemonCount();
    if count == 0 {
      NWInk.Text(d, 484.0, 616.0, NWL.T("DAEMONS: nenhum equipado (aba DAEMONS no mapa)", "DAEMONS: none equipped (DAEMONS tab on the map)"), 16, NWTheme.Muted(), n"Medium");
      return;
    }
    NWInk.Text(d, 484.0, 594.0, NWL.T(s"DAEMONS · AÇÃO LIVRE · RAM \(sys.GetBreachRam())", s"DAEMONS · FREE ACTION · RAM \(sys.GetBreachRam())"), 14, NWTheme.Faction(4), n"Semi-Bold");
    let w = MinF(214.0, (852.0 - 8.0 * Cast<Float>(count - 1)) / Cast<Float>(count));
    let k = 0;
    while k < count {
      let id = sys.GetBreachDaemonId(k);
      let x = 484.0 + Cast<Float>(k) * (w + 8.0);
      let y = 614.0;
      let active = sys.IsBreachDaemonActive(id);
      let usable = sys.CanBreachUseDaemon(id);
      let color = NWTheme.Rarity(sys.GetDaemonRarity(id));
      if active {
        NWInk.Rect(d, x, y, w, 52.0, NWTheme.Cyan(), 0.18);
        NWInk.Frame(d, x, y, w, 52.0, NWTheme.Cyan(), 1.0);
      } else {
        NWInk.Rect(d, x, y, w, 52.0, color, usable ? 0.12 : 0.04);
        NWInk.Frame(d, x, y, w, 52.0, usable ? color : NWTheme.Muted(), usable ? 0.9 : 0.3);
      }
      let textColor = active ? NWTheme.Cyan() : (usable ? color : NWTheme.Muted());
      NWInk.Text(d, x + 10.0, y + 4.0, this.Clip(NWText.Upper(sys.GetDaemonName(id)), 16), 18, textColor, n"Semi-Bold");
      let derezzed = sys.IsBreachDaemonDerezzed(id);
      NWInk.Text(d, x + 10.0, y + 28.0, derezzed ? NWL.T("DERREZZADO", "DEREZZED") : (active ? NWL.T("ATIVO", "ACTIVE") : s"RAM \(sys.GetBreachDaemonCost(id))"), 15, derezzed ? NWTheme.Red() : textColor, n"Medium");
      if usable {
        let hit = NWInk.HitArea(d, StringToName(s"dmn_use_\(id)"), x, y, w, 52.0);
        hit.RegisterToCallback(n"OnRelease", this, n"OnActionRelease");
      }
      k += 1;
    }
  }

  private func DrawLog(d: ref<inkCanvas>) -> Void {
    let sys = this.sys;
    let n = Min(7, sys.GetBreachLogCount());
    let k = 0;
    while k < n {
      let color = k == 0 ? NWTheme.Text() : NWTheme.Muted();
      NWInk.Text(d, 484.0, 746.0 + Cast<Float>(k) * 28.0, this.Clip(sys.GetBreachLogLine(k), 92), 18, color, n"Medium");
      k += 1;
    }
  }

  private func DrawActions(d: ref<inkCanvas>) -> Void {
    let sys = this.sys;
    NWInk.Text(d, 1416.0, 150.0, "NETRUNNER", 16, NWTheme.Cyan(), n"Semi-Bold");
    let hp = sys.GetBreachHP();
    let hpMax = Max(1, sys.GetBreachHPMax());
    NWInk.Text(d, 1416.0, 176.0, NWL.T(s"HP DA SESSÃO  \(hp) / \(hpMax)", s"SESSION HP  \(hp) / \(hpMax)"), 20, NWTheme.Text(), n"Semi-Bold");
    NWInk.Text(d, 1700.0, 176.0, s"RAM \(sys.GetBreachRam()) / \(sys.GetBreachRamMax())", 20, NWTheme.Cyan(), n"Semi-Bold");
    NWInk.Rect(d, 1416.0, 206.0, 432.0, 10.0, NWTheme.Dark(), 1.0);
    let hpColor = hp * 3 < hpMax ? NWTheme.Red() : NWTheme.Cyan();
    NWInk.Rect(d, 1416.0, 206.0, 432.0 * Cast<Float>(hp) / Cast<Float>(hpMax), 10.0, hpColor, 1.0);
    NWInk.Text(d, 1416.0, 228.0, NWL.T(s"RASTREIO NA SESSÃO  +\(sys.GetBreachTraceGained())", s"SESSION TRACE  +\(sys.GetBreachTraceGained())"), 18, NWTheme.Red(), n"Medium");
    if sys.GetBreachLootCount() > 0 {
      NWInk.Text(d, 1416.0, 254.0, s"DAEMONS +\(sys.GetBreachLootCount())", 18, NWTheme.Faction(4), n"Semi-Bold");
    }
    let status = sys.GetBreachStatusText();
    if StrLen(status) > 0 {
      NWInk.Text(d, 1560.0, 254.0, status, 16, NWTheme.Red(), n"Semi-Bold");
    }
    if sys.IsBreachCloaked() {
      NWInk.Rect(d, 1700.0, 228.0, 148.0, 26.0, NWTheme.Cyan(), 0.15);
      NWInk.Text(d, 1712.0, 229.0, NWL.T("CAMUFLADO", "CLOAKED"), 18, NWTheme.Cyan(), n"Semi-Bold");
    }

    NWInk.Text(d, 1416.0, 278.0, NWL.T("AÇÕES", "ACTIONS"), 16, NWTheme.Cyan(), n"Semi-Bold");
    let order: array<Int32> = [0, 1, 8, 2, 9, 3, 4, 10, 5, 7, 6];
    let hints: array<String> = [NWL.T("Revela os próximos andares", "Reveals the next floors"), NWL.T("Avança um andar (esquerda na bifurcação)", "Goes down one floor (left at a fork)"), NWL.T("Pega o outro caminho da bifurcação", "Takes the other path at the fork"), NWL.T("Quebra a senha (teste)", "Breaks the password (check)"), NWL.T("Baixa o arquivo (teste)", "Downloads the file (check)"), NWL.T("Toma o nó de controle (teste)", "Takes the control node (check)"), NWL.T("Dano no Black ICE (teste)", "Damages the Black ICE (check)"), NWL.T("Passa pelo ICE (disputa contra PER)", "Gets past the ICE (contest vs PER)"), NWL.T("ICE −3 no ataque, menos rastreio", "ICE −3 to attack, less trace"), NWL.T("O ICE age; ações renovam", "ICE acts; actions refresh"), NWL.T("Sai com o progresso (ICE ativo ataca antes)", "Leaves with your progress (active ICE attacks first)")];
    let k = 0;
    while k < ArraySize(order) {
      let a = order[k];
      let y = 296.0 + Cast<Float>(k) * 58.0;
      let enabled = sys.CanBreachAct(a) && !sys.HasMiniGame();
      let color = a == 6 ? NWTheme.Red() : NWTheme.Cyan();
      if enabled {
        NWInk.Rect(d, 1416.0, y, 432.0, 52.0, color, 0.10);
        NWInk.Frame(d, 1416.0, y, 432.0, 52.0, color, 0.9);
        NWInk.Text(d, 1436.0, y + 3.0, NWText.Upper(sys.GetBreachActionName(a)), 22, color, n"Semi-Bold");
        NWInk.Text(d, 1436.0, y + 29.0, hints[k], 15, NWTheme.Text(), n"Medium");
        let hit = NWInk.HitArea(d, StringToName(s"act_\(a)"), 1416.0, y, 432.0, 52.0);
        hit.RegisterToCallback(n"OnRelease", this, n"OnActionRelease");
      } else {
        NWInk.Frame(d, 1416.0, y, 432.0, 52.0, NWTheme.Muted(), 0.25);
        NWInk.Text(d, 1436.0, y + 3.0, NWText.Upper(sys.GetBreachActionName(a)), 22, NWTheme.Muted(), n"Semi-Bold");
        NWInk.Text(d, 1436.0, y + 29.0, hints[k], 15, NWTheme.Muted(), n"Medium");
      }
      k += 1;
    }
  }

  private func Button(parent: ref<inkCompoundWidget>, name: CName, x: Float, y: Float, w: Float, h: Float, label: String, filled: Bool, color: HDRColor) -> Void {
    if filled {
      NWInk.Rect(parent, x, y, w, h, color, 1.0);
      NWInk.Text(parent, x + 18.0, y + (h - 26.0) / 2.0, label, 22, NWTheme.Bg(), n"Semi-Bold");
    } else {
      NWInk.Frame(parent, x, y, w, h, color, 0.6);
      NWInk.Text(parent, x + 18.0, y + (h - 22.0) / 2.0, label, 18, color, n"Semi-Bold");
    }
    let hit = NWInk.HitArea(parent, name, x, y, w, h);
    hit.RegisterToCallback(n"OnRelease", this, n"OnActionRelease");
  }

  // ------------------------------------------------------------------ d10 animado

  private func UpdateDie() -> Void {
    let sys = this.sys;
    let serial = sys.GetBreachRollSerial();
    if serial == this.lastSerial {
      return;
    }
    let first = this.lastSerial < 0;
    this.lastSerial = serial;
    if serial <= 0 {
      this.dieText.SetText("-");
      this.dieLabel.SetText("");
      this.dieDetail.SetText("");
      this.dieVerdict.SetText("");
      return;
    }
    let ok = sys.IsBreachRollOk();
    let die = sys.GetBreachRollDie();
    this.dieText.SetText(s"\(die)");
    this.dieText.SetMargin(inkMargin(die >= 10 ? 26.0 : 44.0, 30.0, 0.0, 0.0));
    this.dieLabel.SetText(this.Clip(sys.GetBreachRollLabel(), 22));
    this.dieDetail.SetText(s"\(die) + \(sys.GetBreachRollBonus()) = \(sys.GetBreachRollTotal()) vs DV \(sys.GetBreachRollDV())");
    this.dieVerdict.SetText(ok ? NWL.T("SUCESSO", "SUCCESS") : NWL.T("FALHA", "FAIL"));
    this.dieVerdict.SetTintColor(ok ? NWTheme.Cyan() : NWTheme.Red());
    if !first {
      this.PlayDieAnimation();
    }
  }

  private func PlayDieAnimation() -> Void {
    let anim = new inkAnimDef();
    let scale = new inkAnimScale();
    scale.SetStartScale(Vector2(1.5, 1.5));
    scale.SetEndScale(Vector2(1.0, 1.0));
    scale.SetDuration(0.35);
    anim.AddInterpolator(scale);
    let alpha = new inkAnimTransparency();
    alpha.SetStartTransparency(0.2);
    alpha.SetEndTransparency(1.0);
    alpha.SetDuration(0.35);
    anim.AddInterpolator(alpha);
    this.dieFrame.PlayAnimation(anim);
  }

  // ------------------------------------------------------------------ utilidades

  private func KindColor(kind: Int32) -> HDRColor {
    switch kind {
      case 0: return NWTheme.Yellow();
      case 1: return NWTheme.Text();
      case 2: return NWTheme.Cyan();
      case 3: return NWTheme.Red();
      case 4: return NWTheme.Faction(4);
      default: return NWTheme.Muted();
    }
  }

  private func Clip(text: String, maxChars: Int32) -> String {
    if StrLen(text) <= maxChars {
      return text;
    }
    return StrLeft(text, maxChars - 3) + "...";
  }

  // ------------------------------------------------------------------ entrada

  protected cb func OnActionRelease(evt: ref<inkPointerEvent>) -> Bool {
    if !evt.IsAction(n"click") {
      return false;
    }
    this.HandleClick(NameToString(evt.GetTarget().GetName()));
    return true;
  }

  // Também chamado pelo repasse manual de cliques do popup (camadas sem entrada própria).
  public func HandleClick(name: String) -> Void {
    if Equals(name, "mg_toggle") {
      this.sys.SetUseMinigames(!this.sys.UseMinigames());
      this.sys.PlayUISound(NWSound.Click());
      this.Refresh();
      return;
    }
    if StrBeginsWith(name, "mg_") {
      this.mini.HandleClick(name);
      return;
    }
    if Equals(name, "act_back") {
      this.owner.ShowMap();
      return;
    }
    if StrBeginsWith(name, "dmn_use_") {
      let msg = this.sys.BreachUseDaemon(StringToInt(StrAfterLast(name, "_")));
      this.sys.PlayUISound(StrLen(msg) == 0 ? NWSound.Scan() : NWSound.HackFail());
      this.Refresh();
      return;
    }
    if StrBeginsWith(name, "act_") {
      let sys = this.sys;
      let serial = sys.GetBreachRollSerial();
      let hp = sys.GetBreachHP();
      sys.BreachAction(StringToInt(StrAfterFirst(name, "_")));
      this.PlayOutcomeSound(serial, hp);
      this.Refresh();
    }
  }

  // Som conforme o que a ação provocou: fim da sessão > dano do ICE > resultado do d10 > clique.
  private func PlayOutcomeSound(prevSerial: Int32, prevHp: Int32) -> Void {
    let sys = this.sys;
    let result = sys.GetBreachResult();
    if result > 0 {
      // Fim da sessão: a trilha do hacking para.
      sys.StopHackMusic();
    }
    if result == 1 {
      sys.PlayUISound(NWSound.Captured());
      return;
    }
    if result == 3 {
      sys.PlayUISound(NWSound.Denied());
      sys.PlayUISound(NWSound.Hit());
      return;
    }
    if sys.GetBreachHP() < prevHp {
      sys.PlayUISound(NWSound.Hit());
      return;
    }
    if sys.GetBreachRollSerial() != prevSerial && !sys.IsBreachRollOk() {
      sys.PlayUISound(NWSound.HackFail());
      return;
    }
    sys.PlayUISound(NWSound.HackPress());
  }
}
