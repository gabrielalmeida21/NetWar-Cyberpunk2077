// NET War — simulação do mundo da rede: contra-ataques, renda, rastreio, RAM.
// Não depende de nenhuma API do jogo: recebe horas de jogo já calculadas.
module NetWar.Sim

import NetWar.Data.*
import NetWar.Core.*

public abstract class NWTerritorySim {

  // Avança a simulação em `hours` horas de jogo, rodando um tick a cada `interval` horas.
  public static func Advance(s: ref<NWWorldState>, hours: Float, interval: Float) -> Void {
    if hours <= 0.0 {
      return;
    }
    let step = MaxF(1.0, interval);
    s.tickAccum += hours;
    while s.tickAccum >= step {
      s.tickAccum -= step;
      NWTerritorySim.RunTick(s, step);
    }
  }

  public static func RunTick(s: ref<NWWorldState>, h: Float) -> Void {
    s.simHours += h;
    NWTerritorySim.PayIncome(s, h);
    NWTerritorySim.Regenerate(s, h);
    NWTerritorySim.FactionAttacks(s, h);
    NWTerritorySim.ContestedRecovery(s, h);
    if s.trace >= 100 {
      NWTerritorySim.NetwatchOffensive(s);
    }
  }

  private static func PayIncome(s: ref<NWWorldState>, h: Float) -> Void {
    let i = 0;
    let count = s.NodeCount();
    while i < count {
      if s.owner[i] == NWFaction.V() && s.defs[i].dailyIncome > 0 {
        let perHour = Cast<Float>(s.defs[i].dailyIncome) / 24.0;
        s.incomeAccum += perHour * h * (Cast<Float>(s.control[i]) / 100.0);
      }
      i += 1;
    }
    let paid = Cast<Int32>(s.incomeAccum);
    if paid > 0 {
      s.incomeAccum -= Cast<Float>(paid);
      s.eddies += paid;
      s.incomeToday += paid;
    }
    let day = s.Day();
    if day != s.lastIncomeDay {
      if s.incomeToday > 0 {
        s.AddLog(NWL.T(s"V recebeu €$ \(s.incomeToday) de renda dos nós dominados.", s"V received €$ \(s.incomeToday) in income from held nodes."));
      }
      s.incomeToday = 0;
      s.lastIncomeDay = day;
    }
  }

  private static func Regenerate(s: ref<NWWorldState>, h: Float) -> Void {
    // Rastreio cai 1 ponto a cada 2 horas.
    s.traceDecayAccum += h * 0.5;
    let decay = Cast<Int32>(s.traceDecayAccum);
    if decay > 0 {
      s.traceDecayAccum -= Cast<Float>(decay);
      s.trace = Max(0, s.trace - decay);
    }
    // RAM: é a memória real do cyberdeck (o próprio jogo regenera); a simulação não mexe nela.
    if s.lockoutHours > 0.0 {
      s.lockoutHours = MaxF(0.0, s.lockoutHours - h);
      if s.lockoutHours <= 0.0 {
        s.AddLog(NWL.T("NETWATCH liberou o bloqueio. Acesso à rede restaurado.", "NETWATCH lifted the lockout. Net access restored."));
      }
    }
  }

  private static func FactionAttacks(s: ref<NWWorldState>, h: Float) -> Void {
    // Snapshot dos donos para que um nó tomado neste tick não ataque de novo no mesmo tick.
    let owners: array<Int32> = s.owner;
    let i = 0;
    let count = s.NodeCount();
    while i < count {
      let f = owners[i];
      if NWFaction.IsAttacker(f) {
        let chance = Cast<Int32>(Cast<Float>(NWFaction.Aggression(f)) * h / 6.0);
        if RandRange(0, 100) < chance {
          let targets: array<Int32>;
          for j in s.Neighbors(i) {
            if s.owner[j] != f && s.owner[j] != NWFaction.Blackwall() {
              ArrayPush(targets, j);
            }
          }
          if ArraySize(targets) > 0 {
            NWTerritorySim.Attack(s, f, targets[RandRange(0, ArraySize(targets))]);
          }
        }
      }
      i += 1;
    }
  }

  private static func Attack(s: ref<NWWorldState>, f: Int32, j: Int32) -> Void {
    let def = s.defs[j];
    let target = s.owner[j];
    let attacker = NWFaction.Name(f);
    let place = NWText.Upper(def.Name());

    // Iscas do V: cada uma tem 35% de desviar o ataque inteiro.
    if target == NWFaction.V() {
      let decoys = s.CountLayers(j, NWDefense.Decoy());
      let miss = 100;
      let n = 0;
      while n < decoys {
        miss = (miss * 65) / 100;
        n += 1;
      }
      if decoys > 0 && RandRange(0, 100) < 100 - miss {
        s.AddLog(NWL.T(s"Isca em \(place) desviou o ataque da \(attacker).", s"Decoy at \(place) diverted the \(attacker) attack."));
        return;
      }
    }

    let attackRoll = RandRange(1, 11) + NWFaction.Power(f);
    let defenseBonus = NWFaction.Power(target);
    if target == NWFaction.V() {
      defenseBonus = 2 + s.DefenseBonus(j) + (def.isHome ? 4 : 0);
    }
    let defenseRoll = RandRange(1, 11) + defenseBonus;

    if attackRoll <= defenseRoll {
      if target == NWFaction.V() {
        s.AddLog(NWL.T(s"\(attacker) atacou \(place), mas a defesa do V resistiu.", s"\(attacker) attacked \(place), but V's defense held."));
      }
      return;
    }

    // Black ICE do V absorve o ataque e é destruído.
    if target == NWFaction.V() && s.RemoveOneLayer(j, NWDefense.BlackIce()) {
      s.AddLog(NWL.T(s"\(attacker) destruiu um Black ICE em \(place) (defesas restantes: \(s.LayerCount(j))/3).", s"\(attacker) destroyed a Black ICE at \(place) (defenses left: \(s.LayerCount(j))/3)."));
      return;
    }

    let damage = (attackRoll - defenseRoll) * 5 + 5;
    let remaining = s.control[j] - damage;

    if def.isHome {
      // O nó doméstico nunca muda de dono; só perde controle até um mínimo.
      s.control[j] = Max(10, remaining);
      s.AddLog(NWL.T(s"\(attacker) invadiu o nó doméstico \(place): controle \(s.control[j])%.", s"\(attacker) breached the home node \(place): control \(s.control[j])%."));
      return;
    }

    if remaining <= 0 {
      s.owner[j] = f;
      s.control[j] = 25 + RandRange(0, 20);
      s.ClearLayers(j);
      s.AddLog(NWL.T(s"\(attacker) tomou \(place) de \(NWFaction.Name(target)).", s"\(attacker) took \(place) from \(NWFaction.Name(target))."));
    } else {
      s.control[j] = remaining;
      s.AddLog(NWL.T(s"\(attacker) atacou \(place) (\(NWFaction.Name(target)) −\(damage)%).", s"\(attacker) attacked \(place) (\(NWFaction.Name(target)) −\(damage)%)."));
    }
  }

  // Facções reforçam aos poucos os nós que controlam parcialmente.
  private static func ContestedRecovery(s: ref<NWWorldState>, h: Float) -> Void {
    let gain = Max(1, Cast<Int32>(2.0 * h / 6.0));
    let i = 0;
    let count = s.NodeCount();
    while i < count {
      let f = s.owner[i];
      if NWFaction.IsAttacker(f) && s.control[i] < 100 {
        s.control[i] = Min(100, s.control[i] + gain);
      }
      i += 1;
    }
  }

  public static func NetwatchOffensive(s: ref<NWWorldState>) -> Void {
    s.AddLog(NWL.T("RASTREIO 100% — NETWATCH lançou uma ofensiva digital contra o V.", "TRACE 100% — NETWATCH launched a digital offensive against V."));
    let mine: array<Int32>;
    let i = 0;
    let count = s.NodeCount();
    while i < count {
      if s.owner[i] == NWFaction.V() {
        ArrayPush(mine, i);
      }
      i += 1;
    }
    let hits = 0;
    while hits < 3 && ArraySize(mine) > 0 {
      let pick = RandRange(0, ArraySize(mine));
      let j = mine[pick];
      ArrayErase(mine, pick);
      let place = NWText.Upper(s.defs[j].Name());
      s.RemoveAllLayers(j, NWDefense.BlackIce());
      if s.defs[j].isHome {
        s.control[j] = Max(10, s.control[j] - 35);
        s.AddLog(NWL.T(s"NETWATCH derrubou o ICE de \(place): controle \(s.control[j])%.", s"NETWATCH took down the ICE at \(place): control \(s.control[j])%."));
      } else {
        let remaining = s.control[j] - 35;
        if remaining <= 0 {
          s.owner[j] = NWFaction.Neutral();
          s.control[j] = 50;
          s.AddLog(NWL.T(s"NETWATCH desconectou o V de \(place). Nó voltou a ser neutro.", s"NETWATCH cut V off from \(place). The node is neutral again."));
        } else {
          s.control[j] = remaining;
          s.AddLog(NWL.T(s"NETWATCH atacou \(place): controle \(remaining)%.", s"NETWATCH attacked \(place): control \(remaining)%."));
        }
      }
      hits += 1;
    }
    s.lockoutHours = 24.0;
    s.trace = 40;
    s.AddLog(NWL.T("Acesso à rede bloqueado por 24 horas.", "Net access locked for 24 hours."));
  }
}
