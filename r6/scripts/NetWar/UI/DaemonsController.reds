// NET War — aba DAEMONS: slots equipados e inventário (fase 6, passo 2).
// Só apresentação: lê o NetWarSystem e envia ações. Visão dentro da mesma tela cheia do mapa.
module NetWar.UI

import NetWar.*
import NetWar.Data.*

public class NWDaemonsView extends IScriptable {
  private let sys: wref<NetWarSystem>;
  private let owner: wref<NetWarMapPopup>;
  private let root: wref<inkCanvas>;
  private let dynamic: wref<inkCanvas>;
  private let status: String;

  public static func Create(sys: wref<NetWarSystem>, owner: wref<NetWarMapPopup>, parent: ref<inkCompoundWidget>) -> ref<NWDaemonsView> {
    let view = new NWDaemonsView();
    view.sys = sys;
    view.owner = owner;
    view.Build(parent);
    return view;
  }

  public func SetVisible(visible: Bool) -> Void {
    this.root.SetVisible(visible);
  }

  // ------------------------------------------------------------------ montagem fixa

  private func Build(parent: ref<inkCompoundWidget>) -> Void {
    let r = NWInk.Canvas(parent, n"daemons_view", 0.0, 0.0, 1920.0, 1080.0);
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

    // Barra superior com as abas (DAEMONS ativa).
    NWInk.Rect(r, 0.0, 0.0, 1920.0, 96.0, NWTheme.Bg(), 0.92);
    NWInk.Rect(r, 0.0, 95.0, 1920.0, 1.0, NWTheme.Red(), 0.35);
    let title = NWInk.Text(r, 48.0, 14.0, NWL.T("NET::ACESSO", "NET::ACCESS"), 34, NWTheme.Red(), n"Semi-Bold");
    NWTheme.BindGameRed(title);
    NWInk.Text(r, 48.0, 56.0, NWL.T("TERMINAL DOMÉSTICO // DAEMONS", "HOME TERMINAL // DAEMONS"), 16, NWTheme.Muted(), n"Medium");
    this.Tab(r, n"tab_map", 400.0, NWL.T("MAPA DA REDE", "NETWORK MAP"), false);
    this.Tab(r, n"tab_arch", 628.0, NWL.T("ARQUITETURAS", "ARCHITECTURES"), false);
    this.Tab(r, n"", 846.0, "DAEMONS", true);
    this.Tab(r, n"tab_logs", 1064.0, NWL.T("REGISTROS", "LOGS"), false);
    this.Tab(r, n"tab_help", 1282.0, "TUTORIAL", false);

    NWInk.Text(r, 48.0, 116.0, "DAEMONS", 40, NWTheme.Cyan(), n"Semi-Bold");
    NWInk.Text(r, 48.0, 166.0, NWL.T("Programas encontrados em caches de daemon e ao dominar nós. Equipe nos slots para usar no jack-in.", "Programs found in daemon caches and by taking nodes. Equip them in slots to use during a jack-in."), 18, NWTheme.Muted(), n"Medium");

    NWInk.Panel(r, 48.0, 900.0, 1824.0, 120.0, NWTheme.Red(), 0.3);
    NWInk.Text(r, 72.0, 914.0, NWL.T("REGRAS", "RULES"), 16, NWTheme.Red(), n"Semi-Bold");
    NWInk.Text(r, 72.0, 942.0, NWL.T("O efeito é o mesmo em toda raridade; a raridade só reduz o custo de RAM (comum +3, raro +2, épico +1, lendário = tabela).", "The effect is the same at every rarity; rarity only lowers the RAM cost (common +3, rare +2, epic +1, legendary = base)."), 17, NWTheme.Text(), n"Medium");
    NWInk.Text(r, 72.0, 968.0, NWL.T("2 cópias repetidas sobem uma raridade. Num lendário, cada cópia vira €$ 1.000 no Banco NetWatch. Ser expulso da rede perde os daemons da sessão.", "2 duplicate copies raise the rarity by one. On a legendary, each copy becomes €$ 1,000 in the NetWatch Bank. Getting kicked out loses the session's daemons."), 17, NWTheme.Text(), n"Medium");
    NWInk.Text(r, 72.0, 994.0, NWL.T("O Fragmento de IA é um drop raro (8%) que só aparece em zonas Blackwall. Mais slots: domine a Cidade do México.", "The AI Fragment is a rare drop (8%) found only in Blackwall zones. More slots: take Mexico City."), 17, NWTheme.Muted(), n"Medium");

    this.dynamic = NWInk.Canvas(r, n"daemons_dynamic", 0.0, 0.0, 1920.0, 1080.0);
  }

  private func Tab(r: ref<inkCanvas>, name: CName, x: Float, label: String, active: Bool) -> Void {
    let w = x == 400.0 ? 220.0 : 210.0;
    if active {
      NWInk.Rect(r, x, 24.0, w, 48.0, NWTheme.Red(), 1.0);
      NWInk.Text(r, x + 24.0, 33.0, label, 22, NWTheme.Bg(), n"Semi-Bold");
    } else {
      NWInk.Frame(r, x, 24.0, w, 48.0, NWTheme.Red(), 0.45);
      NWInk.Text(r, x + 24.0, 33.0, label, 22, NWTheme.Muted(), n"Semi-Bold");
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
    this.DrawSlots(d);
    this.DrawInventory(d);
    if StrLen(this.status) > 0 {
      NWInk.Text(d, 1300.0, 214.0, this.status, 18, NWTheme.Yellow(), n"Semi-Bold");
    }
  }

  private func DrawSlots(d: ref<inkCanvas>) -> Void {
    let sys = this.sys;
    let slots = sys.GetDaemonSlots();
    NWInk.Text(d, 48.0, 214.0, NWL.T(s"SLOTS EQUIPADOS · \(sys.GetEquippedCount()) / \(slots)", s"EQUIPPED SLOTS · \(sys.GetEquippedCount()) / \(slots)"), 18, NWTheme.Cyan(), n"Semi-Bold");
    let k = 0;
    while k < slots {
      let x = 48.0 + Cast<Float>(k) * 296.0;
      let y = 246.0;
      let id = sys.GetEquippedId(k);
      if id >= 0 {
        let color = NWTheme.Rarity(sys.GetDaemonRarity(id));
        NWInk.Rect(d, x, y, 280.0, 120.0, color, 0.10);
        NWInk.Frame(d, x, y, 280.0, 120.0, color, 1.0);
        NWInk.Text(d, x + 16.0, y + 10.0, NWText.Upper(sys.GetDaemonName(id)), 22, color, n"Semi-Bold");
        NWInk.Text(d, x + 16.0, y + 40.0, s"\(sys.GetDaemonRarityName(id)) · RAM \(sys.GetDaemonRamCost(id))", 16, NWTheme.Text(), n"Medium");
        this.Button(d, StringToName(s"dmn_unequip_\(id)"), x + 16.0, y + 72.0, 140.0, 34.0, NWL.T("REMOVER", "REMOVE"), NWTheme.Red());
      } else {
        NWInk.Frame(d, x, y, 280.0, 120.0, NWTheme.Muted(), 0.35);
        NWInk.Text(d, x + 16.0, y + 44.0, NWL.T("SLOT VAZIO", "EMPTY SLOT"), 20, NWTheme.Muted(), n"Semi-Bold");
      }
      k += 1;
    }
  }

  private func DrawInventory(d: ref<inkCanvas>) -> Void {
    let sys = this.sys;
    NWInk.Text(d, 48.0, 392.0, NWL.T("INVENTÁRIO", "INVENTORY"), 18, NWTheme.Cyan(), n"Semi-Bold");
    let id = 0;
    while id < sys.GetDaemonCount() {
      let col = id % 4;
      let row = id / 4;
      let x = 48.0 + Cast<Float>(col) * 456.0;
      let y = 424.0 + Cast<Float>(row) * 232.0;
      let rarity = sys.GetDaemonRarity(id);
      if rarity < 0 {
        NWInk.Panel(d, x, y, 440.0, 216.0, NWTheme.Muted(), 0.3);
        NWInk.Text(d, x + 20.0, y + 16.0, "???", 28, NWTheme.Muted(), n"Semi-Bold");
        NWInk.Text(d, x + 20.0, y + 56.0, NWL.T("Não encontrado", "Not found"), 18, NWTheme.Muted(), n"Medium");
        if sys.IsDaemonBlackwallOnly(id) {
          NWInk.Text(d, x + 20.0, y + 86.0, NWL.T("Drop raro, só em zonas Blackwall", "Rare drop, Blackwall zones only"), 16, NWTheme.Crimson(), n"Medium");
        }
      } else {
        let color = NWTheme.Rarity(rarity);
        NWInk.Panel(d, x, y, 440.0, 216.0, color, 0.8);
        NWInk.Text(d, x + 20.0, y + 14.0, NWText.Upper(sys.GetDaemonName(id)), 26, color, n"Semi-Bold");
        NWInk.Text(d, x + 20.0, y + 50.0, NWText.Upper(sys.GetDaemonRarityName(id)), 16, color, n"Medium");
        NWInk.Text(d, x + 200.0, y + 50.0, NWL.T(s"RAM \(sys.GetDaemonRamCost(id))  (lendário \(sys.GetDaemonBaseRam(id)))", s"RAM \(sys.GetDaemonRamCost(id))  (legendary \(sys.GetDaemonBaseRam(id)))"), 16, NWTheme.Yellow(), n"Medium");
        this.Wrapped(d, x + 20.0, y + 80.0, sys.GetDaemonDescription(id), 44, 17, NWTheme.Text());
        let fusion = rarity >= 3 ? NWL.T("Máximo: cópias viram €$ 1.000", "Max: copies become €$ 1,000") : NWL.T(s"Cópias para fundir: \(sys.GetDaemonCopies(id)) / 2", s"Copies to fuse: \(sys.GetDaemonCopies(id)) / 2");
        NWInk.Text(d, x + 20.0, y + 130.0, fusion, 15, NWTheme.Muted(), n"Medium");
        if sys.IsDaemonEquipped(id) {
          this.Button(d, StringToName(s"dmn_unequip_\(id)"), x + 20.0, y + 162.0, 180.0, 36.0, NWL.T("REMOVER", "REMOVE"), NWTheme.Red());
          NWInk.Text(d, x + 216.0, y + 168.0, NWL.T("EQUIPADO", "EQUIPPED"), 18, NWTheme.Cyan(), n"Semi-Bold");
        } else {
          this.Button(d, StringToName(s"dmn_equip_\(id)"), x + 20.0, y + 162.0, 180.0, 36.0, NWL.T("EQUIPAR", "EQUIP"), NWTheme.Cyan());
        }
      }
      id += 1;
    }
  }

  private func Wrapped(parent: ref<inkCompoundWidget>, x: Float, y: Float, text: String, maxChars: Int32, size: Int32, color: HDRColor) -> Void {
    let rest = text;
    let line = 0;
    while StrLen(rest) > 0 && line < 2 {
      let piece = rest;
      if StrLen(rest) > maxChars {
        let cut = maxChars;
        while cut > 8 && !Equals(StrMid(rest, cut, 1), " ") {
          cut -= 1;
        }
        piece = StrLeft(rest, cut);
        rest = StrMid(rest, cut + 1, StrLen(rest) - cut - 1);
      } else {
        rest = "";
      }
      NWInk.Text(parent, x, y + Cast<Float>(line) * Cast<Float>(size + 4), piece, size, color, n"Medium");
      line += 1;
    }
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
    let name = NameToString(evt.GetTarget().GetName());
    if Equals(name, "tab_help") {
      this.sys.PlayUISound(NWSound.Select());
      this.owner.ShowTutorial();
      return true;
    }
    if Equals(name, "tab_map") {
      this.sys.PlayUISound(NWSound.Select());
      this.owner.ShowMap();
      return true;
    }
    if Equals(name, "tab_logs") {
      this.sys.PlayUISound(NWSound.Select());
      this.owner.ShowLogs();
      return true;
    }
    if Equals(name, "tab_arch") {
      this.sys.PlayUISound(NWSound.Select());
      this.owner.ShowArchitectures(-1);
      return true;
    }
    if StrBeginsWith(name, "dmn_equip_") {
      this.status = this.sys.EquipDaemon(StringToInt(StrAfterLast(name, "_")));
      this.sys.PlayUISound(NWSound.Click());
    }
    if StrBeginsWith(name, "dmn_unequip_") {
      this.status = this.sys.UnequipDaemon(StringToInt(StrAfterLast(name, "_")));
      this.sys.PlayUISound(NWSound.Click());
    }
    this.Refresh();
    return true;
  }
}
