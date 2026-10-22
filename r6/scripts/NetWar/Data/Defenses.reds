// NET War — camadas de defesa que o V monta nos próprios nós (aba ARQUITETURAS).
// Cada nó do V tem 3 camadas. Efeito contra os ataques das facções (simulação):
//   Senha     +2 na defesa (permanente)
//   Black ICE +1 na defesa e absorve um ataque bem-sucedido (destruído ao absorver)
//   Isca      35% de desviar o ataque inteiro (permanente; várias iscas acumulam)
module NetWar.Data

public abstract class NWDefense {
  public static func None() -> Int32 { return 0; }
  public static func Password() -> Int32 { return 1; }
  public static func BlackIce() -> Int32 { return 2; }
  public static func Decoy() -> Int32 { return 3; }
  public static func SlotsPerNode() -> Int32 { return 3; }

  public static func Name(t: Int32) -> String {
    switch t {
      case 1: return NWL.T("Senha", "Password");
      case 2: return "Black ICE";
      case 3: return NWL.T("Isca", "Decoy");
      default: return NWL.T("Vazio", "Empty");
    }
  }

  public static func Description(t: Int32) -> String {
    switch t {
      case 1: return NWL.T("+2 na defesa contra ataques", "+2 defense against attacks");
      case 2: return NWL.T("+1 na defesa; absorve um ataque e é destruído", "+1 defense; absorbs one attack and is destroyed");
      case 3: return NWL.T("35% de desviar o ataque inteiro", "35% chance to divert the whole attack");
      default: return NWL.T("Camada livre", "Free layer");
    }
  }

  public static func Cost(t: Int32) -> Int32 {
    switch t {
      case 1: return 1000;
      case 2: return 2500;
      case 3: return 1500;
      default: return 0;
    }
  }

  public static func DefenseBonus(t: Int32) -> Int32 {
    switch t {
      case 1: return 2;
      case 2: return 1;
      default: return 0;
    }
  }

  // Bit do modificador de arquitetura na máscara de inteligência.
  public static func Bit(m: Int32) -> Int32 {
    switch m {
      case 0: return 1;
      case 1: return 2;
      case 2: return 4;
      case 3: return 8;
      case 4: return 16;
      default: return 0;
    }
  }
}
