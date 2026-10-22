// NET War — minigame da defesa contra o ataque do Black ICE (fim de turno): reflexo.
// Uma sequência de códigos aparece; o jogador clica nos botões na mesma ordem antes do tempo.
// Cada código certo tira uma parte do golpe; todos certos = esquiva total. Erro ou tempo
// esgotado contam como falha naquele código. O tempo corre desde o início (é reflexo).
// Só regras: sem UI. O tempo é avançado de fora (Tick), pela tela.
module NetWar.Breach

import NetWar.Data.*

public class NWDefenseParams {
  public let total: Int32;       // códigos na sequência (Ataque do ICE, Interface)
  public let timeLimit: Float;   // Reflexos, cyberdeck, Canto Mk.6
  public let bodyCut: Int32;     // dano a menos quando o golpe passa (Constituição)
  public let notes: array<String>;
}

public class NWDefenseGame {
  public let seq: array<Int32>;     // códigos pedidos (0..5, mesmos textos do Backdoor)
  public let pool: array<Int32>;    // ordem dos 6 botões na tela
  public let marks: array<Int32>;   // por código: 0 pendente, 1 certo, 2 errado
  public let index: Int32;
  public let hits: Int32;
  public let timeLimit: Float;
  public let timeLeft: Float;
  public let bodyCut: Int32;
  public let done: Bool;
  public let aborted: Bool;
  public let notes: array<String>;

  public static func Create(p: ref<NWDefenseParams>) -> ref<NWDefenseGame> {
    let g = new NWDefenseGame();
    g.timeLimit = p.timeLimit;
    g.timeLeft = p.timeLimit;
    g.bodyCut = p.bodyCut;
    g.notes = p.notes;
    let k = 0;
    while k < p.total {
      ArrayPush(g.seq, RandRange(0, NWBufferGame.CodeCount()));
      ArrayPush(g.marks, 0);
      k += 1;
    }
    let ids: array<Int32>;
    k = 0;
    while k < NWBufferGame.CodeCount() {
      ArrayPush(ids, k);
      k += 1;
    }
    while ArraySize(ids) > 0 {
      let pick = RandRange(0, ArraySize(ids));
      ArrayPush(g.pool, ids[pick]);
      ArrayErase(ids, pick);
    }
    return g;
  }

  public func IsRunning() -> Bool {
    return !this.done;
  }

  public func Total() -> Int32 {
    return ArraySize(this.seq);
  }

  public func Choose(code: Int32) -> Void {
    if this.done {
      return;
    }
    if this.seq[this.index] == code {
      this.marks[this.index] = 1;
      this.hits += 1;
    } else {
      this.marks[this.index] = 2;
    }
    this.index += 1;
    if this.index >= ArraySize(this.seq) {
      this.done = true;
    }
  }

  private func FailRest() -> Void {
    while this.index < ArraySize(this.seq) {
      this.marks[this.index] = 2;
      this.index += 1;
    }
    this.done = true;
  }

  public func Tick(dt: Float) -> Void {
    if this.done {
      return;
    }
    this.timeLeft = MaxF(0.0, this.timeLeft - dt);
    if this.timeLeft <= 0.0 {
      this.FailRest();
    }
  }

  public func Abort() -> Void {
    if !this.done {
      this.aborted = true;
      this.FailRest();
    }
  }
}
