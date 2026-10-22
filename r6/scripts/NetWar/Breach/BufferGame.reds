// NET War — minigame do Backdoor: sequência de buffer (estilo Breach Protocol).
// Grade de códigos; a 1ª escolha é na linha de cima, depois alterna coluna da última escolha /
// linha da última escolha. Vence quando a sequência pedida aparece em ordem, contígua, no buffer.
// A dificuldade vem de NWMiniParams (Interface, atributos, cyberdeck, daemons; ver NetWarSystem).
// Só regras: sem UI. O tempo é avançado de fora (Tick), pela tela.
module NetWar.Breach

import NetWar.Data.*

public abstract class NWBufferResult {
  public static func Running() -> Int32 { return 0; }
  public static func Success() -> Int32 { return 1; }
  public static func TimeOut() -> Int32 { return 2; }
  public static func BufferFull() -> Int32 { return 3; }
  public static func Aborted() -> Int32 { return 4; }
}

// Parâmetros de um minigame, calculados pelo NetWarSystem a partir do V e da sessão.
public class NWMiniParams {
  public let seqLen: Int32;
  public let size: Int32;
  public let bufferMax: Int32;
  public let timeLimit: Float;
  public let hints: Int32;       // quantos passos da sequência mostram as células certas
  public let fullHints: Bool;    // Verme: todos os passos
  public let truePath: Bool;     // Canto Mk.6: mostra a próxima casa do caminho que fecha mais rápido
  // Linhas explicando o que ajudou (mostradas na tela).
  public let notes: array<String>;
}

public class NWBufferGame {
  public let size: Int32;
  public let codes: array<Int32>;   // índice r * size + c
  public let used: array<Bool>;
  public let seq: array<Int32>;
  public let picks: array<Int32>;   // células escolhidas, em ordem
  public let bufferMax: Int32;
  public let timeLimit: Float;
  public let timeLeft: Float;
  public let started: Bool;
  public let hints: Int32;
  public let fullHints: Bool;
  public let truePath: Bool;
  public let bestNext: Int32;      // próxima casa do caminho mais curto até completar (−1 = nenhum)
  public let result: Int32;
  public let notes: array<String>;

  public static func CodeCount() -> Int32 { return 6; }

  public static func CodeText(id: Int32) -> String {
    switch id {
      case 0: return "1C";
      case 1: return "55";
      case 2: return "BD";
      case 3: return "E9";
      case 4: return "7A";
      default: return "FF";
    }
  }

  public static func Create(p: ref<NWMiniParams>) -> ref<NWBufferGame> {
    let g = new NWBufferGame();
    g.size = p.size;
    g.bufferMax = p.bufferMax;
    g.timeLimit = p.timeLimit;
    g.timeLeft = p.timeLimit;
    g.hints = p.hints;
    g.fullHints = p.fullHints;
    g.truePath = p.truePath;
    g.bestNext = -1;
    g.notes = p.notes;
    g.result = NWBufferResult.Running();
    let n = g.size * g.size;
    let k = 0;
    while k < n {
      ArrayPush(g.codes, RandRange(0, NWBufferGame.CodeCount()));
      ArrayPush(g.used, false);
      k += 1;
    }
    k = 0;
    while k < p.seqLen {
      ArrayPush(g.seq, RandRange(0, NWBufferGame.CodeCount()));
      k += 1;
    }
    g.EmbedSolution();
    g.UpdateBestNext();
    return g;
  }

  // Garante uma solução: escreve a sequência num caminho válido (linha 0, coluna, linha...).
  private func EmbedSolution() -> Void {
    let taken: array<Int32>;
    let row = 0;
    let col = RandRange(0, this.size);
    let k = 0;
    while k < ArraySize(this.seq) {
      if k > 0 {
        let options: array<Int32>;
        let t = 0;
        while t < this.size {
          let cell = k % 2 == 1 ? t * this.size + col : row * this.size + t;
          if !ArrayContains(taken, cell) {
            ArrayPush(options, t);
          }
          t += 1;
        }
        let pick = options[RandRange(0, ArraySize(options))];
        if k % 2 == 1 {
          row = pick;
        } else {
          col = pick;
        }
      }
      let cell = row * this.size + col;
      ArrayPush(taken, cell);
      this.codes[cell] = this.seq[k];
      k += 1;
    }
  }

  public func IsRunning() -> Bool {
    return this.result == NWBufferResult.Running();
  }

  // Linha ativa: escolha par = linha (da última escolha; a 1ª é a linha 0), ímpar = coluna da última.
  public func IsRowTurn() -> Bool {
    return ArraySize(this.picks) % 2 == 0;
  }

  public func ActiveIndex() -> Int32 {
    let count = ArraySize(this.picks);
    if count == 0 {
      return 0;
    }
    let last = this.picks[count - 1];
    return this.IsRowTurn() ? last / this.size : last % this.size;
  }

  public func InActiveLine(cell: Int32) -> Bool {
    let r = cell / this.size;
    let c = cell % this.size;
    return this.IsRowTurn() ? r == this.ActiveIndex() : c == this.ActiveIndex();
  }

  public func CanPick(cell: Int32) -> Bool {
    return this.IsRunning() && cell >= 0 && cell < ArraySize(this.codes) && !this.used[cell] && this.InActiveLine(cell);
  }

  // Quantos símbolos da sequência o fim do buffer já cobre (maior sufixo = prefixo da sequência).
  public func Matched() -> Int32 {
    let count = ArraySize(this.picks);
    let best = Min(count, ArraySize(this.seq));
    while best > 0 {
      let ok = true;
      let i = 0;
      while i < best && ok {
        if this.codes[this.picks[count - best + i]] != this.seq[i] {
          ok = false;
        }
        i += 1;
      }
      if ok {
        return best;
      }
      best -= 1;
    }
    return 0;
  }

  // Dica: célula escolhível com o próximo código da sequência (INT dá dicas nos primeiros passos).
  public func IsHint(cell: Int32) -> Bool {
    if !this.CanPick(cell) {
      return false;
    }
    let m = this.Matched();
    if m >= ArraySize(this.seq) || (!this.fullHints && m >= this.hints) {
      return false;
    }
    return this.codes[cell] == this.seq[m];
  }

  // ------------------------------------------------------------ caminho verdadeiro (Canto Mk.6)
  // Aprofundamento iterativo: tenta completar com o menor número de escolhas (mínimo = códigos
  // que faltam, até 2 de folga e sem passar do buffer). Testa primeiro as casas com o código certo.
  // Corta ramos em que sobram menos escolhas do que códigos faltando.

  public func IsBestNext(cell: Int32) -> Bool {
    return this.truePath && this.IsRunning() && cell == this.bestNext;
  }

  private func UpdateBestNext() -> Void {
    this.bestNext = -1;
    if !this.truePath || !this.IsRunning() {
      return;
    }
    let need = ArraySize(this.seq) - this.Matched();
    let room = this.bufferMax - ArraySize(this.picks);
    let depth = need;
    while depth <= Min(room, need + 2) && this.bestNext < 0 {
      this.bestNext = this.FirstMoveWithin(depth);
      depth += 1;
    }
  }

  private func FirstMoveWithin(depth: Int32) -> Int32 {
    let pass = 0;
    while pass < 2 {
      let cell = 0;
      while cell < ArraySize(this.codes) {
        let isMatch = this.codes[cell] == this.seq[this.Matched()];
        if this.CanPick(cell) && ((pass == 0 && isMatch) || (pass == 1 && !isMatch)) {
          this.used[cell] = true;
          ArrayPush(this.picks, cell);
          let ok = this.CompletesWithin(depth - 1);
          ArrayPop(this.picks);
          this.used[cell] = false;
          if ok {
            return cell;
          }
        }
        cell += 1;
      }
      pass += 1;
    }
    return -1;
  }

  private func CompletesWithin(depth: Int32) -> Bool {
    let m = this.Matched();
    if m >= ArraySize(this.seq) {
      return true;
    }
    if depth <= 0 || ArraySize(this.seq) - m > depth {
      return false;
    }
    let pass = 0;
    while pass < 2 {
      let cell = 0;
      while cell < ArraySize(this.codes) {
        let isMatch = this.codes[cell] == this.seq[m];
        if this.CanPick(cell) && ((pass == 0 && isMatch) || (pass == 1 && !isMatch)) {
          this.used[cell] = true;
          ArrayPush(this.picks, cell);
          let ok = this.CompletesWithin(depth - 1);
          ArrayPop(this.picks);
          this.used[cell] = false;
          if ok {
            return true;
          }
        }
        cell += 1;
      }
      pass += 1;
    }
    return false;
  }

  public func Pick(cell: Int32) -> Bool {
    if !this.CanPick(cell) {
      return false;
    }
    this.started = true;
    this.used[cell] = true;
    ArrayPush(this.picks, cell);
    if this.Matched() >= ArraySize(this.seq) {
      this.result = NWBufferResult.Success();
    } else {
      if ArraySize(this.picks) >= this.bufferMax || !this.HasAnyMove() {
        this.result = NWBufferResult.BufferFull();
      }
    }
    this.UpdateBestNext();
    return true;
  }

  private func HasAnyMove() -> Bool {
    let k = 0;
    while k < ArraySize(this.codes) {
      if this.CanPick(k) {
        return true;
      }
      k += 1;
    }
    return false;
  }

  // O tempo só corre depois da primeira escolha (como no Breach Protocol do jogo).
  public func Tick(dt: Float) -> Void {
    if !this.IsRunning() || !this.started {
      return;
    }
    this.timeLeft = MaxF(0.0, this.timeLeft - dt);
    if this.timeLeft <= 0.0 {
      this.result = NWBufferResult.TimeOut();
    }
  }

  public func Abort() -> Void {
    if this.IsRunning() {
      this.result = NWBufferResult.Aborted();
    }
  }
}
