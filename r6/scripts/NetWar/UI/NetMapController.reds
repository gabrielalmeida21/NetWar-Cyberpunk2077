// NET War — tela cheia do mapa da rede (fase 4).
// Popup do Codeware (InGamePopup): desacelera o tempo, libera o mouse, desfoca o fundo e
// fecha com ESC ("cancel"). Layout 1920×1080 do mockup "NET War — Mapa Mundi".
// Só apresentação: lê o NetWarSystem e envia ações; nenhuma regra de jogo aqui.
module NetWar.UI

import NetWar.*
import NetWar.Data.*
import Codeware.UI.*

public class NetWarMapPopup extends InGamePopup {
  private let sys: wref<NetWarSystem>;
  private let selected: Int32;
  // Sub-nó selecionado (região ou local; −1 = o nó do mundo em "selected").
  private let selectedSub: Int32;
  private let status: String;

  private let screen: wref<inkCanvas>;
  private let mapView: wref<inkCanvas>;
  private let breachView: ref<NWBreachView>;
  private let daemonsView: ref<NWDaemonsView>;
  private let archView: ref<NWArchView>;
  private let logView: ref<NWLogView>;
  private let tutorialView: ref<NWTutorialView>;
  // Zoom do mapa: 0 MUNDO, 1 REGIÃO, 2 CIDADE (centrado no nó selecionado).
  private let zoom: Int32;
  private let viewCx: Float;
  private let viewCy: Float;
  private let mapBg: wref<inkCanvas>;
  private let edgeLayer: wref<inkCanvas>;
  private let overlayLayer: wref<inkCanvas>;
  private let zoomTabs: wref<inkCanvas>;
  private let wheelHooked: Bool;
  // ESPAÇO como tecla física (CallbackSystem do Codeware) e momento do último uso (anti-duplo).
  private let spaceHandler: ref<CallbackSystemHandler>;
  private let lastSpaceAt: Float;
  private let mapLayer: wref<inkCanvas>;
  private let nodeLayer: wref<inkCanvas>;

  private let clockText: wref<inkText>;
  private let interfaceText: wref<inkText>;
  private let ramText: wref<inkText>;
  private let ramBar: array<wref<inkRectangle>>;
  private let traceText: wref<inkText>;
  private let traceBar: wref<inkRectangle>;
  private let territoryText: wref<inkText>;
  private let eddiesText: wref<inkText>;
  private let walletText: wref<inkText>;
  private let bankStatusText: wref<inkText>;

  private let targetFrame: wref<inkCanvas>;
  private let coordsText: wref<inkText>;
  private let logLines: array<wref<inkText>>;

  // Modo menu (padrão): a tela vive na camada de menus, dentro do cenário de menu do jogo.
  private let menuMode: Bool;
  private let menuHost: wref<inkCompoundWidget>;

  public static func CreateInMenu(gi: GameInstance, holder: ref<inkCanvas>, controller: ref<inkGameController>) -> ref<NetWarMapPopup> {
    let screen = new NetWarMapPopup();
    screen.sys = NetWarSystem.GetInstance(gi);
    screen.selected = 0;
    screen.menuMode = true;
    screen.menuHost = holder;
    screen.Mount(holder, controller);
    return screen;
  }

  public static func Show(gi: GameInstance) -> Void {
    let popup = new NetWarMapPopup();
    popup.sys = NetWarSystem.GetInstance(gi);
    popup.selected = 0;
    GameInstance.GetUISystem(gi).QueueEvent(ShowCustomPopupEvent.Create(popup));
  }

  public func UseCursor() -> Bool {
    return true;
  }

  // Solta o callback global da roda (o controlador da camada continua vivo depois da tela).
  public func Detach() -> Void {
    this.sys.AbortMiniGame();
    if this.wheelHooked {
      this.UnregisterFromGlobalInputCallback(n"OnPostOnRelative", this, n"OnWheel");
      this.UnregisterFromGlobalInputCallback(n"OnPostOnPress", this, n"OnKeyPress");
      if IsDefined(this.spaceHandler) {
        this.spaceHandler.Unregister();
        this.spaceHandler = null;
      }
      this.wheelHooked = false;
    }
  }

  // ESPAÇO ataca no Zap e avança no Slide. Nos arquivos de entrada do jogo, IK_Space liga a UI_Skip (contexto UI)
  // e a track / engagement_screen (UIMenu); aceita as três. Outra tecla vai para o log, para conferir.
  protected cb func OnKeyPress(evt: ref<inkPointerEvent>) -> Bool {
    let kind = this.sys.GetMiniKind();
    if (kind != 3 && kind != 4 && kind != 7) || !(this.breachView.IsShown() || this.tutorialView.IsShown()) {
      return false;
    }
    if evt.IsAction(n"UI_Skip") || evt.IsAction(n"track") || evt.IsAction(n"engagement_screen") {
      this.UseSpace();
      return true;
    }
    if !evt.IsAction(n"click") {
      NWLog("Zap: tecla sem ação reconhecida (" + evt.GetDebugString() + ")");
    }
    return false;
  }

  protected cb func OnRawKey(evt: ref<KeyInputEvent>) -> Bool {
    this.UseSpace();
    return true;
  }

  // Ataca (Zap) ou avança (Slide). As duas vias podem disparar na mesma tecla: ignora a 2ª.
  private func UseSpace() -> Void {
    let kind = this.sys.GetMiniKind();
    if (kind != 3 && kind != 4 && kind != 7) || !(this.breachView.IsShown() || this.tutorialView.IsShown()) {
      return;
    }
    let now = EngineTime.ToFloat(GameInstance.GetEngineTime(GetGameInstance()));
    if now - this.lastSpaceAt < 0.15 {
      return;
    }
    this.lastSpaceAt = now;
    let action = kind == 3 ? "mg_zap" : (kind == 4 ? "mg_adv" : "mg_ping");
    if this.breachView.IsShown() {
      this.breachView.HandleClick(action);
    } else {
      this.tutorialView.HandleMini(action);
    }
  }

  protected cb func OnWheel(evt: ref<inkPointerEvent>) -> Bool {
    if !evt.IsAction(n"mouse_wheel") {
      return false;
    }
    let steps = RoundF(evt.GetAxisData());
    if steps == 0 {
      return false;
    }
    if this.logView.IsVisible() {
      this.logView.Scroll(-steps * 3);
      return true;
    }
    if this.mapView.IsVisible() {
      this.SetZoom(this.zoom + (steps > 0 ? 1 : -1));
      return true;
    }
    return false;
  }

  protected cb func OnHidden() {
    this.Detach();
    this.sys.StopHackMusic();
    let parent = this.screen.GetParentWidget() as inkCompoundWidget;
    if IsDefined(parent) {
      parent.RemoveChild(this.screen);
    }
    super.OnHidden();
  }

  // Não chama o OnCreate do InGamePopup: a tela monta o próprio fundo em vez da vinheta.
  protected cb func OnCreate() {
    let root = new inkCanvas();
    root.SetName(n"netwar_map");
    root.SetAnchor(inkEAnchor.Centered);
    root.SetAnchorPoint(Vector2(0.5, 0.5));
    root.SetSize(Vector2(1920.0, 1080.0));
    this.screen = root;
    this.selectedSub = -1;
    this.MountScreen();
    this.mapView = NWInk.Canvas(root, n"map_view", 0.0, 0.0, 1920.0, 1080.0);
    this.BuildStatic();
    this.breachView = NWBreachView.Create(this.sys, this, root);
    this.daemonsView = NWDaemonsView.Create(this.sys, this, root);
    this.archView = NWArchView.Create(this.sys, this, root);
    this.logView = NWLogView.Create(this.sys, this, root);
    this.tutorialView = NWTutorialView.Create(this.sys, this, root);
    // Roda do mouse (mesmo callback global da galeria do jogo, gallery.script).
    this.RegisterToGlobalInputCallback(n"OnPostOnRelative", this, n"OnWheel");
    // Teclas (ESPAÇO no Zap), como o frameSwitcher do jogo.
    this.RegisterToGlobalInputCallback(n"OnPostOnPress", this, n"OnKeyPress");
    // E a tecla física, que não depende do contexto de entrada do menu.
    this.spaceHandler = GameInstance.GetCallbackSystem().RegisterCallback(n"Input/Key", this, n"OnRawKey")
      .AddTarget(InputTarget.Key(EInputKey.IK_Space, EInputAction.IACT_Press));
    this.wheelHooked = true;
    if this.sys.IsBreachActive() {
      this.ShowBreach();
    } else {
      this.ShowMap();
    }
  }

  // Modo menu (padrão): janela virtual da camada de menus, 1920×1080, plana, recebe o mouse.
  // Modo popup (reserva): raiz do PopupsManager, curva; escala 0.95 para a curvatura não cortar.
  private func MountScreen() -> Void {
    this.screen.SetAnchor(inkEAnchor.Centered);
    this.screen.SetAnchorPoint(Vector2(0.5, 0.5));
    if this.menuMode {
      this.screen.SetScale(Vector2(1.0, 1.0));
      this.screen.Reparent(this.menuHost);
      this.sys.SetUiDebug("modo menu · inkMenuLayer · escala 1");
      return;
    }
    let host = this.GetGameController().GetRootCompoundWidget();
    if !IsDefined(host) {
      host = this.GetRootCompoundWidget();
    }
    this.screen.SetScale(Vector2(0.95, 0.95));
    this.screen.Reparent(host);
    this.sys.SetUiDebug("modo popup · raiz do PopupsManager · escala 0.95");
  }

  // ------------------------------------------------------------------ montagem fixa

  // Duas visões na mesma tela: mapa e invasão (a fila de popups do Codeware aceita um por vez).
  private func HideAll() -> Void {
    // Sair da invasão com o minigame aberto conta como falha (o cronômetro não pode pausar).
    this.sys.AbortMiniGame();
    this.mapView.SetVisible(false);
    this.breachView.SetVisible(false);
    this.daemonsView.SetVisible(false);
    this.archView.SetVisible(false);
    this.logView.SetVisible(false);
    this.tutorialView.SetVisible(false);
  }

  public func ShowTutorial() -> Void {
    this.HideAll();
    this.tutorialView.SetVisible(true);
    this.tutorialView.Refresh();
  }

  public func ShowLogs() -> Void {
    this.HideAll();
    this.logView.ScrollToTop();
    this.logView.SetVisible(true);
    this.logView.Refresh();
  }

  public func ShowMap() -> Void {
    this.sys.StopHackMusic();
    this.HideAll();
    this.mapView.SetVisible(true);
    this.status = "";
    this.Refresh();
  }

  public func ShowMapAt(i: Int32) -> Void {
    this.selected = i;
    this.selectedSub = -1;
    this.ShowMap();
  }

  public func ShowArchitectures(i: Int32) -> Void {
    this.HideAll();
    this.archView.Select(i >= 0 ? i : this.selected);
    this.archView.SetVisible(true);
    this.archView.Refresh();
  }

  public func ShowDaemons() -> Void {
    this.HideAll();
    this.daemonsView.SetVisible(true);
    this.daemonsView.Refresh();
  }

  public func ShowBreach() -> Void {
    this.HideAll();
    if this.sys.IsBreachActive() {
      this.sys.StartHackMusic();
    }
    this.breachView.SetVisible(true);
    this.breachView.Refresh();
  }

  private func BuildStatic() -> Void {
    let s = this.mapView;
    NWInk.Rect(s, 0.0, 0.0, 1920.0, 1080.0, NWTheme.Bg(), 0.96);
    // Grade de fundo sutil (48 px).
    let gx = 0.0;
    while gx < 1920.0 {
      NWInk.Rect(s, gx, 0.0, 1.0, 1080.0, NWTheme.Red(), 0.045);
      gx += 48.0;
    }
    let gy = 0.0;
    while gy < 1080.0 {
      NWInk.Rect(s, 0.0, gy, 1920.0, 1.0, NWTheme.Red(), 0.045);
      gy += 48.0;
    }

    this.BuildTopBar(s);
    this.BuildNetrunnerPanel(s);
    this.BuildBankPanel(s);
    this.BuildLegend(s);
    this.BuildMap(s);
    this.BuildBelowMap(s);
    this.BuildLog(s);
    this.BuildKeyHints(s);

    let target = NWInk.Canvas(s, n"target", 1572.0, 136.0, 300.0, 600.0);
    this.targetFrame = target;
  }

  private func BuildTopBar(s: ref<inkCanvas>) -> Void {
    NWInk.Rect(s, 0.0, 0.0, 1920.0, 96.0, NWTheme.Bg(), 0.92);
    NWInk.Rect(s, 0.0, 95.0, 1920.0, 1.0, NWTheme.Red(), 0.35);
    let title = NWInk.Text(s, 48.0, 14.0, NWL.T("NET::ACESSO", "NET::ACCESS"), 34, NWTheme.Red(), n"Semi-Bold");
    NWTheme.BindGameRed(title);
    NWInk.Text(s, 48.0, 56.0, NWL.T("TERMINAL DOMÉSTICO // PONTO DE ACESSO", "HOME TERMINAL // ACCESS POINT"), 16, NWTheme.Muted(), n"Medium");

    NWInk.Rect(s, 400.0, 24.0, 220.0, 48.0, NWTheme.Red(), 1.0);
    NWInk.Text(s, 424.0, 33.0, NWL.T("MAPA DA REDE", "NETWORK MAP"), 22, NWTheme.Bg(), n"Semi-Bold");
    let tabs: array<String> = [NWL.T("ARQUITETURAS", "ARCHITECTURES"), "DAEMONS", NWL.T("REGISTROS", "LOGS"), "TUTORIAL"];
    let x = 628.0;
    for tab in tabs {
      NWInk.Frame(s, x, 24.0, 210.0, 48.0, NWTheme.Red(), 0.45);
      NWInk.Text(s, x + 24.0, 33.0, tab, 22, NWTheme.Text(), n"Semi-Bold");
      let tabName = n"tab_logs";
      if Equals(tab, "DAEMONS") { tabName = n"tab_daemons"; }
      if Equals(tab, NWL.T("ARQUITETURAS", "ARCHITECTURES")) { tabName = n"tab_arch"; }
      if Equals(tab, "TUTORIAL") { tabName = n"tab_help"; }
      let hit = NWInk.HitArea(s, tabName, x, 24.0, 210.0, 48.0);
      hit.RegisterToCallback(n"OnRelease", this, n"OnButtonRelease");
      x += 218.0;
    }

    NWInk.Rect(s, 1560.0, 28.0, 10.0, 10.0, NWTheme.Cyan(), 1.0);
    NWInk.Text(s, 1578.0, 20.0, NWL.T("CONEXÃO ESTÁVEL", "STABLE CONNECTION"), 18, NWTheme.Cyan(), n"Medium");
    this.clockText = NWInk.Text(s, 1560.0, 50.0, "", 18, NWTheme.Muted(), n"Medium");
  }

  private func BuildNetrunnerPanel(s: ref<inkCanvas>) -> Void {
    NWInk.Panel(s, 48.0, 136.0, 280.0, 270.0, NWTheme.Red(), 0.4);
    NWInk.Text(s, 68.0, 150.0, "NETRUNNER", 16, NWTheme.Red(), n"Semi-Bold");
    NWInk.Text(s, 68.0, 172.0, "V", 40, NWTheme.Text(), n"Semi-Bold");

    NWInk.Text(s, 68.0, 228.0, "INTERFACE", 17, NWTheme.Muted(), n"Medium");
    this.interfaceText = NWInk.Text(s, 280.0, 224.0, "", 24, NWTheme.Yellow(), n"Semi-Bold");

    NWInk.Text(s, 68.0, 264.0, NWL.T("RAM DO DECK", "DECK RAM"), 17, NWTheme.Muted(), n"Medium");
    this.ramText = NWInk.Text(s, 250.0, 262.0, "", 18, NWTheme.Text(), n"Medium");
    let k = 0;
    while k < 16 {
      let cell = NWInk.Rect(s, 68.0 + Cast<Float>(k) * 15.0, 292.0, 12.0, 10.0, NWTheme.Cyan(), 1.0);
      ArrayPush(this.ramBar, cell);
      k += 1;
    }

    NWInk.Text(s, 68.0, 318.0, NWL.T("RASTREIO NETWATCH", "NETWATCH TRACE"), 17, NWTheme.Muted(), n"Medium");
    this.traceText = NWInk.Text(s, 270.0, 316.0, "", 18, NWTheme.Red(), n"Medium");
    NWInk.Rect(s, 68.0, 346.0, 240.0, 6.0, HDRColor(0.165, 0.078, 0.086, 1.0), 1.0);
    this.traceBar = NWInk.Rect(s, 68.0, 346.0, 0.0, 6.0, NWTheme.Red(), 1.0);

    NWInk.Text(s, 68.0, 372.0, NWL.T("TERRITÓRIOS", "TERRITORIES"), 17, NWTheme.Muted(), n"Medium");
    this.territoryText = NWInk.Text(s, 250.0, 368.0, "", 24, NWTheme.Cyan(), n"Semi-Bold");

  }

  // Banco NetWatch: saldo da rede + saque/depósito com o dinheiro real do V.
  private func BuildBankPanel(s: ref<inkCanvas>) -> Void {
    NWInk.Panel(s, 48.0, 420.0, 280.0, 236.0, NWTheme.Yellow(), 0.35);
    NWInk.Text(s, 68.0, 432.0, NWL.T("BANCO NETWATCH", "NETWATCH BANK"), 16, NWTheme.Yellow(), n"Semi-Bold");
    this.eddiesText = NWInk.Text(s, 68.0, 454.0, "", 30, NWTheme.Yellow(), n"Semi-Bold");
    this.walletText = NWInk.Text(s, 68.0, 494.0, "", 16, NWTheme.Muted(), n"Medium");
    this.SmallButton(s, n"bank_w5k", 68.0, 524.0, 116.0, 36.0, NWL.T("SACAR 5K", "WITHDRAW 5K"), NWTheme.Yellow());
    this.SmallButton(s, n"bank_wall", 192.0, 524.0, 116.0, 36.0, NWL.T("SACAR TUDO", "WITHDRAW ALL"), NWTheme.Yellow());
    this.SmallButton(s, n"bank_d5k", 68.0, 568.0, 116.0, 36.0, NWL.T("DEP. 5K", "DEP. 5K"), NWTheme.Cyan());
    this.SmallButton(s, n"bank_dall", 192.0, 568.0, 116.0, 36.0, NWL.T("DEP. TUDO", "DEP. ALL"), NWTheme.Cyan());
    this.bankStatusText = NWInk.Text(s, 68.0, 616.0, "", 14, NWTheme.Yellow(), n"Medium");
  }

  private func BuildLegend(s: ref<inkCanvas>) -> Void {
    NWInk.Panel(s, 48.0, 672.0, 280.0, 284.0, NWTheme.Red(), 0.25);
    NWInk.Text(s, 68.0, 684.0, NWL.T("CONTROLE DA REDE", "NETWORK CONTROL"), 16, NWTheme.Red(), n"Semi-Bold");
    let names: array<String> = [NWL.T("Seu território", "Your territory"), "Arasaka", "Militech", "Netwatch", "Kang Tao", "Voodoo Boys", NWL.T("Neutro / contestado", "Neutral / contested"), NWL.T("Zona Blackwall", "Blackwall zone")];
    let factions: array<Int32> = [0, 1, 2, 3, 4, 5, 6, 7];
    let k = 0;
    while k < ArraySize(names) {
      let y = 712.0 + Cast<Float>(k) * 29.0;
      this.DrawMarker(s, 76.0, y + 11.0, factions[k], false);
      let color = factions[k] == 7 ? NWTheme.Crimson() : NWTheme.Text();
      NWInk.Text(s, 98.0, y, names[k], 18, color, n"Medium");
      k += 1;
    }
  }

  private func BuildMap(s: ref<inkCanvas>) -> Void {
    // inkScrollArea com máscara interna recorta o fundo ampliado na moldura do mapa.
    let clip = new inkScrollArea();
    clip.SetName(n"map");
    clip.constrainContentPosition = false;
    clip.SetUseInternalMask(true);
    NWInk.Place(clip, s, 360.0, 196.0, 1200.0, 496.0);
    let content = NWInk.Canvas(clip, n"map_content", 0.0, 0.0, 1200.0, 496.0);
    this.mapLayer = content;
    let map = NWInk.Canvas(content, n"map_bg", 0.0, 0.0, 1200.0, 496.0);
    map.SetRenderTransformPivot(Vector2(0.0, 0.0));
    this.mapBg = map;

    // Continentes: textura de pontos (NetWar.archive, gerada por tools/gen-map + tools/build-archive.ps1)
    // numa única imagem. Sem o archive instalado, cai na grade grossa de widgets.
    if GameInstance.GetResourceDepot().ResourceExists(r"netwar\\ui\\netwar_map.inkatlas") {
      let img = new inkImage();
      img.SetName(n"world_dots");
      img.SetAtlasResource(r"netwar\\ui\\netwar_map.inkatlas");
      img.SetTexturePart(n"map");
      NWInk.Place(img, map, 0.0, 0.0, 1200.0, 496.0);
      img.SetTintColor(NWTheme.Text());
      img.SetOpacity(0.32);
    } else {
      let pts = NWMapDots.Points();
      let k = 0;
      while k + 1 < ArraySize(pts) {
        NWInk.Rect(map, Cast<Float>(pts[k]) - 2.0, Cast<Float>(pts[k + 1]) - 2.0, 4.0, 4.0, NWTheme.Text(), 0.28);
        k += 2;
      }
    }

    // Zonas Blackwall (posições do mockup).
    this.DrawBlackwallZone(map, 870.0, -6.0, 190.0, 104.0);
    this.DrawBlackwallZone(map, 410.0, 404.0, 140.0, 84.0);
    NWInk.Text(map, 874.0, 102.0, NWL.T("// BRECHA NA BLACKWALL", "// BREACH IN THE BLACKWALL"), 14, NWTheme.Crimson(), n"Medium");

    this.overlayLayer = NWInk.Canvas(content, n"overlay", 0.0, 0.0, 1200.0, 496.0);
    this.edgeLayer = NWInk.Canvas(content, n"edges", 0.0, 0.0, 1200.0, 496.0);
    this.nodeLayer = NWInk.Canvas(content, n"nodes", 0.0, 0.0, 1200.0, 496.0);
    this.viewCx = 600.0;
    this.viewCy = 248.0;
  }

  // ------------------------------------------------------------------ zoom

  private func ZoomFactor() -> Float {
    switch this.zoom {
      case 1: return 2.5;
      case 2: return 5.0;
      default: return 1.0;
    }
  }

  public func SetZoom(level: Int32) -> Void {
    let z = Clamp(level, 0, 2);
    if z == this.zoom {
      return;
    }
    this.zoom = z;
    this.sys.PlayUISound(NWSound.Select());
    this.Refresh();
  }

  // MUNDO seleciona nós do mundo; REGIÃO, regiões; CIDADE, locais. Desce/sobe a partir da seleção atual.
  private func NormalizeSelection() -> Void {
    let sys = this.sys;
    if this.zoom == 0 {
      this.selectedSub = -1;
      return;
    }
    let sub = this.selectedSub;
    if this.zoom == 1 {
      if sub < 0 {
        sub = sys.GetFirstSub(this.selected, 1, -1);
      } else {
        if sys.GetSubLevel(sub) == 2 {
          sub = sys.GetSubParentSub(sub);
        }
      }
    } else {
      if sub < 0 {
        sub = sys.GetFirstSub(this.selected, 1, -1);
      }
      if sub >= 0 && sys.GetSubLevel(sub) == 1 {
        sub = sys.GetFirstSub(sys.GetSubParent(sub), 2, sub);
      }
    }
    this.selectedSub = sub;
    if sub >= 0 {
      this.selected = sys.GetSubParent(sub);
    }
  }

  // Centro da vista no nó selecionado, preso às bordas do mapa; aplica escala ao fundo.
  private func UpdateView() -> Void {
    let z = this.ZoomFactor();
    let hw = 600.0 / z;
    let hh = 248.0 / z;
    this.viewCx = ClampF(this.SelX(), hw, 1200.0 - hw);
    this.viewCy = ClampF(this.SelY(), hh, 496.0 - hh);
    this.mapBg.SetScale(Vector2(z, z));
    this.mapBg.SetTranslation(Vector2(600.0 - this.viewCx * z, 248.0 - this.viewCy * z));
  }

  private func SelX() -> Float {
    return this.selectedSub >= 0 ? this.sys.GetSubX(this.selectedSub) : this.sys.GetNodeX(this.selected);
  }

  private func SelY() -> Float {
    return this.selectedSub >= 0 ? this.sys.GetSubY(this.selectedSub) : this.sys.GetNodeY(this.selected);
  }

  private func TX(x: Float) -> Float { return (x - this.viewCx) * this.ZoomFactor() + 600.0; }
  private func TY(y: Float) -> Float { return (y - this.viewCy) * this.ZoomFactor() + 248.0; }

  private func InView(x: Float, y: Float) -> Bool {
    return x >= -10.0 && x <= 1210.0 && y >= -10.0 && y <= 506.0;
  }

  private func DrawEdges() -> Void {
    let layer = this.edgeLayer;
    layer.RemoveAllChildren();
    if this.zoom > 0 {
      return;
    }
    let sys = this.sys;
    let e = 0;
    let edges = sys.GetEdgeCount();
    while e < edges {
      let a = sys.GetEdgeA(e);
      let b = sys.GetEdgeB(e);
      let x1 = sys.GetNodeX(a);
      let y1 = sys.GetNodeY(a);
      let x2 = sys.GetNodeX(b);
      let y2 = sys.GetNodeY(b);
      let bw = sys.GetNodeOwner(a) == NWFaction.Blackwall() || sys.GetNodeOwner(b) == NWFaction.Blackwall();
      if AbsF(x2 - x1) > 600.0 {
        // Atravessa o Pacífico: sai pela borda e volta pelo outro lado, tracejada.
        let left = x1 < x2 ? a : b;
        let right = x1 < x2 ? b : a;
        let lx = sys.GetNodeX(left);
        let ly = sys.GetNodeY(left);
        let rx = sys.GetNodeX(right);
        let ry = sys.GetNodeY(right);
        this.Segment(layer, this.TX(lx), this.TY(ly), this.TX(0.0), this.TY(ly + 12.0), 1, NWTheme.Text(), 0.45);
        this.Segment(layer, this.TX(rx), this.TY(ry), this.TX(1200.0), this.TY(ry + 12.0), 1, NWTheme.Text(), 0.45);
      } else {
        if bw {
          this.Segment(layer, this.TX(x1), this.TY(y1), this.TX(x2), this.TY(y2), 2, NWTheme.Crimson(), 0.6);
        } else {
          this.Segment(layer, this.TX(x1), this.TY(y1), this.TX(x2), this.TY(y2), 0, NWTheme.Red(), 0.38);
        }
      }
      e += 1;
    }
  }

  private func DrawSubEdges() -> Void {
    if this.zoom == 0 {
      return;
    }
    let sys = this.sys;
    let count = sys.GetSubCount();
    let s = 0;
    while s < count {
      if sys.GetSubLevel(s) == this.zoom {
        // Próximo irmão (mesmo pai e mesma região); a última região fecha o triângulo na primeira.
        let next = -1;
        let t = s + 1;
        while t < count && next < 0 {
          if sys.GetSubLevel(t) == this.zoom && sys.GetSubParent(t) == sys.GetSubParent(s) && sys.GetSubParentSub(t) == sys.GetSubParentSub(s) {
            next = t;
          }
          t += 1;
        }
        if next < 0 && this.zoom == 1 {
          let first = sys.GetFirstSub(sys.GetSubParent(s), 1, -1);
          next = first != s ? first : -1;
        }
        if next >= 0 {
          let color = NWTheme.Faction(sys.GetSubOwner(s));
          this.Segment(this.edgeLayer, this.TX(sys.GetSubX(s)), this.TY(sys.GetSubY(s)), this.TX(sys.GetSubX(next)), this.TY(sys.GetSubY(next)), 0, color, 0.35);
        }
      }
      s += 1;
    }
  }

  // Marcadores menores: regiões (REGIÃO e CIDADE) e locais (só CIDADE).
  private func DrawSubNodes() -> Void {
    if this.zoom == 0 {
      return;
    }
    let layer = this.nodeLayer;
    let sys = this.sys;
    let s = 0;
    while s < sys.GetSubCount() {
      let level = sys.GetSubLevel(s);
      let x = this.TX(sys.GetSubX(s));
      let y = this.TY(sys.GetSubY(s));
      if level == this.zoom && this.InView(x, y) {
        let owner = sys.GetSubOwner(s);
        let color = NWTheme.Faction(owner);
        let isSelected = s == this.selectedSub;
        if isSelected {
          NWInk.Rect(layer, x - 17.0, y - 17.0, 34.0, 34.0, color, 0.15);
          NWInk.Frame(layer, x - 17.0, y - 17.0, 34.0, 34.0, color, 1.0);
        }
        this.DrawMarker(layer, x, y, owner, isSelected);
        let name = NWText.Upper(sys.GetSubName(s));
        let labelColor = isSelected ? color : NWTheme.Faction(NWFaction.Neutral());
        let fontSize = isSelected ? 17 : 14;
        let labelX = x + 22.0;
        if x > 1000.0 {
          labelX = x - 22.0 - Cast<Float>(StrLen(name)) * (isSelected ? 10.0 : 8.5);
        }
        NWInk.Text(layer, labelX, y - (isSelected ? 12.0 : 10.0), name, fontSize, labelColor, isSelected ? n"Semi-Bold" : n"Medium");
        let hit = NWInk.HitArea(layer, StringToName(s"sub_\(s)"), x - 22.0, y - 22.0, 44.0, 44.0);
        hit.RegisterToCallback(n"OnRelease", this, n"OnNodeRelease");
      }
      s += 1;
    }
  }

  // Recorta o segmento na vista (Liang–Barsky) antes de desenhar: no zoom, linhas tracejadas
  // longas viravam centenas de widgets fora da moldura. kind: 0 contínua, 1 tracejada, 2 Blackwall.
  private func Segment(layer: ref<inkCanvas>, x1: Float, y1: Float, x2: Float, y2: Float, kind: Int32, color: HDRColor, opacity: Float) -> Void {
    let dx = x2 - x1;
    let dy = y2 - y1;
    let p: array<Float> = [-dx, dx, -dy, dy];
    let q: array<Float> = [x1 + 20.0, 1220.0 - x1, y1 + 20.0, 516.0 - y1];
    let t0 = 0.0;
    let t1 = 1.0;
    let k = 0;
    while k < 4 {
      if p[k] == 0.0 {
        if q[k] < 0.0 { return; }
      } else {
        let t = q[k] / p[k];
        if p[k] < 0.0 {
          t0 = MaxF(t0, t);
        } else {
          t1 = MinF(t1, t);
        }
      }
      k += 1;
    }
    if t0 > t1 { return; }
    let ax = x1 + dx * t0;
    let ay = y1 + dy * t0;
    let bx = x1 + dx * t1;
    let by = y1 + dy * t1;
    switch kind {
      case 1:
        NWInk.DashedLine(layer, ax, ay, bx, by, 6.0, 6.0, 1.2, color, opacity);
        break;
      case 2:
        NWInk.DashedLine(layer, ax, ay, bx, by, 3.0, 5.0, 1.2, color, opacity);
        break;
      default:
        NWInk.Line(layer, ax, ay, bx, by, 1.2, color, opacity);
        break;
    }
  }

  // REGIÃO e CIDADE: retícula de varredura em volta do nó selecionado e ficha do setor.
  private func DrawOverlay() -> Void {
    let layer = this.overlayLayer;
    layer.RemoveAllChildren();
    if this.zoom == 0 {
      return;
    }
    let sys = this.sys;
    let i = this.selected;
    let sub = this.selectedSub;
    let cx = this.TX(this.SelX());
    let cy = this.TY(this.SelY());
    let color = NWTheme.Faction(sub >= 0 ? sys.GetSubOwner(sub) : sys.GetNodeOwner(i));
    let rings = this.zoom == 2 ? 4 : 2;
    let k = 1;
    while k <= rings {
      let r = Cast<Float>(k) * (this.zoom == 2 ? 70.0 : 90.0);
      NWInk.Frame(layer, cx - r, cy - r, r * 2.0, r * 2.0, color, 0.28 - Cast<Float>(k) * 0.04);
      k += 1;
    }
    NWInk.Rect(layer, cx - 0.5, 0.0, 1.0, 496.0, color, 0.18);
    NWInk.Rect(layer, 0.0, cy - 0.5, 1200.0, 1.0, color, 0.18);

    // Ficha no canto superior esquerdo do mapa.
    NWInk.Rect(layer, 12.0, 12.0, 420.0, this.zoom == 2 ? 112.0 : 64.0, NWTheme.Bg(), 0.82);
    NWInk.Frame(layer, 12.0, 12.0, 420.0, this.zoom == 2 ? 112.0 : 64.0, color, 0.7);
    NWInk.Text(layer, 26.0, 18.0, this.zoom == 2 ? NWL.T("SETOR // VISÃO DE CIDADE", "SECTOR // CITY VIEW") : NWL.T("VISÃO DE REGIÃO", "REGION VIEW"), 14, NWTheme.Muted(), n"Semi-Bold");
    if sub >= 0 {
      NWInk.Text(layer, 26.0, 36.0, NWText.Upper(sys.GetSubName(sub)), 22, color, n"Semi-Bold");
      if this.zoom == 2 {
        NWInk.Text(layer, 26.0, 66.0, sys.GetSubSubtitle(sub), 15, NWTheme.Text(), n"Medium");
        NWInk.Text(layer, 26.0, 90.0, NWL.T(s"\(sys.GetSubOwnerName(sub)) · \(sys.GetSubFloorsText(sub)) andares · DV \(sys.GetSubDVText(sub))", s"\(sys.GetSubOwnerName(sub)) · \(sys.GetSubFloorsText(sub)) floors · DV \(sys.GetSubDVText(sub))"), 15, NWTheme.Muted(), n"Medium");
      }
    } else {
      NWInk.Text(layer, 26.0, 36.0, NWText.Upper(sys.GetNodeName(i)), 22, color, n"Semi-Bold");
      if this.zoom == 2 {
        NWInk.Text(layer, 26.0, 66.0, sys.GetNodeSubtitle(i), 15, NWTheme.Text(), n"Medium");
        NWInk.Text(layer, 26.0, 90.0, NWL.T(s"\(sys.GetNodeOwnerName(i)) · controle \(sys.GetNodeControl(i))% · \(sys.GetNodeFloorsText(i)) andares", s"\(sys.GetNodeOwnerName(i)) · control \(sys.GetNodeControl(i))% · \(sys.GetNodeFloorsText(i)) floors"), 15, NWTheme.Muted(), n"Medium");
      }
    }
  }

  private func DrawZoomTabs() -> Void {
    let t = this.zoomTabs;
    t.RemoveAllChildren();
    let labels: array<String> = [NWL.T("MUNDO", "WORLD"), NWL.T("REGIÃO", "REGION"), NWL.T("CIDADE", "CITY")];
    let k = 0;
    while k < 3 {
      let x = Cast<Float>(k) * 144.0;
      if k == this.zoom {
        NWInk.Rect(t, x, 0.0, 140.0, 44.0, NWTheme.Cyan(), 0.12);
        NWInk.Frame(t, x, 0.0, 140.0, 44.0, NWTheme.Cyan(), 1.0);
        NWInk.Text(t, x + 26.0, 9.0, labels[k], 20, NWTheme.Cyan(), n"Semi-Bold");
      } else {
        NWInk.Frame(t, x, 0.0, 140.0, 44.0, NWTheme.Text(), 0.4);
        NWInk.Text(t, x + 26.0, 9.0, labels[k], 20, NWTheme.Text(), n"Semi-Bold");
      }
      let hit = NWInk.HitArea(t, StringToName(s"zoom_\(k)"), x, 0.0, 140.0, 44.0);
      hit.RegisterToCallback(n"OnRelease", this, n"OnButtonRelease");
      k += 1;
    }
  }

  private func DrawBlackwallZone(parent: ref<inkCompoundWidget>, x: Float, y: Float, w: Float, h: Float) -> Void {
    NWInk.Rect(parent, x, y, w, h, NWTheme.Crimson(), 0.10);
    let dx = 0.0;
    while dx < w + h {
      // Hachura diagonal recortada no retângulo.
      let x1 = x + dx;
      let y1 = y;
      let x2 = x + dx - h;
      let y2 = y + h;
      if x1 > x + w { y1 = y + (x1 - (x + w)); x1 = x + w; }
      if x2 < x { y2 = y + h - (x - x2); x2 = x; }
      NWInk.Line(parent, x1, y1, x2, y2, 1.0, NWTheme.Crimson(), 0.25);
      dx += 12.0;
    }
    NWInk.Frame(parent, x, y, w, h, NWTheme.Crimson(), 0.7);
  }

  private func BuildBelowMap(s: ref<inkCanvas>) -> Void {
    this.zoomTabs = NWInk.Canvas(s, n"zoom_tabs", 360.0, 724.0, 432.0, 44.0);
    NWInk.Text(s, 808.0, 736.0, NWL.T("RODA DO MOUSE: ZOOM", "MOUSE WHEEL: ZOOM"), 14, NWTheme.Muted(), n"Medium");
    this.coordsText = NWInk.Text(s, 1180.0, 736.0, "", 16, NWTheme.Muted(), n"Medium");
  }

  private func BuildLog(s: ref<inkCanvas>) -> Void {
    NWInk.Panel(s, 360.0, 800.0, 1200.0, 200.0, NWTheme.Red(), 0.3);
    NWInk.Text(s, 384.0, 814.0, NWL.T("REGISTRO DA REDE", "NETWORK LOG"), 16, NWTheme.Red(), n"Semi-Bold");
    NWInk.Text(s, 1300.0, 814.0, NWL.T("HISTÓRICO COMPLETO: ABA REGISTROS", "FULL HISTORY: LOGS TAB"), 14, NWTheme.Muted(), n"Medium");
    let k = 0;
    while k < 5 {
      ArrayPush(this.logLines, NWInk.Text(s, 384.0, 846.0 + Cast<Float>(k) * 28.0, "", 18, NWTheme.Text(), n"Medium"));
      k += 1;
    }
  }

  private func BuildKeyHints(s: ref<inkCanvas>) -> Void {
    let keys: array<String> = ["LMB", "ESC"];
    let labels: array<String> = [NWL.T("Selecionar nó · zoom centra nele", "Select node · zoom centers on it"), NWL.T("Desconectar", "Disconnect")];
    let k = 0;
    while k < ArraySize(keys) {
      let y = 940.0 + Cast<Float>(k) * 40.0;
      let color = k == 1 ? NWTheme.Red() : NWTheme.Text();
      NWInk.Frame(s, 1572.0, y, 60.0, 28.0, color, 1.0);
      NWInk.Text(s, 1584.0, y + 2.0, keys[k], 16, color, n"Medium");
      NWInk.Text(s, 1646.0, y + 2.0, labels[k], 18, NWTheme.Text(), n"Medium");
      k += 1;
    }
  }

  // ------------------------------------------------------------------ marcadores

  // Forma por facção: losango (V), quadrado (facções), círculo/aro (neutro), tracejado (Blackwall).
  private func DrawMarker(parent: ref<inkCompoundWidget>, cx: Float, cy: Float, faction: Int32, isSelected: Bool) -> Void {
    let color = NWTheme.Faction(faction);
    let shape = NWFaction.Shape(faction);
    let size = faction == NWFaction.V() ? 14.0 : 12.0;
    if Equals(shape, "diamond") {
      let d = NWInk.Rect(parent, cx - size / 2.0, cy - size / 2.0, size, size, color, 1.0);
      d.SetRotation(45.0);
      return;
    }
    if Equals(shape, "square") {
      NWInk.Rect(parent, cx - size / 2.0, cy - size / 2.0, size, size, color, 1.0);
      return;
    }
    if Equals(shape, "circle") {
      NWInk.Frame(parent, cx - 5.0, cy - 5.0, 10.0, 10.0, color, 1.0);
      NWInk.Frame(parent, cx - 4.0, cy - 4.0, 8.0, 8.0, color, 1.0);
      return;
    }
    // Brecha: aro girado e tracejado.
    let k = 0;
    while k < 4 {
      let seg = NWInk.Rect(parent, cx - 6.0 + Cast<Float>(k % 2) * 8.0, cy - 6.0 + Cast<Float>(k / 2) * 8.0, 4.0, 4.0, color, 1.0);
      seg.SetRotation(45.0);
      k += 1;
    }
  }

  private func DrawNodes() -> Void {
    let layer = this.nodeLayer;
    layer.RemoveAllChildren();
    if this.zoom > 0 {
      return;
    }
    let sys = this.sys;
    let i = 0;
    let n = sys.GetNodeCount();
    while i < n {
      let x = this.TX(sys.GetNodeX(i));
      let y = this.TY(sys.GetNodeY(i));
      if this.InView(x, y) {
        let owner = sys.GetNodeOwner(i);
        let color = NWTheme.Faction(owner);
        let isSelected = i == this.selected;
        if isSelected {
          NWInk.Rect(layer, x - 17.0, y - 17.0, 34.0, 34.0, color, 0.15);
          NWInk.Frame(layer, x - 17.0, y - 17.0, 34.0, 34.0, color, 1.0);
        }
        this.DrawMarker(layer, x, y, owner, isSelected);

        let name = NWText.Upper(sys.GetNodeName(i));
        let size = isSelected ? 17 : 14;
        let labelColor = isSelected ? color : NWTheme.Faction(NWFaction.Neutral());
        let style = isSelected ? n"Semi-Bold" : n"Medium";
        let labelX = x + 26.0;
        let labelY = y - (isSelected ? 12.0 : 10.0);
        if x > 1000.0 {
          labelX = x - 26.0 - Cast<Float>(StrLen(name)) * (isSelected ? 10.0 : 8.5);
        }
        // Cidade do México e Porto Príncipe ficam lado a lado: o rótulo do México vai para baixo.
        if Equals(sys.GetNodeId(i), "mex") && this.zoom == 0 {
          labelX = x - 20.0;
          labelY = y + 18.0;
        }
        NWInk.Text(layer, labelX, labelY, name, size, labelColor, style);

        let hit = NWInk.HitArea(layer, StringToName(s"node_\(i)"), x - 22.0, y - 22.0, 44.0, 44.0);
        hit.RegisterToCallback(n"OnRelease", this, n"OnNodeRelease");
      }
      i += 1;
    }
  }

  // ------------------------------------------------------------------ painel do alvo

  private func DrawSubTarget() -> Void {
    let p = this.targetFrame;
    let sys = this.sys;
    let s = this.selectedSub;
    let color = NWTheme.Faction(sys.GetSubOwner(s));

    NWInk.Rect(p, 0.0, 0.0, 300.0, 600.0, NWTheme.Panel(), 0.9);
    NWInk.Frame(p, 0.0, 0.0, 300.0, 600.0, color, 1.0);
    NWInk.Text(p, 24.0, 20.0, sys.GetSubLevel(s) == 1 ? NWL.T("REGIÃO SELECIONADA", "SELECTED REGION") : NWL.T("LOCAL SELECIONADO", "SELECTED SITE"), 16, NWTheme.Muted(), n"Semi-Bold");
    this.WrappedText(p, 24.0, 46.0, NWText.Upper(sys.GetSubName(s)), 18, 28, color);
    NWInk.Text(p, 24.0, 112.0, sys.GetSubSubtitle(s), 14, NWTheme.Faction(NWFaction.Neutral()), n"Medium");

    NWInk.Text(p, 24.0, 138.0, NWL.T("DONO", "OWNER"), 16, NWTheme.Muted(), n"Medium");
    NWInk.Text(p, 110.0, 136.0, sys.IsSubTaken(s) ? NWL.T("Você (tomado)", "You (taken)") : NWL.T(s"\(sys.GetSubOwnerName(s)) (segue o nó pai)", s"\(sys.GetSubOwnerName(s)) (follows the parent node)"), 16, NWTheme.Text(), n"Semi-Bold");

    NWInk.Frame(p, 24.0, 172.0, 120.0, 64.0, NWTheme.Text(), 0.15);
    NWInk.Text(p, 34.0, 178.0, NWL.T("ANDARES", "FLOORS"), 14, NWTheme.Muted(), n"Medium");
    NWInk.Text(p, 34.0, 196.0, sys.GetSubFloorsText(s), 28, NWTheme.Text(), n"Semi-Bold");
    NWInk.Frame(p, 156.0, 172.0, 120.0, 64.0, NWTheme.Text(), 0.15);
    NWInk.Text(p, 166.0, 178.0, "DV", 14, NWTheme.Muted(), n"Medium");
    NWInk.Text(p, 166.0, 196.0, sys.GetSubDVText(s), 28, NWTheme.Yellow(), n"Semi-Bold");

    NWInk.Text(p, 24.0, 252.0, NWL.T("BLACK ICE DETECTADO", "BLACK ICE DETECTED"), 14, NWTheme.Muted(), n"Medium");
    this.WrappedText(p, 24.0, 272.0, sys.GetSubIceText(s), 30, 16, NWTheme.Red());

    NWInk.Text(p, 24.0, 342.0, NWL.T("AO DOMINAR", "ON TAKEOVER"), 14, NWTheme.Muted(), n"Medium");
    this.WrappedText(p, 24.0, 362.0, sys.GetSubRewardText(s), 30, 16, NWTheme.Text());

    let cta = sys.IsBreachActive() ? NWL.T("VOLTAR À INVASÃO", "BACK TO THE BREACH") : sys.GetSubCTA(s);
    this.Button(p, n"btn_main", 24.0, 470.0, 252.0, 52.0, cta, true, NWTheme.Cyan());
    let reason = sys.CanStartSubBreach(s);
    let note = StrLen(this.status) > 0 ? this.status : (sys.GetSubOwner(s) == NWFaction.V() ? "" : reason);
    if StrLen(note) > 0 {
      this.WrappedText(p, 24.0, 534.0, note, 34, 14, NWTheme.Yellow());
    }
  }

  private func DrawTarget() -> Void {
    let p = this.targetFrame;
    p.RemoveAllChildren();
    if this.selectedSub >= 0 {
      this.DrawSubTarget();
      return;
    }
    let sys = this.sys;
    let i = this.selected;
    let owner = sys.GetNodeOwner(i);
    let color = NWTheme.Faction(owner);

    NWInk.Rect(p, 0.0, 0.0, 300.0, 600.0, NWTheme.Panel(), 0.9);
    NWInk.Frame(p, 0.0, 0.0, 300.0, 600.0, color, 1.0);
    NWInk.Text(p, 24.0, 20.0, NWL.T("ALVO SELECIONADO", "SELECTED TARGET"), 16, NWTheme.Muted(), n"Semi-Bold");
    NWInk.Text(p, 24.0, 46.0, NWText.Upper(sys.GetNodeName(i)), 36, color, n"Semi-Bold");
    NWInk.Text(p, 24.0, 92.0, sys.GetNodeSubtitle(i), 14, NWTheme.Faction(NWFaction.Neutral()), n"Medium");

    NWInk.Text(p, 24.0, 124.0, NWL.T("CONTROLE", "CONTROL"), 16, NWTheme.Muted(), n"Medium");
    let ctrl = sys.GetNodeControl(i);
    NWInk.Text(p, 140.0, 122.0, s"\(sys.GetNodeOwnerName(i)) · \(ctrl)%", 17, NWTheme.Text(), n"Semi-Bold");
    NWInk.Rect(p, 24.0, 150.0, 252.0, 6.0, NWTheme.Dark(), 1.0);
    NWInk.Rect(p, 24.0, 150.0, 252.0 * Cast<Float>(ctrl) / 100.0, 6.0, color, 1.0);

    NWInk.Frame(p, 24.0, 172.0, 120.0, 64.0, NWTheme.Text(), 0.15);
    NWInk.Text(p, 34.0, 178.0, NWL.T("ANDARES", "FLOORS"), 14, NWTheme.Muted(), n"Medium");
    NWInk.Text(p, 34.0, 196.0, sys.GetNodeFloorsText(i), 28, NWTheme.Text(), n"Semi-Bold");
    NWInk.Frame(p, 156.0, 172.0, 120.0, 64.0, NWTheme.Text(), 0.15);
    NWInk.Text(p, 166.0, 178.0, "DV", 14, NWTheme.Muted(), n"Medium");
    NWInk.Text(p, 166.0, 196.0, sys.GetNodeDVText(i), 28, NWTheme.Yellow(), n"Semi-Bold");

    NWInk.Text(p, 24.0, 252.0, NWL.T("BLACK ICE DETECTADO", "BLACK ICE DETECTED"), 14, NWTheme.Muted(), n"Medium");
    this.WrappedText(p, 24.0, 272.0, sys.GetNodeIceText(i), 30, 16, NWTheme.Red());

    NWInk.Text(p, 24.0, 342.0, NWL.T("RECOMPENSA AO DOMINAR", "TAKEOVER REWARD"), 14, NWTheme.Muted(), n"Medium");
    this.WrappedText(p, 24.0, 362.0, sys.GetNodeRewardText(i), 30, 16, NWTheme.Text());

    let cta = sys.GetNodeCTA(i);
    if sys.IsBreachActive() {
      cta = NWL.T("VOLTAR À INVASÃO", "BACK TO THE BREACH");
    } else {
      if Equals(cta, NWL.T("MONTAR DEFESAS", "SET UP DEFENSES")) {
        cta = NWL.T(s"DEFESAS · \(sys.GetNodeDefenseCount(i))/3", s"DEFENSES · \(sys.GetNodeDefenseCount(i))/3");
      }
    }
    this.Button(p, n"btn_main", 24.0, 450.0, 252.0, 52.0, cta, true, NWTheme.Cyan());
    this.Button(p, n"btn_scan", 24.0, 512.0, 252.0, 40.0, NWL.T("ESCANEAR · 2 RAM", "SCAN · 2 RAM"), false, NWTheme.Cyan());

    if StrLen(this.status) > 0 {
      this.WrappedText(p, 24.0, 558.0, this.status, 34, 14, NWTheme.Yellow());
    }
  }

  // inkText sem quebra automática aqui: divide o texto em linhas de até `maxChars`.
  private func WrappedText(parent: ref<inkCompoundWidget>, x: Float, y: Float, text: String, maxChars: Int32, size: Int32, color: HDRColor) -> Void {
    let rest = text;
    let line = 0;
    while StrLen(rest) > 0 && line < 3 {
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

  // Botão compacto (banco): fonte menor para caber "WITHDRAW ALL" em 116 px.
  private func SmallButton(parent: ref<inkCompoundWidget>, name: CName, x: Float, y: Float, w: Float, h: Float, label: String, color: HDRColor) -> Void {
    NWInk.Frame(parent, x, y, w, h, color, 0.6);
    NWInk.Text(parent, x + 10.0, y + (h - 19.0) / 2.0, label, 15, color, n"Semi-Bold");
    let hit = NWInk.HitArea(parent, name, x, y, w, h);
    hit.RegisterToCallback(n"OnRelease", this, n"OnButtonRelease");
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
    hit.RegisterToCallback(n"OnRelease", this, n"OnButtonRelease");
  }

  // ------------------------------------------------------------------ atualização

  private func Refresh() -> Void {
    let sys = this.sys;
    if !IsDefined(sys) {
      return;
    }
    this.clockText.SetText(NWL.T(s"REDE \(sys.GetTimeLabel())", s"NET \(sys.GetTimeLabel())"));
    this.interfaceText.SetText(s"\(sys.GetInterface())");

    let ram = sys.GetRam();
    let ramMax = sys.GetRamMax();
    let bonus = sys.GetRamBonus();
    this.ramText.SetText(bonus > 0 ? s"\(ram) / \(ramMax) +\(bonus)" : s"\(ram) / \(ramMax)");
    let cells = Min(ramMax, ArraySize(this.ramBar));
    let filled = ramMax > 0 ? (ram * cells) / ramMax : 0;
    let k = 0;
    while k < ArraySize(this.ramBar) {
      let cell = this.ramBar[k];
      cell.SetVisible(k < cells);
      cell.SetOpacity(k < filled ? 1.0 : 0.18);
      k += 1;
    }
    let trace = sys.GetTrace();
    this.traceText.SetText(s"\(trace)%");
    this.traceBar.SetSize(Vector2(240.0 * Cast<Float>(trace) / 100.0, 6.0));
    this.territoryText.SetText(s"\(sys.GetTerritoryCount()) / \(sys.GetNodeCount())");
    this.eddiesText.SetText(s"€$ \(sys.GetEddies())");
    this.walletText.SetText(NWL.T(s"Carteira do V: €$ \(sys.GetPlayerMoney())", s"V's wallet: €$ \(sys.GetPlayerMoney())"));
    if sys.IsBankFrozen() {
      this.bankStatusText.SetText(NWL.T("CONGELADO PELA NETWATCH", "FROZEN BY NETWATCH"));
      this.bankStatusText.SetTintColor(NWTheme.Red());
    } else {
      this.bankStatusText.SetText("");
      this.bankStatusText.SetTintColor(NWTheme.Yellow());
    }

    let lat = 72.0 - sys.GetNodeY(this.selected) / (496.0 / 122.0);
    let lon = -135.0 + sys.GetNodeX(this.selected) / (1200.0 / 295.0);
    let latI = Cast<Int32>(lat);
    let lonI = Cast<Int32>(lon);
    this.coordsText.SetText(NWL.T(s"LAT \(latI) / LON \(lonI) // NÓS VISÍVEIS: \(sys.GetNodeCount())", s"LAT \(latI) / LON \(lonI) // VISIBLE NODES: \(sys.GetNodeCount())"));

    k = 0;
    while k < ArraySize(this.logLines) {
      this.logLines[k].SetText(sys.GetLogLine(k));
      k += 1;
    }

    this.NormalizeSelection();
    this.UpdateView();
    this.DrawZoomTabs();
    this.DrawOverlay();
    this.DrawEdges();
    this.DrawSubEdges();
    this.DrawNodes();
    this.DrawSubNodes();
    this.DrawTarget();
  }

  // ------------------------------------------------------------------ entrada

  protected cb func OnNodeRelease(evt: ref<inkPointerEvent>) -> Bool {
    if !evt.IsAction(n"click") {
      return false;
    }
    this.HandleClick(NameToString(evt.GetTarget().GetName()));
    return true;
  }

  protected cb func OnButtonRelease(evt: ref<inkPointerEvent>) -> Bool {
    if !evt.IsAction(n"click") {
      return false;
    }
    this.HandleClick(NameToString(evt.GetTarget().GetName()));
    return true;
  }

  // Ponto único de tratamento de cliques, pelo nome da área clicável.
  private func HandleClick(target: String) -> Void {
    if StrBeginsWith(target, "act_") || StrBeginsWith(target, "dmn_use_") || StrBeginsWith(target, "mg_") {
      this.breachView.HandleClick(target);
      return;
    }
    if Equals(target, "tab_daemons") {
      this.sys.PlayUISound(NWSound.Select());
      this.ShowDaemons();
      return;
    }
    if Equals(target, "tab_help") {
      this.sys.PlayUISound(NWSound.Select());
      this.ShowTutorial();
      return;
    }
    if Equals(target, "tab_logs") {
      this.sys.PlayUISound(NWSound.Select());
      this.ShowLogs();
      return;
    }
    if StrBeginsWith(target, "zoom_") {
      this.SetZoom(StringToInt(StrAfterLast(target, "_")));
      return;
    }
    if Equals(target, "tab_arch") {
      this.sys.PlayUISound(NWSound.Select());
      this.ShowArchitectures(this.selected);
      return;
    }
    if StrBeginsWith(target, "sub_") {
      this.sys.PlayUISound(NWSound.Select());
      this.selectedSub = StringToInt(StrAfterFirst(target, "_"));
      this.selected = this.sys.GetSubParent(this.selectedSub);
      this.status = "";
      this.Refresh();
      return;
    }
    if StrBeginsWith(target, "node_") {
      this.sys.PlayUISound(NWSound.Select());
      this.selectedSub = -1;
      this.selected = StringToInt(StrAfterFirst(target, "_"));
      this.status = "";
      this.Refresh();
      return;
    }
    this.HandleButton(StringToName(target));
  }

  private func HandleButton(name: CName) -> Void {
    let sys = this.sys;
    let i = this.selected;
    if StrBeginsWith(NameToString(name), "bank_") {
      let msg = "";
      if Equals(name, n"bank_w5k") { msg = sys.BankWithdraw(5000); }
      if Equals(name, n"bank_wall") { msg = sys.BankWithdraw(0); }
      if Equals(name, n"bank_d5k") { msg = sys.BankDeposit(5000); }
      if Equals(name, n"bank_dall") { msg = sys.BankDeposit(0); }
      this.Refresh();
      this.bankStatusText.SetText(msg);
      return;
    }
    if StrBeginsWith(NameToString(name), "bank_") {
      sys.PlayUISound(NWSound.Cash());
    } else {
      sys.PlayUISound(Equals(name, n"btn_scan") ? NWSound.Scan() : NWSound.Click());
    }
    if Equals(name, n"btn_scan") {
      this.status = sys.ScanNode(i);
    } else {
      if Equals(name, n"btn_main") {
        if sys.IsBreachActive() {
          this.ShowBreach();
          return;
        }
        if this.selectedSub >= 0 {
          let subResult = sys.StartSubBreach(this.selectedSub);
          if sys.IsBreachActive() {
            this.ShowBreach();
            return;
          }
          this.status = sys.GetSubOwner(this.selectedSub) == NWFaction.V() ? "" : subResult;
        } else {
          if sys.GetNodeOwner(i) == NWFaction.V() && sys.GetNodeControl(i) >= 100 {
            this.ShowArchitectures(i);
            return;
          } else {
            let result = sys.StartBreach(i);
            if sys.IsBreachActive() {
              this.ShowBreach();
              return;
            }
            this.status = result;
          }
        }
      }
    }
    this.Refresh();
    return;
  }
}
