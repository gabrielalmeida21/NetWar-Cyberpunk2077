// NET War — minigame do Controlar: circuito de energia.
// Grade de peças (reta, curva, T) com a fonte à esquerda e o núcleo à direita. Clicar gira a peça
// 90° no sentido horário. Vence quando existe caminho ligado da fonte ao núcleo (qualquer rota).
// Um caminho é gerado primeiro (busca em profundidade aleatória) e só depois as peças são
// giradas ao acaso, então sempre há solução. Conexões em máscara: N=1, L=2, S=4, O=8.
// Só regras: sem UI. O tempo é avançado de fora (Tick), pela tela.
module NetWar.Breach

import NetWar.Data.*

public abstract class NWCircuitResult {
  public static func Running() -> Int32 { return 0; }
  public static func Linked() -> Int32 { return 1; }
  public static func TimeOut() -> Int32 { return 2; }
  public static func Aborted() -> Int32 { return 3; }
}

public class NWCircuitParams {
  public let size: Int32;        // lado da grade (Interface vs DV)
  public let locked: Int32;      // peças do caminho já travadas (Hab. técnica)
  public let hints: Int32;       // casas do caminho destacadas a partir da fonte (Inteligência)
  public let timeLimit: Float;   // cyberdeck, Canto Mk.6, Sobrecarga
  public let notes: array<String>;
}

public class NWCircuitGame {
  public let size: Int32;
  public let masks: array<Int32>;
  public let locked: array<Bool>;
  public let path: array<Int32>;   // caminho gerado (células), da fonte ao núcleo
  public let srcRow: Int32;
  public let dstRow: Int32;
  public let hints: Int32;
  public let timeLimit: Float;
  public let timeLeft: Float;
  public let started: Bool;
  public let result: Int32;
  public let notes: array<String>;

  public static func Rotate(mask: Int32) -> Int32 {
    // N→L, L→S, S→O, O→N.
    let out = 0;
    if (mask & 1) != 0 { out += 2; }
    if (mask & 2) != 0 { out += 4; }
    if (mask & 4) != 0 { out += 8; }
    if (mask & 8) != 0 { out += 1; }
    return out;
  }

  // Direção (0 N, 1 L, 2 S, 3 O) → bit e oposto.
  public static func Bit(d: Int32) -> Int32 {
    switch d {
      case 0: return 1;
      case 1: return 2;
      case 2: return 4;
      default: return 8;
    }
  }

  public static func Opposite(d: Int32) -> Int32 {
    return (d + 2) % 4;
  }

  public static func Create(p: ref<NWCircuitParams>) -> ref<NWCircuitGame> {
    let g = new NWCircuitGame();
    g.size = Clamp(p.size, 3, 6);
    g.hints = p.hints;
    g.timeLimit = p.timeLimit;
    g.timeLeft = p.timeLimit;
    g.notes = p.notes;
    g.result = NWCircuitResult.Running();
    g.srcRow = RandRange(0, g.size);
    g.dstRow = RandRange(0, g.size);
    let n = g.size * g.size;
    let k = 0;
    while k < n {
      ArrayPush(g.masks, 0);
      ArrayPush(g.locked, false);
      k += 1;
    }
    g.BuildPath();

    // Peças do caminho com as conexões certas.
    let i = 0;
    while i < ArraySize(g.path) {
      let cell = g.path[i];
      let mask = 0;
      if i == 0 {
        mask += NWCircuitGame.Bit(3);          // entra pela fonte (oeste)
      } else {
        mask += NWCircuitGame.Bit(g.DirTo(cell, g.path[i - 1]));
      }
      if i == ArraySize(g.path) - 1 {
        mask += NWCircuitGame.Bit(1);          // sai para o núcleo (leste)
      } else {
        mask += NWCircuitGame.Bit(g.DirTo(cell, g.path[i + 1]));
      }
      g.masks[cell] = mask;
      i += 1;
    }
    // Resto da grade: peças aleatórias (reta, curva ou T).
    k = 0;
    while k < n {
      if !ArrayContains(g.path, k) {
        switch RandRange(0, 3) {
          case 0: g.masks[k] = 1 + 4; break;
          case 1: g.masks[k] = 1 + 2; break;
          default: g.masks[k] = 1 + 2 + 4; break;
        }
      }
      k += 1;
    }
    // Hab. técnica: trava as primeiras peças do caminho já no lugar.
    let lockCount = Min(p.locked, ArraySize(g.path) - 1);
    i = 0;
    while i < lockCount {
      g.locked[g.path[i]] = true;
      i += 1;
    }
    // Embaralha girando cada peça livre de 0 a 3 vezes; garante que não comece resolvido.
    k = 0;
    while k < n {
      if !g.locked[k] {
        let turns = RandRange(0, 4);
        while turns > 0 {
          g.masks[k] = NWCircuitGame.Rotate(g.masks[k]);
          turns -= 1;
        }
      }
      k += 1;
    }
    if g.IsLinked() {
      let free = g.path[ArraySize(g.path) - 1];
      g.masks[free] = NWCircuitGame.Rotate(g.masks[free]);
    }
    return g;
  }

  private func Neighbor(cell: Int32, d: Int32) -> Int32 {
    let r = cell / this.size;
    let c = cell % this.size;
    switch d {
      case 0: r -= 1; break;
      case 1: c += 1; break;
      case 2: r += 1; break;
      default: c -= 1; break;
    }
    if r < 0 || r >= this.size || c < 0 || c >= this.size {
      return -1;
    }
    return r * this.size + c;
  }

  private func Distance(a: Int32, b: Int32) -> Int32 {
    return Abs(a / this.size - b / this.size) + Abs(a % this.size - b % this.size);
  }

  private func DirTo(from: Int32, to: Int32) -> Int32 {
    let d = 0;
    while d < 4 {
      if this.Neighbor(from, d) == to {
        return d;
      }
      d += 1;
    }
    return 0;
  }

  // Caminho aleatório sem repetir casas, da coluna 0 (linha da fonte) à última (linha do núcleo).
  private func BuildPath() -> Void {
    let start = this.srcRow * this.size;
    let goal = this.dstRow * this.size + this.size - 1;
    let visited: array<Bool>;
    let k = 0;
    while k < this.size * this.size {
      ArrayPush(visited, false);
      k += 1;
    }
    ArrayClear(this.path);
    ArrayPush(this.path, start);
    visited[start] = true;
    while ArraySize(this.path) > 0 && this.path[ArraySize(this.path) - 1] != goal {
      let here = this.path[ArraySize(this.path) - 1];
      let options: array<Int32>;
      let closer: array<Int32>;
      let d = 0;
      while d < 4 {
        let next = this.Neighbor(here, d);
        if next >= 0 && !visited[next] {
          ArrayPush(options, next);
          if this.Distance(next, goal) < this.Distance(here, goal) {
            ArrayPush(closer, next);
          }
        }
        d += 1;
      }
      if ArraySize(options) == 0 {
        ArrayPop(this.path);
      } else {
        // 70% das vezes prefere se aproximar do núcleo (sem isso o caminho virava uma "cobra"
        // de até 33 das 36 casas no 6x6; com o viés, média de 10 na simulação).
        let pool = ArraySize(closer) > 0 && RandRange(0, 100) < 70 ? closer : options;
        let next = pool[RandRange(0, ArraySize(pool))];
        visited[next] = true;
        ArrayPush(this.path, next);
      }
    }
  }

  // Casas com energia: a partir da fonte, seguindo conexões dos dois lados.
  public func Powered() -> array<Bool> {
    let on: array<Bool>;
    let k = 0;
    while k < this.size * this.size {
      ArrayPush(on, false);
      k += 1;
    }
    let start = this.srcRow * this.size;
    if (this.masks[start] & NWCircuitGame.Bit(3)) == 0 {
      return on;
    }
    let queue: array<Int32>;
    ArrayPush(queue, start);
    on[start] = true;
    let head = 0;
    while head < ArraySize(queue) {
      let cell = queue[head];
      head += 1;
      let d = 0;
      while d < 4 {
        let next = this.Neighbor(cell, d);
        if next >= 0 && !on[next] && (this.masks[cell] & NWCircuitGame.Bit(d)) != 0
          && (this.masks[next] & NWCircuitGame.Bit(NWCircuitGame.Opposite(d))) != 0 {
          on[next] = true;
          ArrayPush(queue, next);
        }
        d += 1;
      }
    }
    return on;
  }

  public func IsLinked() -> Bool {
    let goal = this.dstRow * this.size + this.size - 1;
    let on = this.Powered();
    return on[goal] && (this.masks[goal] & NWCircuitGame.Bit(1)) != 0;
  }

  public func IsHint(cell: Int32) -> Bool {
    let i = 0;
    while i < this.hints && i < ArraySize(this.path) {
      if this.path[i] == cell {
        return true;
      }
      i += 1;
    }
    return false;
  }

  public func IsRunning() -> Bool {
    return this.result == NWCircuitResult.Running();
  }

  public func Turn(cell: Int32) -> Bool {
    if !this.IsRunning() || cell < 0 || cell >= ArraySize(this.masks) || this.locked[cell] {
      return false;
    }
    this.started = true;
    this.masks[cell] = NWCircuitGame.Rotate(this.masks[cell]);
    if this.IsLinked() {
      this.result = NWCircuitResult.Linked();
    }
    return true;
  }

  // O tempo só corre depois do primeiro giro.
  public func Tick(dt: Float) -> Void {
    if !this.IsRunning() || !this.started {
      return;
    }
    this.timeLeft = MaxF(0.0, this.timeLeft - dt);
    if this.timeLeft <= 0.0 {
      this.result = NWCircuitResult.TimeOut();
    }
  }

  public func Abort() -> Void {
    if this.IsRunning() {
      this.result = NWCircuitResult.Aborted();
    }
  }
}
