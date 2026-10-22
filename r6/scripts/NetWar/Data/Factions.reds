// NET War — definições estáticas das facções.
// Facções são Int32 simples (não enum) para facilitar persistência e chamadas via CET.
module NetWar.Data

public abstract class NWFaction {
  public static func V() -> Int32 { return 0; }
  public static func Arasaka() -> Int32 { return 1; }
  public static func Militech() -> Int32 { return 2; }
  public static func Netwatch() -> Int32 { return 3; }
  public static func KangTao() -> Int32 { return 4; }
  public static func VoodooBoys() -> Int32 { return 5; }
  public static func Neutral() -> Int32 { return 6; }
  public static func Blackwall() -> Int32 { return 7; }
  public static func Count() -> Int32 { return 8; }

  public static func Name(f: Int32) -> String {
    switch f {
      case 0: return "V";
      case 1: return "Arasaka";
      case 2: return "Militech";
      case 3: return "Netwatch";
      case 4: return "Kang Tao";
      case 5: return "Voodoo Boys";
      case 6: return NWL.T("Neutro", "Neutral");
      case 7: return "Blackwall";
      default: return "?";
    }
  }

  // Cores do mockup. Na UI final (fase 4) serão ligadas ao estilo de cores do jogo.
  public static func ColorHex(f: Int32) -> String {
    switch f {
      case 0: return "#5EF6FF";
      case 1: return "#FF3B3B";
      case 2: return "#F5A623";
      case 3: return "#4D8DFF";
      case 4: return "#B57BFF";
      case 5: return "#F3E600";
      case 6: return "#C9C3B8";
      case 7: return "#FF2E6B";
      default: return "#FFFFFF";
    }
  }

  // Forma no mapa, para não depender só de cor.
  public static func Shape(f: Int32) -> String {
    switch f {
      case 0: return "diamond";
      case 6: return "circle";
      case 7: return "breach";
      default: return "square";
    }
  }

  // Chance (%) de atacar um vizinho a cada 6 horas de jogo.
  public static func Aggression(f: Int32) -> Int32 {
    switch f {
      case 1: return 25;
      case 2: return 30;
      case 3: return 15;
      case 4: return 35;
      case 5: return 30;
      default: return 0;
    }
  }

  // Bônus somado ao d10 nos ataques e defesas da simulação.
  public static func Power(f: Int32) -> Int32 {
    switch f {
      case 1: return 5;
      case 2: return 4;
      case 3: return 5;
      case 4: return 4;
      case 5: return 3;
      case 6: return 2;
      default: return 0;
    }
  }

  // Facções que tomam território sozinhas na simulação.
  public static func IsAttacker(f: Int32) -> Bool {
    return f >= 1 && f <= 5;
  }
}
