// NET War — minigame do Eye-Dee: decifrar o cabeçalho do arquivo.
// O cabeçalho é uma corrente de blocos de 2 caracteres em que cada bloco começa com o caractere
// em que o anterior terminou (4A → A7 → 7E → E2). A tela mostra o caractere de início e o de fim.
// Blocos corrompidos começam com o caractere certo mas levam a um beco sem saída (o 2º caractere
// não continua nenhum bloco): olhar um passo à frente resolve. 3 erros corrompem o arquivo.
// Só regras: sem UI. O tempo é avançado de fora (Tick), pela tela.
module NetWar.Breach

import NetWar.Data.*

public abstract class NWHeaderResult {
  public static func Running() -> Int32 { return 0; }
  public static func Success() -> Int32 { return 1; }
  public static func TimeOut() -> Int32 { return 2; }
  public static func Corrupted() -> Int32 { return 3; }
  public static func Aborted() -> Int32 { return 4; }
}

public class NWHeaderParams {
  public let chainLen: Int32;     // blocos da corrente
  public let decoys: Int32;       // blocos corrompidos
  public let preplaced: Int32;    // blocos já encaixados (cyberdeck)
  public let hints: Int32;        // passos com o próximo bloco destacado (INT)
  public let freeErrors: Int32;   // erros sem rastreio (Hab. técnica)
  public let startOnClick: Bool;  // Cool: o tempo só corre depois do 1º clique
  public let timeLimit: Float;
  public let notes: array<String>;
}

public class NWHeaderGame {
  public let first: array<Int32>;   // 1º caractere de cada bloco (0..15)
  public let second: array<Int32>;  // 2º caractere
  public let decoy: array<Bool>;
  public let gone: array<Bool>;     // encaixado, ou corrompido já descartado
  public let order: array<Int32>;   // blocos encaixados, em ordem
  public let chainLen: Int32;
  public let startChar: Int32;
  public let endChar: Int32;
  public let errors: Int32;
  public let freeErrors: Int32;
  public let maxErrors: Int32;
  public let hints: Int32;
  public let preplaced: Int32;
  public let timeLimit: Float;
  public let timeLeft: Float;
  public let started: Bool;
  public let result: Int32;
  public let lastWrong: Int32;      // último bloco errado (para a tela marcar)
  public let notes: array<String>;

  public static func CharText(c: Int32) -> String {
    switch c {
      case 10: return "A";
      case 11: return "B";
      case 12: return "C";
      case 13: return "D";
      case 14: return "E";
      case 15: return "F";
      default: return IntToString(c);
    }
  }

  public func BlockText(b: Int32) -> String {
    return NWHeaderGame.CharText(this.first[b]) + NWHeaderGame.CharText(this.second[b]);
  }

  public static func Create(p: ref<NWHeaderParams>) -> ref<NWHeaderGame> {
    let g = new NWHeaderGame();
    g.chainLen = p.chainLen;
    g.hints = p.hints;
    g.freeErrors = p.freeErrors;
    g.maxErrors = 3;
    g.timeLimit = p.timeLimit;
    g.timeLeft = p.timeLimit;
    g.started = !p.startOnClick;
    g.notes = p.notes;
    g.lastWrong = -1;
    g.result = NWHeaderResult.Running();

    // Caracteres da corrente, todos diferentes: c0 → c1 → ... → cN.
    let pool: array<Int32>;
    let k = 0;
    while k < 16 {
      ArrayPush(pool, k);
      k += 1;
    }
    let chain: array<Int32>;
    k = 0;
    while k <= g.chainLen {
      let pick = RandRange(0, ArraySize(pool));
      ArrayPush(chain, pool[pick]);
      ArrayErase(pool, pick);
      k += 1;
    }
    g.preplaced = Clamp(p.preplaced, 0, g.chainLen - 2);
    g.startChar = chain[0];
    g.endChar = chain[g.chainLen];

    // Blocos verdadeiros e corrompidos (2º caractere fora da corrente: beco sem saída).
    let firsts: array<Int32>;
    let seconds: array<Int32>;
    let decoys: array<Bool>;
    k = 0;
    while k < g.chainLen {
      ArrayPush(firsts, chain[k]);
      ArrayPush(seconds, chain[k + 1]);
      ArrayPush(decoys, false);
      k += 1;
    }
    k = 0;
    while k < p.decoys && ArraySize(pool) > 0 {
      // Corrompido num passo depois dos já encaixados, para sempre ser uma armadilha real.
      let step = RandRange(g.preplaced, g.chainLen);
      let pick = RandRange(0, ArraySize(pool));
      ArrayPush(firsts, chain[step]);
      ArrayPush(seconds, pool[pick]);
      ArrayErase(pool, pick);
      ArrayPush(decoys, true);
      k += 1;
    }

    // Embaralha a ordem de exibição.
    let n = ArraySize(firsts);
    let idx: array<Int32>;
    k = 0;
    while k < n {
      ArrayPush(idx, k);
      k += 1;
    }
    while ArraySize(idx) > 0 {
      let pick = RandRange(0, ArraySize(idx));
      let src = idx[pick];
      ArrayErase(idx, pick);
      ArrayPush(g.first, firsts[src]);
      ArrayPush(g.second, seconds[src]);
      ArrayPush(g.decoy, decoys[src]);
      ArrayPush(g.gone, false);
    }

    // Cyberdeck: primeiros blocos já encaixados.
    k = 0;
    while k < g.preplaced {
      g.PlaceCorrect();
      k += 1;
    }
    return g;
  }

  public func IsRunning() -> Bool {
    return this.result == NWHeaderResult.Running();
  }

  // Caractere que o próximo bloco precisa ter no começo.
  public func Need() -> Int32 {
    let count = ArraySize(this.order);
    return count == 0 ? this.startChar : this.second[this.order[count - 1]];
  }

  public func CorrectNext() -> Int32 {
    let need = this.Need();
    let b = 0;
    while b < ArraySize(this.first) {
      if !this.gone[b] && !this.decoy[b] && this.first[b] == need {
        return b;
      }
      b += 1;
    }
    return -1;
  }

  private func PlaceCorrect() -> Void {
    let b = this.CorrectNext();
    if b >= 0 {
      this.gone[b] = true;
      ArrayPush(this.order, b);
    }
  }

  public func IsHint(b: Int32) -> Bool {
    return this.IsRunning() && ArraySize(this.order) - this.preplaced < this.hints && b == this.CorrectNext();
  }

  public func PaidErrors() -> Int32 {
    return Max(0, this.errors - this.freeErrors);
  }

  // Devolve true se o bloco foi aceito.
  public func Choose(b: Int32) -> Bool {
    if !this.IsRunning() || b < 0 || b >= ArraySize(this.first) || this.gone[b] {
      return false;
    }
    this.started = true;
    if b == this.CorrectNext() {
      this.gone[b] = true;
      ArrayPush(this.order, b);
      this.lastWrong = -1;
      if ArraySize(this.order) >= this.chainLen {
        this.result = NWHeaderResult.Success();
      }
      return true;
    }
    this.errors += 1;
    this.lastWrong = b;
    // Corrompido escolhido some da lista (o jogador aprende que era armadilha).
    if this.decoy[b] {
      this.gone[b] = true;
    }
    if this.errors >= this.maxErrors {
      this.result = NWHeaderResult.Corrupted();
    }
    return false;
  }

  public func Tick(dt: Float) -> Void {
    if !this.IsRunning() || !this.started {
      return;
    }
    this.timeLeft = MaxF(0.0, this.timeLeft - dt);
    if this.timeLeft <= 0.0 {
      this.result = NWHeaderResult.TimeOut();
    }
  }

  public func Abort() -> Void {
    if this.IsRunning() {
      this.result = NWHeaderResult.Aborted();
    }
  }
}
