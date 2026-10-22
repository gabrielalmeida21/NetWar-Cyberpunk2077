// NET War — tipos de Black ICE e seus atributos.
// Números e nomes próprios do mod (em 2026-10-19 os nomes herdados do Cyberpunk RED foram trocados
// antes de publicar no Nexus; os ids não mudaram, então saves antigos seguem iguais).
module NetWar.Data

public abstract class NWIce {
  public static func Count() -> Int32 { return 14; }

  public static func Name(id: Int32) -> String {
    switch id {
      case 0: return "Glitchmoth";
      case 1: return "Corvex";
      case 2: return "Ripjack";
      case 3: return "Bulwark";
      case 4: return "Hollowmind";
      case 5: return "Ashjaw";
      case 6: return "Fangwire";
      case 7: return "Viperline";
      case 8: return "Barbtrace";
      case 9: return "Deepcoil";
      case 10: return NWL.T("Black ICE classe Arasaka", "Arasaka-class Black ICE");
      case 11: return NWL.T("Entidade desconhecida", "Unknown entity");
      case 12: return NWL.T("IA renegada", "Rogue AI");
      case 13: return NWL.T("Eco do DataKrash", "DataKrash echo");
      default: return "ICE?";
    }
  }

  // Velocidade: soma 1/3 no ataque.
  public static func Speed(id: Int32) -> Int32 {
    switch id {
      case 0: return 4;
      case 1: return 6;
      case 2: return 6;
      case 3: return 2;
      case 4: return 5;
      case 5: return 6;
      case 6: return 8;
      case 7: return 7;
      case 8: return 5;
      case 9: return 4;
      case 10: return 8;
      case 11: return 9;
      case 12: return 8;
      case 13: return 5;
      default: return 4;
    }
  }

  // Ataque: bônus na rolagem e no dano.
  public static func Attack(id: Int32) -> Int32 {
    switch id {
      case 0: return 1;
      case 1: return 2;
      case 2: return 3;
      case 3: return 4;
      case 4: return 3;
      case 5: return 4;
      case 6: return 3;
      case 7: return 3;
      case 8: return 3;
      case 9: return 5;
      case 10: return 5;
      case 11: return 6;
      case 12: return 6;
      case 13: return 4;
      default: return 2;
    }
  }

  // Defesa: DV que o Zap precisa alcançar (d10 + Interface).
  public static func Defense(id: Int32) -> Int32 {
    switch id {
      case 0: return 8;
      case 1: return 9;
      case 2: return 10;
      case 3: return 9;
      case 4: return 11;
      case 5: return 12;
      case 6: return 12;
      case 7: return 11;
      case 8: return 11;
      case 9: return 13;
      case 10: return 14;
      case 11: return 15;
      case 12: return 14;
      case 13: return 13;
      default: return 10;
    }
  }

  // Percepção: contra ela o V disputa o Slide (d10 + Interface vs d10 + PER), como no RED.
  public static func Perception(id: Int32) -> Int32 {
    switch id {
      case 0: return 6;
      case 1: return 8;
      case 2: return 5;
      case 3: return 3;
      case 4: return 6;
      case 5: return 7;
      case 6: return 5;
      case 7: return 6;
      case 8: return 5;
      case 9: return 4;
      case 10: return 8;
      case 11: return 9;
      case 12: return 8;
      case 13: return 6;
      default: return 5;
    }
  }

  // Efeito ao acertar o V (inspirado nos efeitos do Black ICE do RED; números próprios do mod).
  public static func EffectText(id: Int32) -> String {
    switch id {
      case 0: return NWL.T("-1 ação no próximo turno", "-1 action next turn");
      case 1: return NWL.T("Derrezza um daemon equipado (nesta sessão)", "Derezzes an equipped daemon (this session)");
      case 2: return NWL.T("+3 de dano", "+3 damage");
      case 3: return NWL.T("Empurra o V um andar acima", "Pushes V one floor up");
      case 4: return NWL.T("-1 Interface na sessão (até -3)", "-1 Interface this session (up to -3)");
      case 5: return NWL.T("Queima: 2 de dano por turno nos 2 turnos seguintes", "Burn: 2 damage per turn for the next 2 turns");
      case 6: return NWL.T("Ignora a Camuflagem; +2 de dano", "Ignores Cloak; +2 damage");
      case 7: return NWL.T("Queima 2 de RAM do deck", "Burns 2 deck RAM");
      case 8: return NWL.T("-1 ação no próximo turno e +1 de rastreio", "-1 action next turn and +1 trace");
      case 9: return NWL.T("Prende: no próximo turno não dá para descer, deslizar nem desconectar", "Holds: next turn V can't descend, slide or disconnect");
      case 10: return NWL.T("+3 de rastreio e -1 ação no próximo turno", "+3 trace and -1 action next turn");
      case 11: return NWL.T("-1 Interface na sessão e derrezza um daemon", "-1 Interface this session and derezzes a daemon");
      case 12: return NWL.T("Derrezza um daemon e queima 2 de RAM", "Derezzes a daemon and burns 2 RAM");
      case 13: return NWL.T("+3 de rastreio e prende o V", "+3 trace and holds V");
      default: return "";
    }
  }

  // REZ: "vida" do ICE.
  public static func Rez(id: Int32) -> Int32 {
    switch id {
      case 0: return 10;
      case 1: return 12;
      case 2: return 16;
      case 3: return 24;
      case 4: return 20;
      case 5: return 20;
      case 6: return 18;
      case 7: return 16;
      case 8: return 18;
      case 9: return 28;
      case 10: return 30;
      case 11: return 35;
      case 12: return 32;
      case 13: return 24;
      default: return 12;
    }
  }
}
