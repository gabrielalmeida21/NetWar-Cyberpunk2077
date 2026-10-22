// NET War — minigame do Escanear: sonar.
// Cada pulso devolve um eco que encolhe da borda (raio 1) até o centro (raio 0). O jogador clica
// (ou ESPAÇO) quando o eco passa pela faixa-alvo: centro da faixa = perfeito (2 pontos), resto da
// faixa = bom (1), fora ou sem clicar = erro (0). Os pontos decidem quantos andares além da base
// (o atual + 3, como o Escanear do d10) são revelados; atingir a meta revela a torre inteira.
// Não tem falha. Só regras: sem UI. O tempo é avançado de fora (Tick), pela tela.
module NetWar.Breach

import NetWar.Data.*

public class NWSonarParams {
  public let pulses: Int32;       // tentativas (Canto Mk.6 +1)
  public let travel: Float;       // segundos do eco da borda ao centro (Interface, cyberdeck)
  public let bandHalf: Float;     // meia largura da faixa-alvo, em fração do raio (Reflexos)
  public let goal: Int32;         // pontos para revelar tudo (Inteligência baixa a meta)
  public let notes: array<String>;
}

public class NWSonarGame {
  public let pulses: Int32;
  public let current: Int32;
  public let marks: array<Int32>;   // por pulso: 0 pendente, 1 bom, 2 perfeito, 3 erro
  public let radius: Float;
  public let pause: Float;          // intervalo entre pulsos
  public let travel: Float;
  public let bandCenter: Float;
  public let bandHalf: Float;
  public let goal: Int32;
  public let done: Bool;
  public let notes: array<String>;

  // Fração da meia largura que conta como perfeito.
  public static func PerfectShare() -> Float { return 0.4; }

  public static func Create(p: ref<NWSonarParams>) -> ref<NWSonarGame> {
    let g = new NWSonarGame();
    g.pulses = Max(1, p.pulses);
    g.travel = MaxF(0.6, p.travel);
    g.bandHalf = p.bandHalf;
    g.bandCenter = 0.45;
    g.goal = Max(1, p.goal);
    g.notes = p.notes;
    g.radius = 1.0;
    g.pause = 0.6;
    let k = 0;
    while k < g.pulses {
      ArrayPush(g.marks, 0);
      k += 1;
    }
    return g;
  }

  public func IsRunning() -> Bool {
    return !this.done;
  }

  public func Score() -> Int32 {
    let total = 0;
    for m in this.marks {
      if m == 2 { total += 2; }
      if m == 1 { total += 1; }
    }
    return total;
  }

  public func IsWaiting() -> Bool {
    return this.pause > 0.0;
  }

  private func NextPulse(mark: Int32) -> Void {
    this.marks[this.current] = mark;
    this.current += 1;
    if this.current >= this.pulses {
      this.done = true;
      return;
    }
    this.radius = 1.0;
    this.pause = 0.35;
  }

  public func Ping() -> Void {
    if this.done || this.pause > 0.0 {
      return;
    }
    let d = AbsF(this.radius - this.bandCenter);
    if d <= this.bandHalf * NWSonarGame.PerfectShare() {
      this.NextPulse(2);
    } else {
      this.NextPulse(d <= this.bandHalf ? 1 : 3);
    }
  }

  public func Tick(dt: Float) -> Void {
    if this.done {
      return;
    }
    if this.pause > 0.0 {
      this.pause = MaxF(0.0, this.pause - dt);
      return;
    }
    this.radius -= dt / this.travel;
    if this.radius <= 0.0 {
      this.radius = 0.0;
      this.NextPulse(3);
    }
  }

  // Sair da tela: os pulsos restantes contam como erro (o Escanear ainda revela a base).
  public func Abort() -> Void {
    while !this.done {
      this.NextPulse(3);
    }
  }
}
