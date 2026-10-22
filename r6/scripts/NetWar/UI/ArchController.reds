// NET War — aba ARQUITETURAS (fase 6, passo 4): inteligência dos nós inimigos e defesas dos nós do V.
// Só apresentação: lê o NetWarSystem e envia ações. Visão dentro da mesma tela cheia do mapa.
module NetWar.UI

import NetWar.*
import NetWar.Data.*

public class NWArchView extends IScriptable {
  private let sys: wref<NetWarSystem>;
  private let owner: wref<NetWarMapPopup>;
  private let root: wref<inkCanvas>;
  private let dynamic: wref<inkCanvas>;
  private let selected: Int32;
  private let status: String;

  public static func Create(sys: wref<NetWarSystem>, owner: wref<NetWarMapPopup>, parent: ref<inkCompoundWidget>) -> ref<NWArchView> {
    let view = new NWArchView();
    view.sys = sys;
    view.owner = owner;
    view.Build(parent);
    return view;
  }

  public func SetVisible(visible: Bool) -> Void {
    this.root.SetVisible(visible);
  }

  public func Select(i: Int32) -> Void {
    this.selected = i;
    this.status = "";
  }

  // ------------------------------------------------------------------ montagem fixa

  private func Build(parent: ref<inkCompoundWidget>) -> Void {
    let r = NWInk.Canvas(parent, n"arch_view", 0.0, 0.0, 1920.0, 1080.0);
    this.root = r;
    NWInk.Rect(r, 0.0, 0.0, 1920.0, 1080.0, NWTheme.Bg(), 0.97);
    let gx = 0.0;
    while gx < 1920.0 {
      NWInk.Rect(r, gx, 0.0, 1.0, 1080.0, NWTheme.Red(), 0.045);
      gx += 48.0;
    }
    let gy = 0.0;
    while gy < 1080.0 {
      NWInk.Rect(r, 0.0, gy, 1920.0, 1.0, NWTheme.Red(), 0.045);
      gy += 48.0;
    }

    // Barra superior com as abas (ARQUITETURAS ativa).
    NWInk.Rect(r, 0.0, 0.0, 1920.0, 96.0, NWTheme.Bg(), 0.92);
    NWInk.Rect(r, 0.0, 95.0, 1920.0, 1.0, NWTheme.Red(), 0.35);
    let title = NWInk.Text(r, 48.0, 14.0, NWL.T("NET::ACESSO", "NET::ACCESS"), 34, NWTheme.Red(), n"Semi-Bold");
    NWTheme.BindGameRed(title);
    NWInk.Text(r, 48.0, 56.0, NWL.T("TERMINAL DOMÉSTICO // ARQUITETURAS", "HOME TERMINAL // ARCHITECTURES"), 16, NWTheme.Muted(), n"Medium");
    this.Tab(r, n"tab_map", 400.0, NWL.T("MAPA DA REDE", "NETWORK MAP"), false);
    this.Tab(r, n"", 628.0, NWL.T("ARQUITETURAS", "ARCHITECTURES"), true);
    this.Tab(r, n"tab_daemons", 846.0, "DAEMONS", false);
    this.Tab(r, n"tab_logs", 1064.0, NWL.T("REGISTROS", "LOGS"), false);
    this.Tab(r, n"tab_help", 1282.0, "TUTORIAL", false);

    NWInk.Text(r, 48.0, 116.0, NWL.T("ARQUITETURAS", "ARCHITECTURES"), 40, NWTheme.Cyan(), n"Semi-Bold");
    NWInk.Text(r, 48.0, 166.0, NWL.T("Inteligência dos nós inimigos e defesas dos seus nós contra os ataques das facções.", "Intel on enemy nodes and defenses for your nodes against faction attacks."), 18, NWTheme.Muted(), n"Medium");

    NWInk.Panel(r, 48.0, 900.0, 1824.0, 120.0, NWTheme.Red(), 0.3);
    NWInk.Text(r, 72.0, 914.0, NWL.T("REGRAS", "RULES"), 16, NWTheme.Red(), n"Semi-Bold");
    NWInk.Text(r, 72.0, 942.0, NWL.T("Escanear um nó revela o estilo da arquitetura; invadir revela andares, profundidade e modificadores. A inteligência fica velha quando o nó troca de dono.", "Scanning a node reveals its architecture style; breaching reveals floors, depth and modifiers. Intel goes stale when the node changes hands."), 17, NWTheme.Text(), n"Medium");
    NWInk.Text(r, 72.0, 968.0, NWL.T("Cada nó seu tem 3 camadas pagas pelo Banco NetWatch: Senha (+2 na defesa), Black ICE (+1 e absorve um ataque) e Isca (35% de desviar o ataque).", "Each of your nodes has 3 layers paid from the NetWatch Bank: Password (+2 defense), Black ICE (+1 and absorbs one attack) and Decoy (35% to divert the attack)."), 17, NWTheme.Text(), n"Medium");
    NWInk.Text(r, 72.0, 994.0, NWL.T("Remover uma camada não devolve os eddies. Perder o nó ou a ofensiva da Netwatch destrói as defesas.", "Removing a layer doesn't refund the eddies. Losing the node or a Netwatch offensive destroys the defenses."), 17, NWTheme.Muted(), n"Medium");

    this.dynamic = NWInk.Canvas(r, n"arch_dynamic", 0.0, 0.0, 1920.0, 1080.0);
  }

  private func Tab(r: ref<inkCanvas>, name: CName, x: Float, label: String, active: Bool) -> Void {
    let w = x == 400.0 ? 220.0 : 210.0;
    if active {
      NWInk.Rect(r, x, 24.0, w, 48.0, NWTheme.Red(), 1.0);
      NWInk.Text(r, x + 24.0, 33.0, label, 22, NWTheme.Bg(), n"Semi-Bold");
    } else {
      NWInk.Frame(r, x, 24.0, w, 48.0, NWTheme.Red(), 0.45);
      NWInk.Text(r, x + 24.0, 33.0, label, 22, NotEquals(name, n"") ? NWTheme.Text() : NWTheme.Muted(), n"Semi-Bold");
    }
    if NotEquals(name, n"") {
      let hit = NWInk.HitArea(r, name, x, 24.0, w, 48.0);
      hit.RegisterToCallback(n"OnRelease", this, n"OnRelease");
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
    this.DrawList(d);
    if sys.GetNodeOwner(this.selected) == NWFaction.V() {
      this.DrawDefenses(d);
    } else {
      this.DrawIntel(d);
    }
    NWInk.Text(d, 1500.0, 116.0, NWL.T(s"BANCO NETWATCH  €$ \(sys.GetEddies())", s"NETWATCH BANK  €$ \(sys.GetEddies())"), 22, NWTheme.Yellow(), n"Semi-Bold");
    if StrLen(this.status) > 0 {
      NWInk.Text(d, 1500.0, 150.0, this.status, 18, NWTheme.Yellow(), n"Medium");
    }
  }

  private func DrawList(d: ref<inkCanvas>) -> Void {
    let sys = this.sys;
    NWInk.Text(d, 48.0, 206.0, NWL.T("NÓS DA REDE", "NETWORK NODES"), 18, NWTheme.Cyan(), n"Semi-Bold");
    let n = sys.GetNodeCount();
    let i = 0;
    while i < n {
      let x = 48.0;
      let y = 236.0 + Cast<Float>(i) * 46.0;
      let owner = sys.GetNodeOwner(i);
      let color = NWTheme.Faction(owner);
      let isSelected = i == this.selected;
      NWInk.Rect(d, x, y, 520.0, 40.0, isSelected ? NWTheme.Cyan() : color, isSelected ? 0.16 : 0.05);
      NWInk.Frame(d, x, y, 520.0, 40.0, isSelected ? NWTheme.Cyan() : color, isSelected ? 1.0 : 0.3);
      NWInk.Rect(d, x + 12.0, y + 14.0, 12.0, 12.0, color, 1.0);
      NWInk.Text(d, x + 36.0, y + 8.0, this.Clip(NWText.Upper(sys.GetNodeName(i)), 22), 18, isSelected ? NWTheme.Cyan() : NWTheme.Text(), n"Semi-Bold");
      let tag = "";
      if owner == NWFaction.V() {
        tag = NWL.T(s"DEFESAS \(sys.GetNodeDefenseCount(i))/3", s"DEFENSES \(sys.GetNodeDefenseCount(i))/3");
      } else {
        if sys.IsIntelStale(i) {
          tag = NWL.T("INTEL VELHA", "STALE INTEL");
        } else {
          tag = sys.HasIntel(i) ? (sys.GetIntelVisits(i) > 0 ? NWL.T("INTEL COMPLETA", "FULL INTEL") : NWL.T("ESTILO CONHECIDO", "STYLE KNOWN")) : NWL.T("SEM INTEL", "NO INTEL");
        }
      }
      NWInk.Text(d, x + 340.0, y + 10.0, tag, 15, owner == NWFaction.V() ? NWTheme.Cyan() : NWTheme.Muted(), n"Medium");
      let hit = NWInk.HitArea(d, StringToName(s"arch_node_\(i)"), x, y, 520.0, 40.0);
      hit.RegisterToCallback(n"OnRelease", this, n"OnRelease");
      i += 1;
    }
  }

  private func DrawHeader(d: ref<inkCanvas>) -> Void {
    let sys = this.sys;
    let i = this.selected;
    let color = NWTheme.Faction(sys.GetNodeOwner(i));
    NWInk.Panel(d, 600.0, 206.0, 1272.0, 676.0, color, 0.5);
    NWInk.Text(d, 632.0, 222.0, NWText.Upper(sys.GetNodeName(i)), 34, color, n"Semi-Bold");
    NWInk.Text(d, 632.0, 268.0, NWL.T(s"\(sys.GetNodeOwnerName(i)) · controle \(sys.GetNodeControl(i))% · \(sys.GetNodeFloorsText(i)) andares · DV \(sys.GetNodeDVText(i))", s"\(sys.GetNodeOwnerName(i)) · control \(sys.GetNodeControl(i))% · \(sys.GetNodeFloorsText(i)) floors · DV \(sys.GetNodeDVText(i))"), 18, NWTheme.Text(), n"Medium");
  }

  // Nó do V: 3 camadas de defesa.
  private func DrawDefenses(d: ref<inkCanvas>) -> Void {
    let sys = this.sys;
    let i = this.selected;
    this.DrawHeader(d);
    NWInk.Text(d, 632.0, 316.0, NWL.T("DEFESAS DO NÓ", "NODE DEFENSES"), 20, NWTheme.Cyan(), n"Semi-Bold");
    NWInk.Text(d, 632.0, 344.0, sys.GetNodeDefenseSummary(i), 17, NWTheme.Text(), n"Medium");

    let slot = 0;
    while slot < 3 {
      let x = 632.0 + Cast<Float>(slot) * 412.0;
      let y = 392.0;
      let t = sys.GetDefenseLayer(i, slot);
      if t == NWDefense.None() {
        NWInk.Frame(d, x, y, 396.0, 300.0, NWTheme.Muted(), 0.4);
        NWInk.Text(d, x + 20.0, y + 16.0, NWL.T(s"CAMADA \(slot + 1) · VAZIA", s"LAYER \(slot + 1) · EMPTY"), 20, NWTheme.Muted(), n"Semi-Bold");
        let k = 1;
        while k <= 3 {
          let by = y + 56.0 + Cast<Float>(k - 1) * 78.0;
          let label = s"\(NWText.Upper(sys.GetDefenseName(k)))  €$ \(sys.GetDefenseCost(k))";
          let affordable = sys.GetEddies() >= sys.GetDefenseCost(k);
          this.Button(d, StringToName(s"def_build_\(slot)_\(k)"), x + 20.0, by, 356.0, 40.0, label, affordable ? NWTheme.Cyan() : NWTheme.Muted());
          NWInk.Text(d, x + 24.0, by + 44.0, sys.GetDefenseDescription(k), 14, NWTheme.Muted(), n"Medium");
          k += 1;
        }
      } else {
        let color = this.DefenseColor(t);
        NWInk.Rect(d, x, y, 396.0, 300.0, color, 0.10);
        NWInk.Frame(d, x, y, 396.0, 300.0, color, 1.0);
        NWInk.Text(d, x + 20.0, y + 16.0, NWL.T(s"CAMADA \(slot + 1)", s"LAYER \(slot + 1)"), 16, NWTheme.Muted(), n"Semi-Bold");
        NWInk.Text(d, x + 20.0, y + 44.0, NWText.Upper(sys.GetDefenseName(t)), 30, color, n"Semi-Bold");
        NWInk.Text(d, x + 20.0, y + 92.0, sys.GetDefenseDescription(t), 17, NWTheme.Text(), n"Medium");
        this.Button(d, StringToName(s"def_remove_\(slot)"), x + 20.0, y + 238.0, 200.0, 40.0, NWL.T("REMOVER", "REMOVE"), NWTheme.Red());
      }
      slot += 1;
    }
    NWInk.Text(d, 632.0, 720.0, NWL.T("Os ataques das facções aparecem no registro do mapa. Black ICE que absorve um ataque é destruído e libera a camada.", "Faction attacks show up in the map log. Black ICE that absorbs an attack is destroyed and frees its layer."), 16, NWTheme.Muted(), n"Medium");
  }

  // Nó inimigo: o que o V sabe da arquitetura.
  private func DrawIntel(d: ref<inkCanvas>) -> Void {
    let sys = this.sys;
    let i = this.selected;
    this.DrawHeader(d);
    NWInk.Text(d, 632.0, 316.0, NWL.T("INTELIGÊNCIA", "INTEL"), 20, NWTheme.Cyan(), n"Semi-Bold");
    if !sys.HasIntel(i) {
      NWInk.Text(d, 632.0, 356.0, NWL.T("SEM INTELIGÊNCIA", "NO INTEL"), 30, NWTheme.Muted(), n"Semi-Bold");
      NWInk.Text(d, 632.0, 400.0, NWL.T("Escaneie o nó no mapa para revelar o estilo da arquitetura, ou invada para mapear tudo.", "Scan the node on the map to reveal its architecture style, or breach it to map everything."), 18, NWTheme.Text(), n"Medium");
      NWInk.Text(d, 632.0, 440.0, NWL.T(s"Estilo provável (pelo dono atual): \(sys.GetLikelyStyleName(i))", s"Likely style (from the current owner): \(sys.GetLikelyStyleName(i))"), 18, NWTheme.Muted(), n"Medium");
      this.Button(d, n"arch_open_map", 632.0, 800.0, 260.0, 48.0, NWL.T("ABRIR NO MAPA", "OPEN ON MAP"), NWTheme.Cyan());
      return;
    }
    let y = 356.0;
    if sys.IsIntelStale(i) {
      NWInk.Text(d, 632.0, y, NWL.T("INTEL VELHA: o nó trocou de dono e a arquitetura provavelmente foi refeita.", "STALE INTEL: the node changed hands and the architecture was probably rebuilt."), 18, NWTheme.Yellow(), n"Semi-Bold");
      NWInk.Text(d, 632.0, y + 28.0, NWL.T(s"Estilo provável agora: \(sys.GetLikelyStyleName(i))", s"Likely style now: \(sys.GetLikelyStyleName(i))"), 17, NWTheme.Muted(), n"Medium");
      y += 72.0;
    }
    NWInk.Text(d, 632.0, y, NWL.T("ESTILO", "STYLE"), 16, NWTheme.Muted(), n"Semi-Bold");
    NWInk.Text(d, 632.0, y + 22.0, NWText.Upper(sys.GetIntelStyleName(i)), 30, NWTheme.Cyan(), n"Semi-Bold");
    NWInk.Text(d, 632.0, y + 64.0, sys.GetIntelStyleDescription(i), 18, NWTheme.Text(), n"Medium");
    y += 116.0;

    let visits = sys.GetIntelVisits(i);
    let floors = sys.GetIntelFloors(i);
    this.Stat(d, 632.0, y, NWL.T("ANDARES", "FLOORS"), visits > 0 ? s"\(floors)" : s"~\(floors)");
    this.Stat(d, 932.0, y, NWL.T("MAIS FUNDO ALCANÇADO", "DEEPEST REACHED"), visits > 0 ? s"\(Min(sys.GetIntelDepth(i), floors)) / \(floors)" : "—");
    this.Stat(d, 1232.0, y, NWL.T("INVASÕES", "BREACHES"), s"\(visits)");
    y += 100.0;
    NWInk.Text(d, 632.0, y, NWL.T("MODIFICADORES (ÚLTIMA INVASÃO)", "MODIFIERS (LAST BREACH)"), 16, NWTheme.Muted(), n"Semi-Bold");
    NWInk.Text(d, 632.0, y + 24.0, sys.GetIntelModsText(i), 20, visits > 0 ? NWTheme.Yellow() : NWTheme.Muted(), n"Semi-Bold");
    NWInk.Text(d, 632.0, y + 56.0, NWL.T("Modificadores são sorteados a cada invasão; a última serve de pista, não de garantia.", "Modifiers are rolled on every breach; the last one is a hint, not a guarantee."), 15, NWTheme.Muted(), n"Medium");
    this.Button(d, n"arch_open_map", 632.0, 800.0, 260.0, 48.0, NWL.T("ABRIR NO MAPA", "OPEN ON MAP"), NWTheme.Cyan());
  }

  private func Stat(d: ref<inkCanvas>, x: Float, y: Float, label: String, value: String) -> Void {
    NWInk.Text(d, x, y, label, 16, NWTheme.Muted(), n"Semi-Bold");
    NWInk.Text(d, x, y + 22.0, value, 34, NWTheme.Text(), n"Semi-Bold");
  }

  private func DefenseColor(t: Int32) -> HDRColor {
    switch t {
      case 1: return NWTheme.Cyan();
      case 2: return NWTheme.Crimson();
      default: return NWTheme.Yellow();
    }
  }

  private func Clip(text: String, maxChars: Int32) -> String {
    return StrLen(text) > maxChars ? StrLeft(text, maxChars - 1) + "." : text;
  }

  private func Button(parent: ref<inkCompoundWidget>, name: CName, x: Float, y: Float, w: Float, h: Float, label: String, color: HDRColor) -> Void {
    NWInk.Rect(parent, x, y, w, h, color, 0.12);
    NWInk.Frame(parent, x, y, w, h, color, 0.9);
    NWInk.Text(parent, x + 16.0, y + (h - 22.0) / 2.0, label, 18, color, n"Semi-Bold");
    let hit = NWInk.HitArea(parent, name, x, y, w, h);
    hit.RegisterToCallback(n"OnRelease", this, n"OnRelease");
  }

  // ------------------------------------------------------------------ entrada

  protected cb func OnRelease(evt: ref<inkPointerEvent>) -> Bool {
    if !evt.IsAction(n"click") {
      return false;
    }
    let sys = this.sys;
    let name = NameToString(evt.GetTarget().GetName());
    if Equals(name, "tab_help") {
      this.sys.PlayUISound(NWSound.Select());
      this.owner.ShowTutorial();
      return true;
    }
    if Equals(name, "tab_map") {
      sys.PlayUISound(NWSound.Select());
      this.owner.ShowMap();
      return true;
    }
    if Equals(name, "tab_logs") {
      sys.PlayUISound(NWSound.Select());
      this.owner.ShowLogs();
      return true;
    }
    if Equals(name, "tab_daemons") {
      sys.PlayUISound(NWSound.Select());
      this.owner.ShowDaemons();
      return true;
    }
    if Equals(name, "arch_open_map") {
      sys.PlayUISound(NWSound.Select());
      this.owner.ShowMapAt(this.selected);
      return true;
    }
    if StrBeginsWith(name, "arch_node_") {
      sys.PlayUISound(NWSound.Select());
      this.Select(StringToInt(StrAfterLast(name, "_")));
    }
    if StrBeginsWith(name, "def_build_") {
      let parts = StrAfterFirst(name, "def_build_");
      let slot = StringToInt(StrLeft(parts, 1));
      let t = StringToInt(StrAfterLast(parts, "_"));
      let before = sys.GetEddies();
      this.status = sys.BuildDefense(this.selected, slot, t);
      sys.PlayUISound(sys.GetEddies() < before ? NWSound.Cash() : NWSound.HackFail());
    }
    if StrBeginsWith(name, "def_remove_") {
      this.status = sys.RemoveDefense(this.selected, StringToInt(StrAfterLast(name, "_")));
      sys.PlayUISound(NWSound.Click());
    }
    this.Refresh();
    return true;
  }
}
