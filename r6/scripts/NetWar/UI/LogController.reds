// NET War — aba REGISTROS: histórico completo do registro da rede, com rolagem.
// Só apresentação: lê o NetWarSystem. Visão dentro da mesma tela cheia do mapa.
// Roda do mouse: NetWarMapPopup.OnWheel (callback global 'OnPostOnRelative', como a galeria do jogo).
module NetWar.UI

import NetWar.*
import NetWar.Data.*

public class NWLogView extends IScriptable {
  private let sys: wref<NetWarSystem>;
  private let owner: wref<NetWarMapPopup>;
  private let root: wref<inkCanvas>;
  private let dynamic: wref<inkCanvas>;
  // Índice (0 = mais recente) da primeira linha visível.
  private let offset: Int32;

  public static func Create(sys: wref<NetWarSystem>, owner: wref<NetWarMapPopup>, parent: ref<inkCompoundWidget>) -> ref<NWLogView> {
    let view = new NWLogView();
    view.sys = sys;
    view.owner = owner;
    view.Build(parent);
    return view;
  }

  public func SetVisible(visible: Bool) -> Void {
    this.root.SetVisible(visible);
  }

  public func IsVisible() -> Bool {
    return this.root.IsVisible();
  }

  public func ScrollToTop() -> Void {
    this.offset = 0;
  }

  private func Rows() -> Int32 { return 19; }
  private func RowHeight() -> Float { return 32.0; }
  private func TrackY() -> Float { return 262.0; }
  private func TrackH() -> Float { return Cast<Float>(this.Rows()) * this.RowHeight(); }

  private func MaxOffset() -> Int32 {
    return Max(0, this.sys.GetLogCount() - this.Rows());
  }

  public func Scroll(lines: Int32) -> Void {
    this.offset = Clamp(this.offset + lines, 0, this.MaxOffset());
    this.Refresh();
  }

  // ------------------------------------------------------------------ montagem fixa

  private func Build(parent: ref<inkCompoundWidget>) -> Void {
    let r = NWInk.Canvas(parent, n"log_view", 0.0, 0.0, 1920.0, 1080.0);
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

    // Barra superior com as abas (REGISTROS ativa).
    NWInk.Rect(r, 0.0, 0.0, 1920.0, 96.0, NWTheme.Bg(), 0.92);
    NWInk.Rect(r, 0.0, 95.0, 1920.0, 1.0, NWTheme.Red(), 0.35);
    let title = NWInk.Text(r, 48.0, 14.0, NWL.T("NET::ACESSO", "NET::ACCESS"), 34, NWTheme.Red(), n"Semi-Bold");
    NWTheme.BindGameRed(title);
    NWInk.Text(r, 48.0, 56.0, NWL.T("TERMINAL DOMÉSTICO // REGISTROS", "HOME TERMINAL // LOGS"), 16, NWTheme.Muted(), n"Medium");
    this.Tab(r, n"tab_map", 400.0, NWL.T("MAPA DA REDE", "NETWORK MAP"), false);
    this.Tab(r, n"tab_arch", 628.0, NWL.T("ARQUITETURAS", "ARCHITECTURES"), false);
    this.Tab(r, n"tab_daemons", 846.0, "DAEMONS", false);
    this.Tab(r, n"", 1064.0, NWL.T("REGISTROS", "LOGS"), true);
    this.Tab(r, n"tab_help", 1282.0, "TUTORIAL", false);

    NWInk.Text(r, 48.0, 116.0, NWL.T("REGISTRO DA REDE", "NETWORK LOG"), 40, NWTheme.Cyan(), n"Semi-Bold");
    NWInk.Text(r, 48.0, 166.0, NWL.T("Tudo o que aconteceu na rede nesta sessão: invasões, ataques das facções, renda, bônus e a Netwatch.", "Everything that happened on the net this session: breaches, faction attacks, income, bonuses and Netwatch."), 18, NWTheme.Muted(), n"Medium");

    NWInk.Panel(r, 48.0, 206.0, 1824.0, 682.0, NWTheme.Red(), 0.3);

    this.Button(r, n"log_top", 1272.0, 214.0, 140.0, 36.0, NWL.T("RECENTES", "RECENT"));
    this.Button(r, n"log_up", 1420.0, 214.0, 140.0, 36.0, NWL.T("SUBIR", "UP"));
    this.Button(r, n"log_down", 1568.0, 214.0, 140.0, 36.0, NWL.T("DESCER", "DOWN"));
    this.Button(r, n"log_bottom", 1716.0, 214.0, 140.0, 36.0, NWL.T("ANTIGOS", "OLDEST"));

    NWInk.Panel(r, 48.0, 900.0, 1824.0, 120.0, NWTheme.Red(), 0.3);
    NWInk.Text(r, 72.0, 914.0, NWL.T("NAVEGAÇÃO", "NAVIGATION"), 16, NWTheme.Red(), n"Semi-Bold");
    NWInk.Text(r, 72.0, 942.0, NWL.T("Roda do mouse para rolar, botões para pular uma página, ou clique na barra à direita para ir direto a um ponto.", "Mouse wheel to scroll, buttons to jump a page, or click the bar on the right to go straight to a point."), 17, NWTheme.Text(), n"Medium");
    NWInk.Text(r, 72.0, 968.0, NWL.T("Os eventos mais recentes ficam no topo. O registro guarda os últimos 500 eventos e recomeça ao carregar um save.", "Newest events are at the top. The log keeps the last 500 events and starts over when a save is loaded."), 17, NWTheme.Muted(), n"Medium");

    this.dynamic = NWInk.Canvas(r, n"log_dynamic", 0.0, 0.0, 1920.0, 1080.0);
  }

  private func Tab(r: ref<inkCanvas>, name: CName, x: Float, label: String, active: Bool) -> Void {
    let w = x == 400.0 ? 220.0 : 210.0;
    if active {
      NWInk.Rect(r, x, 24.0, w, 48.0, NWTheme.Red(), 1.0);
      NWInk.Text(r, x + 24.0, 33.0, label, 22, NWTheme.Bg(), n"Semi-Bold");
    } else {
      NWInk.Frame(r, x, 24.0, w, 48.0, NWTheme.Red(), 0.45);
      NWInk.Text(r, x + 24.0, 33.0, label, 22, NWTheme.Text(), n"Semi-Bold");
    }
    if NotEquals(name, n"") {
      let hit = NWInk.HitArea(r, name, x, 24.0, w, 48.0);
      hit.RegisterToCallback(n"OnRelease", this, n"OnRelease");
    }
  }

  private func Button(parent: ref<inkCompoundWidget>, name: CName, x: Float, y: Float, w: Float, h: Float, label: String) -> Void {
    NWInk.Rect(parent, x, y, w, h, NWTheme.Cyan(), 0.12);
    NWInk.Frame(parent, x, y, w, h, NWTheme.Cyan(), 0.9);
    NWInk.Text(parent, x + 16.0, y + (h - 22.0) / 2.0, label, 18, NWTheme.Cyan(), n"Semi-Bold");
    let hit = NWInk.HitArea(parent, name, x, y, w, h);
    hit.RegisterToCallback(n"OnRelease", this, n"OnRelease");
  }

  // ------------------------------------------------------------------ atualização

  public func Refresh() -> Void {
    let sys = this.sys;
    if !IsDefined(sys) {
      return;
    }
    let d = this.dynamic;
    d.RemoveAllChildren();
    let total = sys.GetLogCount();
    this.offset = Clamp(this.offset, 0, this.MaxOffset());

    let last = Min(total, this.offset + this.Rows());
    let range = total == 0 ? NWL.T("NENHUM EVENTO", "NO EVENTS") : NWL.T(s"EVENTOS \(this.offset + 1) - \(last) DE \(total)", s"EVENTS \(this.offset + 1) - \(last) OF \(total)");
    NWInk.Text(d, 72.0, 220.0, range, 18, NWTheme.Cyan(), n"Semi-Bold");

    let row = 0;
    while row < this.Rows() {
      let k = this.offset + row;
      if k >= total {
        break;
      }
      let y = this.TrackY() + Cast<Float>(row) * this.RowHeight();
      if row % 2 == 0 {
        NWInk.Rect(d, 64.0, y, 1756.0, this.RowHeight(), NWTheme.Text(), 0.03);
      }
      NWInk.Text(d, 76.0, y + 5.0, s"#\(total - k)", 15, NWTheme.Muted(), n"Medium");
      NWInk.Text(d, 150.0, y + 4.0, sys.GetLogLine(k), 18, this.LineColor(sys.GetLogLine(k)), n"Medium");
      row += 1;
    }

    this.DrawScrollBar(d, total);
  }

  private func DrawScrollBar(d: ref<inkCanvas>, total: Int32) -> Void {
    let x = 1836.0;
    let y = this.TrackY();
    let h = this.TrackH();
    NWInk.Rect(d, x, y, 12.0, h, NWTheme.Red(), 0.12);
    if total > this.Rows() {
      let thumbH = MaxF(32.0, h * Cast<Float>(this.Rows()) / Cast<Float>(total));
      let thumbY = y + (h - thumbH) * Cast<Float>(this.offset) / Cast<Float>(this.MaxOffset());
      NWInk.Rect(d, x, thumbY, 12.0, thumbH, NWTheme.Cyan(), 0.9);
    } else {
      NWInk.Rect(d, x, y, 12.0, h, NWTheme.Cyan(), 0.25);
    }
    // Trilho clicável em 20 faixas: clicar pula para aquele ponto do histórico.
    let k = 0;
    while k < 20 {
      let hit = NWInk.HitArea(d, StringToName(s"log_jump_\(k)"), x - 8.0, y + h * Cast<Float>(k) / 20.0, 28.0, h / 20.0);
      hit.RegisterToCallback(n"OnRelease", this, n"OnRelease");
      k += 1;
    }
  }

  // Cor pela natureza do evento (texto do registro em pt-BR).
  private func LineColor(line: String) -> HDRColor {
    // Palavras dos dois idiomas: o registro guarda o texto no idioma em que o evento aconteceu.
    if StrContains(line, "Netwatch") || StrContains(line, "NETWATCH") || StrContains(line, "BLACKWALL") || StrContains(line, "expulso") || StrContains(line, "kicked") {
      return NWTheme.Crimson();
    }
    if StrContains(line, "atacou") || StrContains(line, "destruiu") || StrContains(line, "tomou") || StrContains(line, "perdeu")
      || StrContains(line, "attacked") || StrContains(line, "destroyed") || StrContains(line, " took ") || StrContains(line, " lost") {
      return NWTheme.Red();
    }
    if StrContains(line, "Bônus") || StrContains(line, "Bonus") || StrContains(line, "€$") || StrContains(line, "Daemon") {
      return NWTheme.Yellow();
    }
    if StrContains(line, "V ") || StrContains(line, "Isca") || StrContains(line, "Decoy") || StrContains(line, "resistiu") || StrContains(line, "held") {
      return NWTheme.Cyan();
    }
    return NWTheme.Text();
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
    if Equals(name, "tab_arch") {
      sys.PlayUISound(NWSound.Select());
      this.owner.ShowArchitectures(-1);
      return true;
    }
    if Equals(name, "tab_daemons") {
      sys.PlayUISound(NWSound.Select());
      this.owner.ShowDaemons();
      return true;
    }
    sys.PlayUISound(NWSound.Click());
    if Equals(name, "log_top") { this.offset = 0; }
    if Equals(name, "log_bottom") { this.offset = this.MaxOffset(); }
    if Equals(name, "log_up") { this.offset -= this.Rows() - 1; }
    if Equals(name, "log_down") { this.offset += this.Rows() - 1; }
    if StrBeginsWith(name, "log_jump_") {
      let k = StringToInt(StrAfterLast(name, "_"));
      this.offset = (this.MaxOffset() * k + 10) / 19;
    }
    this.Refresh();
    return true;
  }
}
