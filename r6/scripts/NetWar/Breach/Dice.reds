// NET War — rolagens. RandRange(min, max) do jogo devolve min <= x < max.
module NetWar.Breach

public abstract class NWDice {
  public static func D10() -> Int32 { return RandRange(1, 11); }
  public static func D6() -> Int32 { return RandRange(1, 7); }
}
