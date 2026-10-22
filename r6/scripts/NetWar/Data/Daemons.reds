// NET War — daemons: programas encontrados nas invasões, equipados em slots e ativados na sessão.
// O efeito é o mesmo em toda raridade; a raridade só reduz o custo de RAM, até o valor da tabela
// no lendário (comum +3, raro +2, épico +1, lendário = tabela). Decisão de design do usuário.
module NetWar.Data

public abstract class NWDaemon {
  public static func Count() -> Int32 { return 7; }
  public static func BlackwallOnly() -> Int32 { return 6; }
  public static func MaxRarity() -> Int32 { return 3; }

  public static func Name(id: Int32) -> String {
    switch id {
      case 0: return NWL.T("Lâmina", "Blade");
      case 1: return NWL.T("Espelho", "Mirror");
      case 2: return NWL.T("Verme", "Worm");
      case 3: return NWL.T("Fantasma", "Ghost");
      case 4: return NWL.T("Sobrecarga", "Overload");
      case 5: return NWL.T("Âncora", "Anchor");
      case 6: return NWL.T("Fragmento de IA", "AI Fragment");
      default: return "?";
    }
  }

  public static func Description(id: Int32) -> String {
    switch id {
      case 0: return NWL.T("Zap causa +3 de dano nesta sessão", "Zap deals +3 damage this session");
      case 1: return NWL.T("Anula o próximo acerto do Black ICE", "Negates the next Black ICE hit");
      case 2: return NWL.T("−2 DV nas senhas por 3 turnos", "−2 DV on passwords for 3 turns");
      case 3: return NWL.T("Rastreio zero neste andar", "Zero trace on this floor");
      case 4: return NWL.T("+1 ação de NET neste turno", "+1 NET action this turn");
      case 5: return NWL.T("Se for expulso, sai em desconexão de emergência", "If kicked out, you leave in an emergency disconnect");
      case 6: return NWL.T("+3 Interface na sessão, mas +2 de rastreio por turno", "+3 Interface this session, but +2 trace per turn");
      default: return "";
    }
  }

  // Custo de RAM no lendário (valor da tabela).
  public static func BaseRam(id: Int32) -> Int32 {
    switch id {
      case 0: return 2;
      case 1: return 3;
      case 2: return 3;
      case 3: return 4;
      case 4: return 4;
      case 5: return 2;
      case 6: return 6;
      default: return 3;
    }
  }

  public static func RamCost(id: Int32, rarity: Int32) -> Int32 {
    return NWDaemon.BaseRam(id) + (NWDaemon.MaxRarity() - Clamp(rarity, 0, NWDaemon.MaxRarity()));
  }

  public static func RarityName(r: Int32) -> String {
    switch r {
      case 0: return NWL.T("Comum", "Common");
      case 1: return NWL.T("Raro", "Rare");
      case 2: return NWL.T("Épico", "Epic");
      case 3: return NWL.T("Lendário", "Legendary");
      default: return "—";
    }
  }

  public static func RarityColorHex(r: Int32) -> String {
    switch r {
      case 1: return "#4D8DFF";
      case 2: return "#B57BFF";
      case 3: return "#F5A623";
      default: return "#C9C3B8";
    }
  }

  // Chance (%) de o Fragmento de IA sair num sorteio de daemon em zona Blackwall (drop raro).
  public static func FragmentChance() -> Int32 { return 8; }

  // Sorteia o daemon. O Fragmento de IA só sai em zonas Blackwall, e raramente.
  public static func RollId(isBlackwall: Bool) -> Int32 {
    if isBlackwall && RandRange(0, 100) < NWDaemon.FragmentChance() {
      return NWDaemon.BlackwallOnly();
    }
    return RandRange(0, NWDaemon.BlackwallOnly());
  }

  // Sorteia a raridade: melhora com o DV do nó e na Blackwall.
  public static func RollRarity(dvBase: Int32, isBlackwall: Bool) -> Int32 {
    let common = 60;
    let rare = 27;
    let epic = 10;
    if dvBase >= 10 {
      common = 45;
      rare = 33;
      epic = 16;
    }
    if dvBase >= 12 {
      common = 35;
      rare = 35;
      epic = 22;
    }
    if isBlackwall {
      common = 20;
      rare = 40;
      epic = 28;
    }
    let roll = RandRange(0, 100);
    if roll < common { return 0; }
    if roll < common + rare { return 1; }
    if roll < common + rare + epic { return 2; }
    return 3;
  }
}
