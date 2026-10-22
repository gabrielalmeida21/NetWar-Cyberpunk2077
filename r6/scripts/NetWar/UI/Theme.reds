// NET War — cores, fontes e helpers para montar widgets ink em código.
// Fonte: Rajdhani do próprio jogo. Destaques ligados ao estilo de cores principal do jogo
// (main_colors.inkstyle); cores de facção fixas, como no mockup.
module NetWar.UI

public abstract class NWTheme {
  public static func Font() -> String { return "base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily"; }

  public static func Bg() -> HDRColor { return HDRColor(0.027, 0.031, 0.047, 1.0); }
  public static func Panel() -> HDRColor { return HDRColor(0.055, 0.039, 0.047, 1.0); }
  public static func Red() -> HDRColor { return HDRColor(1.0, 0.380, 0.345, 1.0); }
  public static func Cyan() -> HDRColor { return HDRColor(0.369, 0.965, 1.0, 1.0); }
  public static func Yellow() -> HDRColor { return HDRColor(0.953, 0.902, 0.0, 1.0); }
  public static func Text() -> HDRColor { return HDRColor(0.910, 0.886, 0.839, 1.0); }
  public static func Muted() -> HDRColor { return HDRColor(0.604, 0.561, 0.525, 1.0); }
  public static func Crimson() -> HDRColor { return HDRColor(1.0, 0.180, 0.420, 1.0); }
  public static func Dark() -> HDRColor { return HDRColor(0.110, 0.102, 0.118, 1.0); }

  public static func Faction(f: Int32) -> HDRColor {
    switch f {
      case 0: return HDRColor(0.369, 0.965, 1.0, 1.0);
      case 1: return HDRColor(1.0, 0.231, 0.231, 1.0);
      case 2: return HDRColor(0.961, 0.651, 0.137, 1.0);
      case 3: return HDRColor(0.302, 0.553, 1.0, 1.0);
      case 4: return HDRColor(0.710, 0.482, 1.0, 1.0);
      case 5: return HDRColor(0.953, 0.902, 0.0, 1.0);
      case 7: return HDRColor(1.0, 0.180, 0.420, 1.0);
      default: return HDRColor(0.788, 0.765, 0.722, 1.0);
    }
  }

  // Raridade dos daemons: comum cinza, raro azul, épico roxo, lendário laranja.
  public static func Rarity(r: Int32) -> HDRColor {
    switch r {
      case 1: return HDRColor(0.302, 0.553, 1.0, 1.0);
      case 2: return HDRColor(0.710, 0.482, 1.0, 1.0);
      case 3: return HDRColor(0.961, 0.651, 0.137, 1.0);
      default: return HDRColor(0.788, 0.765, 0.722, 1.0);
    }
  }

  // Liga a cor do widget ao vermelho de interface do jogo (acompanha mudanças de tema).
  public static func BindGameRed(w: ref<inkWidget>) -> Void {
    w.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
    w.BindProperty(n"tintColor", n"MainColors.Red");
  }
}

// Eventos de som de UI do jogo usados pelo NET War (todos existentes nos scripts do jogo).
public abstract class NWSound {
  public static func Click() -> CName { return n"ui_menu_onpress"; }
  public static func Select() -> CName { return n"ui_gui_tab_change"; }
  public static func Scan() -> CName { return n"ui_focus_mode_quickhack"; }
  public static func Cash() -> CName { return n"ui_loot_cash_picking"; }
  public static func HackPress() -> CName { return n"ui_hacking_press"; }
  public static func HackFail() -> CName { return n"ui_hacking_press_fail"; }
  public static func Denied() -> CName { return n"ui_hacking_access_denied"; }
  public static func Hit() -> CName { return n"ui_jingle_chip_malfunction"; }
  // Som de sucesso: só ao dominar o nó.
  public static func Captured() -> CName { return n"ui_hacking_access_granted"; }
  public static func Close() -> CName { return n"ui_hacking_close"; }
}

public abstract class NWInk {

  public static func Place(w: ref<inkWidget>, parent: ref<inkCompoundWidget>, x: Float, y: Float, width: Float, height: Float) -> Void {
    w.SetAnchor(inkEAnchor.TopLeft);
    w.SetMargin(inkMargin(x, y, 0.0, 0.0));
    w.SetSize(Vector2(width, height));
    w.Reparent(parent);
  }

  public static func Canvas(parent: ref<inkCompoundWidget>, name: CName, x: Float, y: Float, width: Float, height: Float) -> ref<inkCanvas> {
    let c = new inkCanvas();
    c.SetName(name);
    NWInk.Place(c, parent, x, y, width, height);
    return c;
  }

  public static func Rect(parent: ref<inkCompoundWidget>, x: Float, y: Float, width: Float, height: Float, color: HDRColor, opacity: Float) -> ref<inkRectangle> {
    let r = new inkRectangle();
    NWInk.Place(r, parent, x, y, width, height);
    r.SetTintColor(color);
    r.SetOpacity(opacity);
    return r;
  }

  // Moldura de 1 px (4 retângulos).
  public static func Frame(parent: ref<inkCompoundWidget>, x: Float, y: Float, width: Float, height: Float, color: HDRColor, opacity: Float) -> Void {
    NWInk.Rect(parent, x, y, width, 1.0, color, opacity);
    NWInk.Rect(parent, x, y + height - 1.0, width, 1.0, color, opacity);
    NWInk.Rect(parent, x, y, 1.0, height, color, opacity);
    NWInk.Rect(parent, x + width - 1.0, y, 1.0, height, color, opacity);
  }

  // Painel escuro translúcido com borda.
  public static func Panel(parent: ref<inkCompoundWidget>, x: Float, y: Float, width: Float, height: Float, border: HDRColor, borderOpacity: Float) -> Void {
    NWInk.Rect(parent, x, y, width, height, NWTheme.Panel(), 0.88);
    NWInk.Frame(parent, x, y, width, height, border, borderOpacity);
  }

  public static func Text(parent: ref<inkCompoundWidget>, x: Float, y: Float, text: String, size: Int32, color: HDRColor, style: CName) -> ref<inkText> {
    let t = new inkText();
    t.SetFontFamily(NWTheme.Font());
    t.SetFontStyle(style);
    t.SetFontSize(size);
    t.SetTintColor(color);
    t.SetText(text);
    t.SetAnchor(inkEAnchor.TopLeft);
    t.SetMargin(inkMargin(x, y, 0.0, 0.0));
    t.SetFitToContent(true);
    t.Reparent(parent);
    return t;
  }

  // Linha como retângulo girado em torno do ponto inicial.
  public static func Line(parent: ref<inkCompoundWidget>, x1: Float, y1: Float, x2: Float, y2: Float, thickness: Float, color: HDRColor, opacity: Float) -> Void {
    let dx = x2 - x1;
    let dy = y2 - y1;
    let len = SqrtF(dx * dx + dy * dy);
    if len < 0.5 {
      return;
    }
    let angle = Rad2Deg(AcosF(dx / len));
    if dy < 0.0 {
      angle = -angle;
    }
    let r = NWInk.Rect(parent, x1, y1 - thickness / 2.0, len, thickness, color, opacity);
    r.SetRenderTransformPivot(Vector2(0.0, 0.5));
    r.SetRotation(angle);
  }

  public static func DashedLine(parent: ref<inkCompoundWidget>, x1: Float, y1: Float, x2: Float, y2: Float, dash: Float, gap: Float, thickness: Float, color: HDRColor, opacity: Float) -> Void {
    let dx = x2 - x1;
    let dy = y2 - y1;
    let len = SqrtF(dx * dx + dy * dy);
    if len < 0.5 {
      return;
    }
    let ux = dx / len;
    let uy = dy / len;
    let t = 0.0;
    while t < len {
      let e = MinF(len, t + dash);
      NWInk.Line(parent, x1 + ux * t, y1 + uy * t, x1 + ux * e, y1 + uy * e, thickness, color, opacity);
      t = e + gap;
    }
  }

  // Área clicável invisível com nome usado para identificar a origem do clique.
  public static func HitArea(parent: ref<inkCompoundWidget>, name: CName, x: Float, y: Float, width: Float, height: Float) -> ref<inkRectangle> {
    let r = NWInk.Rect(parent, x, y, width, height, HDRColor(0.0, 0.0, 0.0, 1.0), 0.01);
    r.SetName(name);
    r.SetInteractive(true);
    return r;
  }
}
