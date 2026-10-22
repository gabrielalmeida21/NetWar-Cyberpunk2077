// NET War — minigame do Zap: ritmo no anel.
// Um marcador gira em volta do Black ICE; o jogador ataca quando ele passa pela zona vulnerável.
// Centro da zona = crítico (dano máximo), borda = acerto, fora = erro. Se as voltas acabarem
// sem ataque, conta como erro. O acerto é avaliado na posição desenhada (a mesma que o jogador vê).
// Só regras: sem UI. O tempo é avançado de fora (Tick), pela tela.
module NetWar.Breach

import NetWar.Data.*

public abstract class NWZapResult {
  public static func Running() -> Int32 { return 0; }
  public static func Critical() -> Int32 { return 1; }
  public static func Hit() -> Int32 { return 2; }
  public static func Miss() -> Int32 { return 3; }
  public static func OutOfLaps() -> Int32 { return 4; }
  public static func Aborted() -> Int32 { return 5; }
}

public class NWZapParams {
  public let zoneHalf: Float;   // meia largura da zona, em graus
  public let speed: Float;      // graus por segundo
  public let laps: Int32;       // voltas antes de errar por omissão
  public let double: Bool;      // Lâmina: segunda zona do lado oposto
  public let notes: array<String>;
}

public class NWZapGame {
  public let angle: Float;
  public let zoneCenter: Float;
  public let zoneHalf: Float;
  public let speed: Float;
  public let double: Bool;
  public let laps: Int32;
  public let traveled: Float;
  public let result: Int32;
  public let notes: array<String>;

  // Fração da meia largura que conta como crítico.
  public static func CriticalShare() -> Float { return 0.4; }

  public static func Create(p: ref<NWZapParams>) -> ref<NWZapGame> {
    let g = new NWZapGame();
    g.zoneHalf = p.zoneHalf;
    g.speed = p.speed;
    g.laps = Max(1, p.laps);
    g.double = p.double;
    g.notes = p.notes;
    g.result = NWZapResult.Running();
    g.zoneCenter = Cast<Float>(RandRange(0, 360));
    // Começa longe da zona, para o primeiro acerto exigir esperar o marcador chegar.
    g.angle = NWZapGame.Wrap(g.zoneCenter + 120.0 + Cast<Float>(RandRange(0, 60)));
    return g;
  }

  public static func Wrap(a: Float) -> Float {
    let v = a;
    while v >= 360.0 {
      v -= 360.0;
    }
    while v < 0.0 {
      v += 360.0;
    }
    return v;
  }

  public static func Distance(a: Float, b: Float) -> Float {
    let d = AbsF(NWZapGame.Wrap(a) - NWZapGame.Wrap(b));
    return d > 180.0 ? 360.0 - d : d;
  }

  public func IsRunning() -> Bool {
    return this.result == NWZapResult.Running();
  }

  // 0 fora, 1 acerto, 2 crítico, para um ângulo qualquer (também usado para desenhar a zona).
  public func ZoneAt(a: Float) -> Int32 {
    let d = NWZapGame.Distance(a, this.zoneCenter);
    if this.double {
      d = MinF(d, NWZapGame.Distance(a, this.zoneCenter + 180.0));
    }
    if d <= this.zoneHalf * NWZapGame.CriticalShare() {
      return 2;
    }
    return d <= this.zoneHalf ? 1 : 0;
  }

  public func LapsLeft() -> Int32 {
    return Max(0, this.laps - Cast<Int32>(this.traveled / 360.0));
  }

  public func Tick(dt: Float) -> Void {
    if !this.IsRunning() {
      return;
    }
    let step = this.speed * dt;
    this.angle = NWZapGame.Wrap(this.angle + step);
    this.traveled += step;
    if this.traveled >= Cast<Float>(this.laps) * 360.0 {
      this.result = NWZapResult.OutOfLaps();
    }
  }

  public func Strike() -> Void {
    if !this.IsRunning() {
      return;
    }
    switch this.ZoneAt(this.angle) {
      case 2: this.result = NWZapResult.Critical(); break;
      case 1: this.result = NWZapResult.Hit(); break;
      default: this.result = NWZapResult.Miss(); break;
    }
  }

  public func Abort() -> Void {
    if this.IsRunning() {
      this.result = NWZapResult.Aborted();
    }
  }
}
