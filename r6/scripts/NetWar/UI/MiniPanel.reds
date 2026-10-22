// NET War — painel dos minigames (camada por cima da tela + relógio por animação em loop, que roda
// com o jogo pausado). Usado pela tela da invasão e pela aba TUTORIAL (treino). Só apresentação:
// lê o NetWarSystem e envia as jogadas; quem hospeda redesenha a tela quando algo muda.
module NetWar.UI

import NetWar.*
import NetWar.Data.*
import NetWar.Breach.*

public class NWMiniPanel extends IScriptable {
  private let sys: wref<NetWarSystem>;
  private let breachHost: wref<NWBreachView>;
  private let tutorialHost: wref<NWTutorialView>;

  private let miniLayer: wref<inkCanvas>;
  private let ticker: wref<inkRectangle>;
  private let tickProxy: ref<inkAnimProxy>;
  private let miniTimeText: wref<inkText>;
  private let miniTimeBar: wref<inkRectangle>;
  private let zapMarker: wref<inkRectangle>;
  private let zapLapsText: wref<inkText>;
  private let slideBeams: array<wref<inkRectangle>>;
  private let slideGhosts: array<wref<inkRectangle>>;
  private let slideRunner: wref<inkRectangle>;
  private let sonarEcho: array<wref<inkRectangle>>;

  public static func Create(sys: wref<NetWarSystem>, parent: ref<inkCompoundWidget>) -> ref<NWMiniPanel> {
    let p = new NWMiniPanel();
    p.sys = sys;
    p.miniLayer = NWInk.Canvas(parent, n"mini_layer", 0.0, 0.0, 1920.0, 1080.0);
    p.ticker = NWInk.Rect(parent, 0.0, 0.0, 1.0, 1.0, NWTheme.Bg(), 0.0);
    return p;
  }

  public func SetBreachHost(host: ref<NWBreachView>) -> Void { this.breachHost = host; }
  public func SetTutorialHost(host: ref<NWTutorialView>) -> Void { this.tutorialHost = host; }

  // Redesenha a tela inteira de quem hospeda (o resultado muda a invasão ou o texto do treino).
  private func NotifyHost() -> Void {
    if IsDefined(this.breachHost) {
      this.breachHost.Refresh();
    }
    if IsDefined(this.tutorialHost) {
      this.tutorialHost.Refresh();
    }
  }

  public func Draw() -> Void {
    this.DrawMiniGame();
  }

  protected cb func OnActionRelease(evt: ref<inkPointerEvent>) -> Bool {
    if !evt.IsAction(n"click") {
      return false;
    }
    this.HandleClick(NameToString(evt.GetTarget().GetName()));
    return true;
  }

  public func HandleClick(name: String) -> Void {
    if Equals(name, "mg_abort") {
      this.sys.AbortMiniGame();
      this.NotifyHost();
      return;
    }
    if StrBeginsWith(name, "mg_pc_") {
      if !this.sys.CircuitTurn(StringToInt(StrAfterLast(name, "_"))) {
        this.sys.PlayUISound(NWSound.Click());
      }
      this.NotifyHost();
      return;
    }
    if StrBeginsWith(name, "mg_def_") {
      this.sys.DefenseChoose(StringToInt(StrAfterLast(name, "_")));
      this.sys.PlayUISound(NWSound.Click());
      this.NotifyHost();
      return;
    }
    if Equals(name, "mg_ping") {
      this.sys.SonarPing();
      this.NotifyHost();
      return;
    }
    if Equals(name, "mg_adv") {
      this.sys.SlideAdvance();
      this.NotifyHost();
      return;
    }
    if Equals(name, "mg_zap") {
      this.sys.ZapStrike();
      this.NotifyHost();
      return;
    }
    if StrBeginsWith(name, "mg_blk_") {
      this.sys.HeaderChoose(StringToInt(StrAfterLast(name, "_")));
      this.NotifyHost();
      return;
    }
    if StrBeginsWith(name, "mg_cell_") {
      if !this.sys.MiniPick(StringToInt(StrAfterLast(name, "_"))) {
        this.sys.PlayUISound(NWSound.Click());
      }
      this.NotifyHost();
      return;
    }
  }

  private func DrawMiniGame() -> Void {
    let sys = this.sys;
    let m = this.miniLayer;
    m.RemoveAllChildren();
    if !sys.HasMiniGame() {
      this.StopTicker();
      return;
    }

    NWInk.Rect(m, 460.0, 136.0, 900.0, 540.0, NWTheme.Bg(), 0.97);
    NWInk.Frame(m, 460.0, 136.0, 900.0, 540.0, NWTheme.Cyan(), 0.9);
    let rx = 920.0;
    let k = 0;
    if sys.GetMiniKind() == 7 {
      this.DrawSonarBody(m, rx);
    } else {
    if sys.GetMiniKind() == 6 {
      this.DrawCircuitBody(m, rx);
    } else {
    if sys.GetMiniKind() == 5 {
      this.DrawDefenseBody(m, rx);
    } else {
    if sys.GetMiniKind() == 4 {
      this.DrawSlideBody(m, rx);
    } else {
    if sys.GetMiniKind() == 3 {
      this.DrawZapBody(m, rx);
    } else {
    if sys.GetMiniKind() == 2 {
      this.DrawHeaderBody(m, rx);
    } else {
      NWInk.Text(m, 484.0, 148.0, NWL.T("BACKDOOR // SEQUÊNCIA DE BUFFER", "BACKDOOR // BUFFER SEQUENCE"), 24, NWTheme.Cyan(), n"Semi-Bold");
      NWInk.Text(m, 484.0, 182.0, NWL.T("Comece na linha de cima; depois alterne: coluna da última escolha, linha da última escolha.", "Start on the top row, then alternate: column of the last pick, row of the last pick."), 15, NWTheme.Muted(), n"Medium");

      // Grade.
      let size = sys.GetMiniSize();
      let cell = size <= 5 ? 66.0 : 56.0;
      let step = cell + 6.0;
      let gx = 484.0;
      let gy = 216.0;
      let i = 0;
      while i < size * size {
        let r = i / size;
        let c = i % size;
        let x = gx + Cast<Float>(c) * step;
        let y = gy + Cast<Float>(r) * step;
        if sys.IsMiniCellActiveLine(i) {
          NWInk.Rect(m, x - 3.0, y - 3.0, cell + 6.0, cell + 6.0, NWTheme.Cyan(), 0.10);
        }
        if sys.IsMiniCellUsed(i) {
          NWInk.Rect(m, x, y, cell, cell, NWTheme.Dark(), 1.0);
          NWInk.Text(m, x + cell / 2.0 - 12.0, y + cell / 2.0 - 13.0, "[ ]", 20, NWTheme.Muted(), n"Medium");
        } else {
          // Canto Mk.6: a próxima casa do caminho que fecha mais rápido fica em vermelho;
          // as dicas da Inteligência (qualquer casa com o código certo) continuam em amarelo.
          let best = sys.IsMiniBestNext(i);
          let hint = best || sys.IsMiniHint(i);
          let pickable = sys.CanMiniPick(i);
          let color = best ? NWTheme.Red() : (hint ? NWTheme.Yellow() : (pickable ? NWTheme.Cyan() : NWTheme.Muted()));
          NWInk.Rect(m, x, y, cell, cell, color, best ? 0.28 : (hint ? 0.18 : (pickable ? 0.08 : 0.03)));
          NWInk.Frame(m, x, y, cell, cell, color, hint ? 1.0 : (pickable ? 0.6 : 0.2));
          NWInk.Text(m, x + cell / 2.0 - 15.0, y + cell / 2.0 - 15.0, sys.GetMiniCellText(i), 24, color, n"Semi-Bold");
          if pickable {
            let hit = NWInk.HitArea(m, StringToName(s"mg_cell_\(i)"), x, y, cell, cell);
            hit.RegisterToCallback(n"OnRelease", this, n"OnActionRelease");
          }
        }
        i += 1;
      }

      // Sequência pedida.
      NWInk.Text(m, rx, 216.0, NWL.T("SEQUÊNCIA", "SEQUENCE"), 15, NWTheme.Muted(), n"Semi-Bold");
      let matched = sys.GetMiniMatched();
      k = 0;
      while k < sys.GetMiniSeqLen() {
        let x = rx + Cast<Float>(k) * 62.0;
        let done = k < matched;
        NWInk.Rect(m, x, 240.0, 56.0, 42.0, NWTheme.Cyan(), done ? 0.35 : 0.06);
        NWInk.Frame(m, x, 240.0, 56.0, 42.0, NWTheme.Cyan(), done ? 1.0 : 0.5);
        NWInk.Text(m, x + 13.0, 247.0, sys.GetMiniSeqText(k), 22, done ? NWTheme.Text() : NWTheme.Cyan(), n"Semi-Bold");
        k += 1;
      }

      // Buffer.
      let bmax = sys.GetMiniBufferMax();
      let count = sys.GetMiniPickCount();
      NWInk.Text(m, rx, 300.0, NWL.T(s"BUFFER  \(count) / \(bmax)", s"BUFFER  \(count) / \(bmax)"), 15, NWTheme.Muted(), n"Semi-Bold");
      let slot = MinF(44.0, 420.0 / Cast<Float>(Max(1, bmax)));
      k = 0;
      while k < bmax {
        let x = rx + Cast<Float>(k) * slot;
        NWInk.Frame(m, x, 324.0, slot - 6.0, 36.0, NWTheme.Yellow(), k < count ? 0.9 : 0.3);
        if k < count {
          NWInk.Text(m, x + 4.0, 330.0, sys.GetMiniPickText(k), 18, NWTheme.Yellow(), n"Semi-Bold");
        }
        k += 1;
      }
    }

    }
    }
    }
    }
    }

    // Tempo (Zap mostra voltas e o sonar mostra pulsos no corpo deles).
    if sys.GetMiniKind() != 3 && sys.GetMiniKind() != 7 {
      NWInk.Text(m, rx, 380.0, NWL.T("TEMPO", "TIME"), 15, NWTheme.Muted(), n"Semi-Bold");
      this.miniTimeText = NWInk.Text(m, rx, 400.0, "", 26, NWTheme.Red(), n"Semi-Bold");
      NWInk.Rect(m, rx, 438.0, 420.0, 8.0, NWTheme.Dark(), 1.0);
      this.miniTimeBar = NWInk.Rect(m, rx, 438.0, 420.0, 8.0, NWTheme.Red(), 1.0);
    }
    this.UpdateMiniTime();

    // O que está ajudando: atributos, Interface e equipamento.
    NWInk.Text(m, rx, 462.0, NWL.T("SEU NETRUNNER", "YOUR NETRUNNER"), 15, NWTheme.Muted(), n"Semi-Bold");
    k = 0;
    while k < sys.GetMiniNoteCount() {
      NWInk.Text(m, rx, 486.0 + Cast<Float>(k) * 22.0, sys.GetMiniNote(k), 15, NWTheme.Text(), n"Medium");
      k += 1;
    }

    NWInk.Frame(m, rx, 626.0, 220.0, 36.0, NWTheme.Red(), 0.8);
    NWInk.Text(m, rx + 14.0, 632.0, NWL.T("DESISTIR (FALHA)", "GIVE UP (FAIL)"), 17, NWTheme.Red(), n"Semi-Bold");
    let abort = NWInk.HitArea(m, n"mg_abort", rx, 626.0, 220.0, 36.0);
    abort.RegisterToCallback(n"OnRelease", this, n"OnActionRelease");

    this.StartTicker();
  }

  // Eye-Dee: corrente de blocos (cada um começa onde o anterior termina) e blocos soltos.
  private func DrawHeaderBody(m: ref<inkCanvas>, rx: Float) -> Void {
    let sys = this.sys;
    NWInk.Text(m, 484.0, 148.0, NWL.T("EYE-DEE // DECIFRAR CABEÇALHO", "EYE-DEE // DECODE HEADER"), 24, NWTheme.Cyan(), n"Semi-Bold");
    NWInk.Text(m, 484.0, 182.0, NWL.T("Cada bloco começa com o caractere em que o anterior termina. Corrompidos levam a um beco sem saída.", "Each block starts with the character the previous one ends with. Corrupted ones lead to a dead end."), 15, NWTheme.Muted(), n"Medium");

    // Início e fim da assinatura.
    NWInk.Text(m, 484.0, 214.0, NWL.T("INÍCIO", "START"), 15, NWTheme.Muted(), n"Semi-Bold");
    NWInk.Text(m, 484.0, 232.0, sys.GetHeaderStartText(), 34, NWTheme.Cyan(), n"Semi-Bold");
    NWInk.Text(m, 600.0, 214.0, NWL.T("FIM", "END"), 15, NWTheme.Muted(), n"Semi-Bold");
    NWInk.Text(m, 600.0, 232.0, sys.GetHeaderEndText(), 34, NWTheme.Yellow(), n"Semi-Bold");

    // Corrente montada.
    let len = sys.GetHeaderChainLen();
    let placed = sys.GetHeaderPlacedCount();
    let pre = sys.GetHeaderPreplaced();
    let k = 0;
    while k < len {
      let x = 484.0 + Cast<Float>(k) * 70.0;
      let y = 290.0;
      if k < placed {
        let fromDeck = k < pre;
        NWInk.Rect(m, x, y, 62.0, 48.0, NWTheme.Cyan(), fromDeck ? 0.12 : 0.30);
        NWInk.Frame(m, x, y, 62.0, 48.0, NWTheme.Cyan(), 1.0);
        NWInk.Text(m, x + 12.0, y + 9.0, sys.GetHeaderPlacedText(k), 24, NWTheme.Text(), n"Semi-Bold");
        if fromDeck {
          NWInk.Text(m, x + 2.0, y + 50.0, "DECK", 11, NWTheme.Muted(), n"Medium");
        }
      } else {
        let next = k == placed;
        NWInk.Frame(m, x, y, 62.0, 48.0, next ? NWTheme.Yellow() : NWTheme.Muted(), next ? 0.9 : 0.3);
        if next {
          NWInk.Text(m, x + 12.0, y + 9.0, sys.GetHeaderNeedText() + "?", 24, NWTheme.Yellow(), n"Semi-Bold");
        }
      }
      k += 1;
    }

    // Blocos soltos.
    NWInk.Text(m, 484.0, 372.0, NWL.T("BLOCOS DO ARQUIVO", "FILE BLOCKS"), 15, NWTheme.Muted(), n"Semi-Bold");
    let n = sys.GetHeaderBlockCount();
    let wrong = sys.GetHeaderLastWrong();
    let slot = 0;
    let b = 0;
    while b < n {
      let gone = sys.IsHeaderBlockGone(b);
      let burned = gone && sys.IsHeaderBlockDecoy(b);
      if !gone || burned {
        let x = 484.0 + Cast<Float>(slot % 4) * 104.0;
        let y = 396.0 + Cast<Float>(slot / 4) * 70.0;
        if burned {
          NWInk.Rect(m, x, y, 94.0, 58.0, NWTheme.Red(), 0.10);
          NWInk.Frame(m, x, y, 94.0, 58.0, NWTheme.Red(), 0.6);
          NWInk.Text(m, x + 26.0, y + 4.0, sys.GetHeaderBlockText(b), 22, NWTheme.Red(), n"Semi-Bold");
          NWInk.Text(m, x + 8.0, y + 34.0, NWL.T("CORROMPIDO", "CORRUPTED"), 12, NWTheme.Red(), n"Medium");
        } else {
          let hint = sys.IsHeaderHint(b);
          let color = b == wrong ? NWTheme.Red() : (hint ? NWTheme.Yellow() : NWTheme.Cyan());
          NWInk.Rect(m, x, y, 94.0, 58.0, color, hint ? 0.20 : 0.08);
          NWInk.Frame(m, x, y, 94.0, 58.0, color, hint || b == wrong ? 1.0 : 0.6);
          NWInk.Text(m, x + 26.0, y + 12.0, sys.GetHeaderBlockText(b), 28, color, n"Semi-Bold");
          let hit = NWInk.HitArea(m, StringToName(s"mg_blk_\(b)"), x, y, 94.0, 58.0);
          hit.RegisterToCallback(n"OnRelease", this, n"OnActionRelease");
        }
        slot += 1;
      }
      b += 1;
    }

    // Erros (3 corrompem o arquivo; os gratuitos não dão rastreio).
    let errors = sys.GetHeaderErrors();
    let free = sys.GetHeaderFreeErrors();
    NWInk.Text(m, rx, 216.0, NWL.T("ERROS", "ERRORS"), 15, NWTheme.Muted(), n"Semi-Bold");
    k = 0;
    while k < sys.GetHeaderMaxErrors() {
      let x = rx + Cast<Float>(k) * 50.0;
      let used = k < errors;
      NWInk.Rect(m, x, 240.0, 40.0, 40.0, NWTheme.Red(), used ? 0.5 : 0.06);
      NWInk.Frame(m, x, 240.0, 40.0, 40.0, k < free ? NWTheme.Cyan() : NWTheme.Red(), 0.9);
      k += 1;
    }
    NWInk.Text(m, rx, 292.0, NWL.T(s"\(free) gratuito(s) · o 3º erro corrompe o arquivo", s"\(free) free · the 3rd error corrupts the file"), 15, NWTheme.Text(), n"Medium");
  }

  private func SonarCX() -> Float { return 692.0; }
  private func SonarCY() -> Float { return 446.0; }
  private func SonarR() -> Float { return 170.0; }

  // Anel quadrado entre dois raios (4 retângulos).
  private func SquareRing(m: ref<inkCanvas>, rOut: Float, rIn: Float, color: HDRColor, opacity: Float) -> Void {
    let cx = this.SonarCX();
    let cy = this.SonarCY();
    let t = MaxF(1.0, rOut - rIn);
    NWInk.Rect(m, cx - rOut, cy - rOut, rOut * 2.0, t, color, opacity);
    NWInk.Rect(m, cx - rOut, cy + rIn, rOut * 2.0, t, color, opacity);
    NWInk.Rect(m, cx - rOut, cy - rIn, t, rIn * 2.0, color, opacity);
    NWInk.Rect(m, cx + rIn, cy - rIn, t, rIn * 2.0, color, opacity);
  }

  // Escanear: radar quadrado. Faixa-alvo amarela (centro perfeito em vermelho) e eco azul se fechando.
  private func DrawSonarBody(m: ref<inkCanvas>, rx: Float) -> Void {
    let sys = this.sys;
    NWInk.Text(m, 484.0, 148.0, NWL.T("ESCANEAR // SONAR", "SCAN // SONAR"), 24, NWTheme.Cyan(), n"Semi-Bold");
    NWInk.Text(m, 484.0, 182.0, NWL.T("Clique (ou ESPAÇO) quando o eco azul passar pela faixa amarela; o vermelho é perfeito.", "Click (or SPACE) when the blue echo crosses the yellow band; red is perfect."), 15, NWTheme.Muted(), n"Medium");

    let R = this.SonarR();
    let bc = sys.GetSonarBandCenter();
    let bh = sys.GetSonarBandHalf();
    NWInk.Frame(m, this.SonarCX() - R, this.SonarCY() - R, R * 2.0, R * 2.0, NWTheme.Cyan(), 0.3);
    this.SquareRing(m, (bc + bh) * R, (bc - bh) * R, NWTheme.Yellow(), 0.35);
    let ph = bh * NWSonarGame.PerfectShare();
    this.SquareRing(m, (bc + ph) * R, (bc - ph) * R, NWTheme.Red(), 0.6);
    let center = NWInk.Rect(m, this.SonarCX() - 9.0, this.SonarCY() - 9.0, 18.0, 18.0, NWTheme.Cyan(), 1.0);
    center.SetRotation(45.0);

    ArrayClear(this.sonarEcho);
    let k = 0;
    while k < 4 {
      ArrayPush(this.sonarEcho, NWInk.Rect(m, 0.0, 0.0, 1.0, 1.0, NWTheme.Cyan(), 1.0));
      k += 1;
    }
    let area = NWInk.HitArea(m, n"mg_ping", this.SonarCX() - R, this.SonarCY() - R, R * 2.0, R * 2.0);
    area.RegisterToCallback(n"OnRelease", this, n"OnActionRelease");

    // Pulsos e pontos na coluna da direita.
    NWInk.Rect(m, rx, 216.0, 200.0, 56.0, NWTheme.Cyan(), 0.15);
    NWInk.Frame(m, rx, 216.0, 200.0, 56.0, NWTheme.Cyan(), 1.0);
    NWInk.Text(m, rx + 24.0, 226.0, "PING", 28, NWTheme.Cyan(), n"Semi-Bold");
    let button = NWInk.HitArea(m, n"mg_ping", rx, 216.0, 200.0, 56.0);
    button.RegisterToCallback(n"OnRelease", this, n"OnActionRelease");
    NWInk.Text(m, rx + 214.0, 234.0, NWL.T("ou ESPAÇO", "or SPACE"), 15, NWTheme.Text(), n"Medium");
    NWInk.Text(m, rx, 290.0, NWL.T("PULSOS", "PULSES"), 15, NWTheme.Muted(), n"Semi-Bold");
    k = 0;
    while k < sys.GetSonarPulses() {
      let mark = sys.GetSonarMark(k);
      let color = mark == 2 ? NWTheme.Red() : (mark == 1 ? NWTheme.Yellow() : (mark == 3 ? NWTheme.Muted() : NWTheme.Cyan()));
      let label = mark == 2 ? NWL.T("PERFEITO", "PERFECT") : (mark == 1 ? NWL.T("BOM", "GOOD") : (mark == 3 ? NWL.T("ERRO", "MISS") : "..."));
      let x = rx + Cast<Float>(k) * 104.0;
      NWInk.Frame(m, x, 312.0, 96.0, 34.0, color, 0.9);
      NWInk.Text(m, x + 8.0, 318.0, label, 15, color, n"Semi-Bold");
      k += 1;
    }
    NWInk.Text(m, rx, 362.0, NWL.T(s"PONTOS \(sys.GetSonarScore()) / META \(sys.GetSonarGoal())", s"POINTS \(sys.GetSonarScore()) / GOAL \(sys.GetSonarGoal())"), 18, NWTheme.Yellow(), n"Semi-Bold");
    NWInk.Text(m, rx, 390.0, NWL.T("Errar tudo revela a base; a meta revela a torre toda.", "Missing everything reveals the base; the goal reveals the whole tower."), 14, NWTheme.Text(), n"Medium");
    this.UpdateSonar();
  }

  private func UpdateSonar() -> Void {
    let sys = this.sys;
    if sys.GetMiniKind() != 7 || ArraySize(this.sonarEcho) < 4 {
      return;
    }
    let r = MaxF(2.0, sys.GetSonarRadius() * this.SonarR());
    let cx = this.SonarCX();
    let cy = this.SonarCY();
    let t = 4.0;
    let op = sys.IsSonarWaiting() ? 0.15 : 1.0;
    this.sonarEcho[0].SetMargin(inkMargin(cx - r, cy - r, 0.0, 0.0));
    this.sonarEcho[0].SetSize(Vector2(r * 2.0, t));
    this.sonarEcho[1].SetMargin(inkMargin(cx - r, cy + r - t, 0.0, 0.0));
    this.sonarEcho[1].SetSize(Vector2(r * 2.0, t));
    this.sonarEcho[2].SetMargin(inkMargin(cx - r, cy - r, 0.0, 0.0));
    this.sonarEcho[2].SetSize(Vector2(t, r * 2.0));
    this.sonarEcho[3].SetMargin(inkMargin(cx + r - t, cy - r, 0.0, 0.0));
    this.sonarEcho[3].SetSize(Vector2(t, r * 2.0));
    let k = 0;
    while k < 4 {
      this.sonarEcho[k].SetOpacity(op);
      k += 1;
    }
  }

  // Controlar: peças desenhadas como braços a partir do centro; acesas quando recebem energia.
  private func DrawCircuitBody(m: ref<inkCanvas>, rx: Float) -> Void {
    let sys = this.sys;
    NWInk.Text(m, 484.0, 148.0, NWL.T("CONTROLAR // CIRCUITO DE ENERGIA", "CONTROL // POWER CIRCUIT"), 24, NWTheme.Cyan(), n"Semi-Bold");
    NWInk.Text(m, 484.0, 182.0, NWL.T("Clique nas peças para girar. Ligue a FONTE (esquerda) ao NÚCLEO (direita); peças com energia acendem.", "Click pieces to rotate. Link the SOURCE (left) to the CORE (right); powered pieces light up."), 15, NWTheme.Muted(), n"Medium");

    let size = sys.GetCircuitSize();
    let cell = size <= 4 ? 84.0 : (size == 5 ? 70.0 : 60.0);
    let step = cell + 4.0;
    let gx = 504.0;
    let gy = 216.0;
    let on = sys.GetCircuitPowered();
    let arm = cell * 0.22;
    let i = 0;
    while i < size * size {
      let x = gx + Cast<Float>(i % size) * step;
      let y = gy + Cast<Float>(i / size) * step;
      let powered = i < ArraySize(on) && on[i];
      let locked = sys.IsCircuitLocked(i);
      let color = powered ? NWTheme.Cyan() : NWTheme.Muted();
      NWInk.Rect(m, x, y, cell, cell, NWTheme.Dark(), 0.95);
      if sys.IsCircuitHint(i) {
        NWInk.Frame(m, x, y, cell, cell, NWTheme.Yellow(), 0.9);
      } else {
        NWInk.Frame(m, x, y, cell, cell, locked ? NWTheme.Text() : NWTheme.Cyan(), locked ? 0.5 : 0.25);
      }
      let mask = sys.GetCircuitMask(i);
      let cx = x + cell / 2.0;
      let cy = y + cell / 2.0;
      let half = cell / 2.0;
      NWInk.Rect(m, cx - arm / 2.0, cy - arm / 2.0, arm, arm, color, 1.0);
      if (mask & 1) != 0 { NWInk.Rect(m, cx - arm / 2.0, y, arm, half, color, 1.0); }
      if (mask & 2) != 0 { NWInk.Rect(m, cx, cy - arm / 2.0, half, arm, color, 1.0); }
      if (mask & 4) != 0 { NWInk.Rect(m, cx - arm / 2.0, cy, arm, half, color, 1.0); }
      if (mask & 8) != 0 { NWInk.Rect(m, x, cy - arm / 2.0, half, arm, color, 1.0); }
      if locked {
        NWInk.Text(m, x + 3.0, y + 1.0, NWL.T("FIXA", "FIXED"), 10, NWTheme.Text(), n"Medium");
      } else {
        let hit = NWInk.HitArea(m, StringToName(s"mg_pc_\(i)"), x, y, cell, cell);
        hit.RegisterToCallback(n"OnRelease", this, n"OnActionRelease");
      }
      i += 1;
    }
    // Fonte à esquerda e núcleo à direita.
    let sy = gy + Cast<Float>(sys.GetCircuitSrcRow()) * step + cell / 2.0;
    NWInk.Rect(m, 470.0, sy - 12.0, 30.0, 24.0, NWTheme.Cyan(), 1.0);
    NWInk.Text(m, 466.0, sy + 14.0, NWL.T("FONTE", "SOURCE"), 11, NWTheme.Cyan(), n"Semi-Bold");
    let dx = gx + Cast<Float>(size) * step;
    let dy = gy + Cast<Float>(sys.GetCircuitDstRow()) * step + cell / 2.0;
    NWInk.Rect(m, dx, dy - 16.0, 32.0, 32.0, NWTheme.Yellow(), 0.9);
    NWInk.Text(m, dx - 4.0, dy + 18.0, NWL.T("NÚCLEO", "CORE"), 11, NWTheme.Yellow(), n"Semi-Bold");

    NWInk.Text(m, rx, 216.0, NWL.T("O tempo começa no 1º giro.", "The clock starts on the first turn."), 15, NWTheme.Text(), n"Medium");
    NWInk.Text(m, rx, 240.0, NWL.T("Qualquer rota que ligue os dois vale.", "Any route that links both counts."), 15, NWTheme.Text(), n"Medium");
  }

  // Defesa: sequência de códigos para clicar na ordem antes do golpe do ICE.
  private func DrawDefenseBody(m: ref<inkCanvas>, rx: Float) -> Void {
    let sys = this.sys;
    NWInk.Text(m, 484.0, 148.0, NWL.T("DEFESA // O ICE ATACA", "DEFENSE // THE ICE ATTACKS"), 24, NWTheme.Red(), n"Semi-Bold");
    NWInk.Text(m, 484.0, 182.0, NWL.T("Clique nos códigos na ordem mostrada antes do tempo acabar. Cada acerto tira parte do golpe.", "Click the codes in the order shown before time runs out. Each hit takes away part of the blow."), 15, NWTheme.Muted(), n"Medium");

    NWInk.Text(m, 484.0, 214.0, NWText.Upper(sys.GetMiniIceName()), 30, NWTheme.Red(), n"Semi-Bold");

    // Sequência pedida.
    let total = sys.GetDefenseTotal();
    let current = sys.GetDefenseIndex();
    let k = 0;
    while k < total {
      let x = 484.0 + Cast<Float>(k) * 82.0;
      let y = 268.0;
      let mark = sys.GetDefenseMark(k);
      let color = mark == 1 ? NWTheme.Cyan() : (mark == 2 ? NWTheme.Red() : (k == current ? NWTheme.Yellow() : NWTheme.Muted()));
      NWInk.Rect(m, x, y, 72.0, 60.0, color, mark > 0 ? 0.30 : (k == current ? 0.15 : 0.05));
      NWInk.Frame(m, x, y, 72.0, 60.0, color, k == current || mark > 0 ? 1.0 : 0.4);
      NWInk.Text(m, x + 18.0, y + 12.0, sys.GetDefenseSeqText(k), 28, color, n"Semi-Bold");
      k += 1;
    }

    // Botões (6 códigos em ordem embaralhada).
    k = 0;
    while k < 6 {
      let code = sys.GetDefensePoolCode(k);
      let x = 484.0 + Cast<Float>(k % 3) * 136.0;
      let y = 372.0 + Cast<Float>(k / 3) * 84.0;
      NWInk.Rect(m, x, y, 124.0, 72.0, NWTheme.Cyan(), 0.10);
      NWInk.Frame(m, x, y, 124.0, 72.0, NWTheme.Cyan(), 0.8);
      NWInk.Text(m, x + 40.0, y + 18.0, NWBufferGame.CodeText(code), 30, NWTheme.Cyan(), n"Semi-Bold");
      let hit = NWInk.HitArea(m, StringToName(s"mg_def_\(code)"), x, y, 124.0, 72.0);
      hit.RegisterToCallback(n"OnRelease", this, n"OnActionRelease");
      k += 1;
    }

    NWInk.Text(m, rx, 216.0, NWL.T("CÓDIGO ATUAL", "CURRENT CODE"), 15, NWTheme.Muted(), n"Semi-Bold");
    NWInk.Text(m, rx, 236.0, s"\(Min(current + 1, total)) / \(total)", 30, NWTheme.Yellow(), n"Semi-Bold");
  }

  private func SlideLaneY(k: Int32) -> Float {
    // k = 0 zona segura (embaixo), 1..lanes faixas, lanes + 1 saída (em cima).
    return 600.0 - Cast<Float>(k) * 60.0;
  }

  // Slide: corredor de scanners. Feixes, rastro e o V são widgets fixos, só reposicionados no relógio.
  private func DrawSlideBody(m: ref<inkCanvas>, rx: Float) -> Void {
    let sys = this.sys;
    NWInk.Text(m, 484.0, 148.0, NWL.T("SLIDE // CORREDOR DE SCANNERS", "SLIDE // SCANNER CORRIDOR"), 24, NWTheme.Cyan(), n"Semi-Bold");
    NWInk.Text(m, 484.0, 182.0, NWL.T("Avance uma faixa por vez até a SAÍDA. Se o feixe da sua faixa encostar em você, o ICE te vê.", "Move up one lane at a time to the EXIT. If the beam in your lane touches you, the ICE sees you."), 15, NWTheme.Muted(), n"Medium");

    let lanes = sys.GetSlideLanes();
    let x0 = 504.0;
    let w = 380.0;
    // Saída e zona segura.
    let gy = this.SlideLaneY(lanes + 1);
    NWInk.Rect(m, x0, gy, w, 44.0, NWTheme.Cyan(), 0.15);
    NWInk.Frame(m, x0, gy, w, 44.0, NWTheme.Cyan(), 0.9);
    NWInk.Text(m, x0 + 12.0, gy + 10.0, NWL.T("SAÍDA", "EXIT"), 18, NWTheme.Cyan(), n"Semi-Bold");
    let sy = this.SlideLaneY(0);
    NWInk.Rect(m, x0, sy, w, 44.0, NWTheme.Text(), 0.06);
    NWInk.Text(m, x0 + 12.0, sy + 10.0, NWL.T("ZONA SEGURA", "SAFE ZONE"), 16, NWTheme.Muted(), n"Semi-Bold");
    // Coluna do V.
    NWInk.Rect(m, x0 + w * 0.5 - 1.0, gy, 2.0, sy + 44.0 - gy, NWTheme.Cyan(), 0.15);

    ArrayClear(this.slideBeams);
    ArrayClear(this.slideGhosts);
    let k = 1;
    while k <= lanes {
      let y = this.SlideLaneY(k);
      NWInk.Rect(m, x0, y, w, 44.0, NWTheme.Dark(), 0.95);
      NWInk.Frame(m, x0, y, w, 44.0, NWTheme.Red(), 0.25);
      ArrayPush(this.slideBeams, NWInk.Rect(m, x0, y + 2.0, 10.0, 40.0, NWTheme.Red(), 0.9));
      k += 1;
    }
    let runner = NWInk.Rect(m, 0.0, 0.0, 22.0, 22.0, NWTheme.Cyan(), 1.0);
    runner.SetRotation(45.0);
    this.slideRunner = runner;

    let area = NWInk.HitArea(m, n"mg_adv", x0, gy, w, sy + 44.0 - gy);
    area.RegisterToCallback(n"OnRelease", this, n"OnActionRelease");

    // Botão na coluna da direita.
    NWInk.Rect(m, rx, 216.0, 260.0, 64.0, NWTheme.Cyan(), 0.15);
    NWInk.Frame(m, rx, 216.0, 260.0, 64.0, NWTheme.Cyan(), 1.0);
    NWInk.Text(m, rx + 20.0, 230.0, NWL.T("AVANÇAR", "ADVANCE"), 28, NWTheme.Cyan(), n"Semi-Bold");
    let button = NWInk.HitArea(m, n"mg_adv", rx, 216.0, 260.0, 64.0);
    button.RegisterToCallback(n"OnRelease", this, n"OnActionRelease");
    NWInk.Text(m, rx, 290.0, NWL.T("ESPAÇO ou clique no corredor", "SPACE or click the corridor"), 15, NWTheme.Text(), n"Medium");
    this.UpdateSlide();
  }

  private func UpdateSlide() -> Void {
    let sys = this.sys;
    if sys.GetMiniKind() != 4 || !IsDefined(this.slideRunner) {
      return;
    }
    let x0 = 504.0;
    let w = 380.0;
    let half = sys.GetSlideBeamHalf();
    let k = 0;
    while k < ArraySize(this.slideBeams) {
      let beam = this.slideBeams[k];
      if IsDefined(beam) {
        let y = this.SlideLaneY(k + 1);
        let p = sys.GetSlideBeamPos(k);
        beam.SetMargin(inkMargin(x0 + (p - half) * w, y + 2.0, 0.0, 0.0));
        beam.SetSize(Vector2(half * 2.0 * w, 40.0));
        beam.SetOpacity(sys.IsSlideBeamOn(k) ? 0.9 : 0.15);
      }
      if k < ArraySize(this.slideGhosts) && IsDefined(this.slideGhosts[k]) {
        let gp = sys.GetSlideGhostPos(k);
        this.slideGhosts[k].SetMargin(inkMargin(x0 + (gp - half) * w, this.SlideLaneY(k + 1) + 36.0, 0.0, 0.0));
        this.slideGhosts[k].SetSize(Vector2(half * 2.0 * w, 6.0));
      }
      k += 1;
    }
    let lane = sys.GetSlideLane();
    this.slideRunner.SetMargin(inkMargin(x0 + w * 0.5 - 11.0, this.SlideLaneY(lane) + 11.0, 0.0, 0.0));
  }

  private func ZapCenterX() -> Float { return 692.0; }
  private func ZapCenterY() -> Float { return 448.0; }
  private func ZapRadius() -> Float { return 150.0; }

  // Zap: anel de 48 segmentos (zona em amarelo, crítico em vermelho) e marcador girando.
  private func DrawZapBody(m: ref<inkCanvas>, rx: Float) -> Void {
    let sys = this.sys;
    NWInk.Text(m, 484.0, 148.0, NWL.T("ZAP // RITMO NO ANEL", "ZAP // RING RHYTHM"), 24, NWTheme.Cyan(), n"Semi-Bold");
    NWInk.Text(m, 484.0, 182.0, NWL.T("Ataque quando o marcador passar pela zona: centro vermelho = crítico, amarelo = acerto.", "Strike when the marker crosses the zone: red center = critical, yellow = hit."), 15, NWTheme.Muted(), n"Medium");

    let cx = this.ZapCenterX();
    let cy = this.ZapCenterY();
    let r = this.ZapRadius();
    let k = 0;
    while k < 48 {
      let a = Cast<Float>(k) * 7.5;
      let rad = Deg2Rad(a);
      let zone = sys.GetZapZoneAt(a);
      let color = zone == 2 ? NWTheme.Red() : (zone == 1 ? NWTheme.Yellow() : NWTheme.Cyan());
      let seg = NWInk.Rect(m, cx + CosF(rad) * r - 9.0, cy + SinF(rad) * r - 4.0, 18.0, 8.0, color, zone > 0 ? 1.0 : 0.25);
      seg.SetRotation(a + 90.0);
      k += 1;
    }

    // ICE no centro do anel.
    NWInk.Text(m, cx - 80.0, cy - 30.0, NWText.Upper(sys.GetMiniIceName()), 22, NWTheme.Red(), n"Semi-Bold");
    NWInk.Text(m, cx - 80.0, cy + 2.0, sys.GetMiniIceRezText(), 18, NWTheme.Muted(), n"Medium");

    let marker = NWInk.Rect(m, 0.0, 0.0, 34.0, 14.0, NWTheme.Text(), 1.0);
    this.zapMarker = marker;

    // Clicar em qualquer lugar do anel também ataca.
    let ring = NWInk.HitArea(m, n"mg_zap", cx - r - 30.0, cy - r - 30.0, (r + 30.0) * 2.0, (r + 30.0) * 2.0);
    ring.RegisterToCallback(n"OnRelease", this, n"OnActionRelease");

    // Botão e voltas na coluna da direita.
    NWInk.Rect(m, rx, 216.0, 260.0, 64.0, NWTheme.Red(), 0.20);
    NWInk.Frame(m, rx, 216.0, 260.0, 64.0, NWTheme.Red(), 1.0);
    NWInk.Text(m, rx + 24.0, 228.0, NWL.T("ZAP!", "ZAP!"), 32, NWTheme.Red(), n"Semi-Bold");
    NWInk.Text(m, rx + 110.0, 238.0, NWL.T("ESPAÇO ou clique", "SPACE or click"), 16, NWTheme.Text(), n"Medium");
    let button = NWInk.HitArea(m, n"mg_zap", rx, 216.0, 260.0, 64.0);
    button.RegisterToCallback(n"OnRelease", this, n"OnActionRelease");
    NWInk.Text(m, rx, 300.0, NWL.T("VOLTAS RESTANTES", "LAPS LEFT"), 15, NWTheme.Muted(), n"Semi-Bold");
    this.zapLapsText = NWInk.Text(m, rx, 320.0, "", 26, NWTheme.Yellow(), n"Semi-Bold");
    this.UpdateZapMarker();
  }

  private func UpdateZapMarker() -> Void {
    let sys = this.sys;
    if !IsDefined(this.zapMarker) || sys.GetMiniKind() != 3 {
      return;
    }
    let a = sys.GetZapAngle();
    let rad = Deg2Rad(a);
    let r = this.ZapRadius() + 2.0;
    this.zapMarker.SetMargin(inkMargin(this.ZapCenterX() + CosF(rad) * r - 17.0, this.ZapCenterY() + SinF(rad) * r - 7.0, 0.0, 0.0));
    this.zapMarker.SetRotation(a + 90.0);
    // Marcador acende dentro da zona (mesma regra usada no acerto).
    let zone = sys.GetZapZoneAt(a);
    this.zapMarker.SetTintColor(zone == 2 ? NWTheme.Red() : (zone == 1 ? NWTheme.Yellow() : NWTheme.Text()));
    if IsDefined(this.zapLapsText) {
      this.zapLapsText.SetText(s"\(sys.GetZapLapsLeft()) / \(sys.GetZapLaps())");
    }
  }

  private func UpdateMiniTime() -> Void {
    let sys = this.sys;
    if sys.GetMiniKind() == 3 {
      this.UpdateZapMarker();
      return;
    }
    if sys.GetMiniKind() == 4 {
      this.UpdateSlide();
    }
    if sys.GetMiniKind() == 7 {
      this.UpdateSonar();
      return;
    }
    if !IsDefined(this.miniTimeText) || !sys.HasMiniGame() {
      return;
    }
    let left = sys.GetMiniTimeLeft();
    let tenths = RoundF(left * 10.0);
    let text = s"\(tenths / 10).\(tenths % 10) s";
    if !sys.IsMiniStarted() {
      text = text + NWL.T("  · começa na 1ª escolha", "  · starts on the first pick");
    }
    this.miniTimeText.SetText(text);
    this.miniTimeBar.SetSize(Vector2(420.0 * left / MaxF(0.1, sys.GetMiniTimeLimit()), 8.0));
  }

  private func StartTicker() -> Void {
    if IsDefined(this.tickProxy) && this.tickProxy.IsPlaying() {
      return;
    }
    let anim = new inkAnimDef();
    let alpha = new inkAnimTransparency();
    alpha.SetStartTransparency(0.0);
    alpha.SetEndTransparency(0.0);
    alpha.SetDuration(this.sys.GetMiniTickInterval());
    anim.AddInterpolator(alpha);
    let options: inkAnimOptions;
    options.loopType = inkanimLoopType.Cycle;
    options.loopInfinite = true;
    this.tickProxy = this.ticker.PlayAnimationWithOptions(anim, options);
    this.tickProxy.RegisterToCallback(inkanimEventType.OnEndLoop, this, n"OnMiniTick");
  }

  private func StopTicker() -> Void {
    if IsDefined(this.tickProxy) {
      this.tickProxy.UnregisterFromAllCallbacks(inkanimEventType.OnEndLoop);
      this.tickProxy.Stop(true);
      this.tickProxy = null;
    }
  }

  // Só o painel da tela visível conta o tempo (senão dois relógios andariam no mesmo minigame).
  private func HostShown() -> Bool {
    return (IsDefined(this.breachHost) && this.breachHost.IsShown())
      || (IsDefined(this.tutorialHost) && this.tutorialHost.IsShown());
  }

  protected cb func OnMiniTick(proxy: ref<inkAnimProxy>) -> Bool {
    let sys = this.sys;
    if !IsDefined(sys) || !sys.HasMiniGame() || !this.HostShown() {
      this.StopTicker();
      return false;
    }
    if sys.TickMiniGame(sys.GetMiniTickInterval()) {
      this.StopTicker();
      this.NotifyHost();
      return true;
    }
    this.UpdateMiniTime();
    return true;
  }

}
