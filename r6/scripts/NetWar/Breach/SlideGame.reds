// NET War — minigame do Slide: corredor de scanners (tempo real, estilo Frogger).
// O V sai da zona segura de baixo e atravessa faixas até a saída no topo. Em cada faixa um feixe
// do ICE vai e volta na horizontal; o V fica sempre na coluna do meio. Avançar é um clique (ou
// ESPAÇO). Ser tocado pelo feixe da faixa onde o V está = visto. O que está na tela é o que vale:
// a colisão é verificada nas mesmas posições desenhadas, a cada passo do relógio.
// Versão anterior (grade por turnos com "próximo olhar") foi trocada a pedido do usuário em
// 2026-10-19 por ser contraintuitiva.
// Só regras: sem UI. O tempo é avançado de fora (Tick), pela tela.
module NetWar.Breach

import NetWar.Data.*

public abstract class NWSlideResult {
  public static func Running() -> Int32 { return 0; }
  public static func Escaped() -> Int32 { return 1; }
  public static func Detected() -> Int32 { return 2; }
  public static func TimeOut() -> Int32 { return 3; }
  public static func Aborted() -> Int32 { return 4; }
}

public class NWSlideParams {
  public let lanes: Int32;        // faixas (Interface)
  public let speed: Float;        // larguras de faixa por segundo (Percepção do ICE, Sangue-frio)
  public let beamHalf: Float;     // meia largura do feixe, em fração da faixa (Percepção do ICE)
  public let ghost: Bool;         // Inteligência: mostra onde o feixe vai estar em 0,5 s
  public let blink: Bool;         // Camuflagem/Fantasma: feixe desliga parte do tempo
  public let timeLimit: Float;    // cyberdeck, Canto Mk.6
  public let notes: array<String>;
}

public class NWSlideGame {
  public let lanes: Int32;
  public let pos: array<Float>;     // posição do centro de cada feixe (0..1)
  public let dir: array<Float>;     // +1 ou −1
  public let speed: array<Float>;
  public let beamHalf: Float;
  public let ghost: Bool;
  public let blink: Bool;
  public let clock: Float;
  public let lane: Int32;           // 0 = zona segura de baixo; 1..lanes = faixas; lanes + 1 = saída
  public let timeLimit: Float;
  public let timeLeft: Float;
  public let result: Int32;
  public let notes: array<String>;

  // O V ocupa a coluna do meio, com esta meia largura.
  public static func RunnerHalf() -> Float { return 0.04; }
  // Feixe piscando: desligado durante esta fração de cada ciclo de 1,2 s.
  public static func BlinkOff() -> Float { return 0.4; }

  public static func Create(p: ref<NWSlideParams>) -> ref<NWSlideGame> {
    let g = new NWSlideGame();
    g.lanes = Clamp(p.lanes, 2, 6);
    g.beamHalf = p.beamHalf;
    g.ghost = p.ghost;
    g.blink = p.blink;
    g.timeLimit = p.timeLimit;
    g.timeLeft = p.timeLimit;
    g.notes = p.notes;
    g.result = NWSlideResult.Running();
    let k = 0;
    while k < g.lanes {
      // Começa longe do meio, para a primeira entrada exigir esperar a hora certa.
      let start = RandRange(0, 2) == 0 ? 0.08 + RandRangeF(0.0, 0.2) : 0.72 + RandRangeF(0.0, 0.2);
      ArrayPush(g.pos, start);
      ArrayPush(g.dir, RandRange(0, 2) == 0 ? 1.0 : -1.0);
      ArrayPush(g.speed, p.speed * RandRangeF(0.8, 1.2));
      k += 1;
    }
    return g;
  }

  public func IsRunning() -> Bool {
    return this.result == NWSlideResult.Running();
  }

  public func IsBeamOn(k: Int32) -> Bool {
    if !this.blink {
      return true;
    }
    // Cada faixa pisca com uma defasagem própria.
    let phase = this.clock + Cast<Float>(k) * 0.37;
    let cycle = phase - Cast<Float>(FloorF(phase / 1.2)) * 1.2;
    return cycle >= 1.2 * NWSlideGame.BlinkOff();
  }

  // Posição do feixe daqui a dt segundos, com o vai e volta (para o rastro da Inteligência).
  public func FuturePos(k: Int32, dt: Float) -> Float {
    let p = this.pos[k];
    let d = this.dir[k];
    let left = this.speed[k] * dt;
    let guard = 0;
    while left > 0.0 && guard < 8 {
      let room = d > 0.0 ? 1.0 - p : p;
      if left <= room {
        p += d * left;
        left = 0.0;
      } else {
        p = d > 0.0 ? 1.0 : 0.0;
        left -= room;
        d = -d;
      }
      guard += 1;
    }
    return p;
  }

  // Move o feixe quicando nas bordas (posição e direção juntas).
  private func StepBeam(k: Int32, dt: Float) -> Void {
    let left = this.speed[k] * dt;
    let guard = 0;
    while left > 0.0 && guard < 8 {
      let room = this.dir[k] > 0.0 ? 1.0 - this.pos[k] : this.pos[k];
      if left <= room {
        this.pos[k] += this.dir[k] * left;
        left = 0.0;
      } else {
        this.pos[k] = this.dir[k] > 0.0 ? 1.0 : 0.0;
        left -= room;
        this.dir[k] = -this.dir[k];
      }
      guard += 1;
    }
  }

  public func Touches(k: Int32) -> Bool {
    return this.IsBeamOn(k) && AbsF(this.pos[k] - 0.5) < this.beamHalf + NWSlideGame.RunnerHalf();
  }

  private func CheckSeen() -> Void {
    if this.lane >= 1 && this.lane <= this.lanes && this.Touches(this.lane - 1) {
      this.result = NWSlideResult.Detected();
    }
  }

  public func Advance() -> Void {
    if !this.IsRunning() {
      return;
    }
    this.lane += 1;
    if this.lane > this.lanes {
      this.result = NWSlideResult.Escaped();
      return;
    }
    this.CheckSeen();
  }

  public func Tick(dt: Float) -> Void {
    if !this.IsRunning() {
      return;
    }
    this.clock += dt;
    let k = 0;
    while k < this.lanes {
      this.StepBeam(k, dt);
      k += 1;
    }
    this.CheckSeen();
    if !this.IsRunning() {
      return;
    }
    this.timeLeft = MaxF(0.0, this.timeLeft - dt);
    if this.timeLeft <= 0.0 {
      this.result = NWSlideResult.TimeOut();
    }
  }

  public func Abort() -> Void {
    if this.IsRunning() {
      this.result = NWSlideResult.Aborted();
    }
  }
}
