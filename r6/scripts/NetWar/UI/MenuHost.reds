// NET War — abre a tela do mapa como um menu de verdade do jogo (plano, sem a curvatura dos popups).
//
// Usa o cenário de menu dos fliperamas (MenuScenario_ArcadeMinigame), o mesmo que as máquinas
// de arcade abrem durante a exploração: o jogo entra em modo menu (plano, pausado) e o ESC chega
// ao OnBack do cenário. Com dados do NET War, o cenário não abre minigame nenhum: a tela é montada
// na janela virtual da camada de menus (inkMenuLayer). Com dados normais, o fliperama segue igual.
// Padrão inspirado no Equipment-EX (psiberx), que reaproveita o menu do guarda-roupa.
//
// API conferida no código-fonte dos scripts do jogo:
//   ArcadeMachineController.OnBeginArcadeMinigameUI → inkMenuInstance_SpawnEvent('OnArcadeMinigameBegin')
//   MenuScenario_ArcadeMinigame.OnEnterScenario / OnBack, gameuiInGameMenuGameController.OnArcadeMinigameEvent
//   inkMenuLayer_SetCursorVisibility (e3EndScreenScenario)
module NetWar.UI

import NetWar.*

public class NetWarMenuUserData extends ArcadeMinigameUserData {
  public let game: GameInstance;
}

public abstract class NWMenuHost {

  public static func HolderName() -> CName { return n"netwar_menu_holder"; }

  // Pede ao jogo para entrar no cenário de menu com os dados do NET War.
  public static func Open(gi: GameInstance) -> Void {
    let data = new NetWarMenuUserData();
    data.m_minigame = ArcadeMinigame.INVALID;
    data.game = gi;
    let evt = new inkMenuInstance_SpawnEvent();
    evt.Init(n"OnArcadeMinigameBegin", data);
    GameInstance.GetUISystem(gi).QueueEvent(evt);
  }

  // Chamado pelo cenário ao entrar: monta a tela na camada de menus.
  public static func Mount(gi: GameInstance) -> Void {
    NWMenuHost.Unmount(gi);
    let layer = GameInstance.GetInkSystem().GetLayer(n"inkMenuLayer");
    if !IsDefined(layer) || !IsDefined(layer.GetVirtualWindow()) {
      NWLog("Camada de menus indisponível; tela não montada.");
      return;
    }
    let holder = new inkCanvas();
    holder.SetName(NWMenuHost.HolderName());
    holder.SetAnchor(inkEAnchor.Fill);
    holder.Reparent(layer.GetVirtualWindow());
    let screen = NetWarMapPopup.CreateInMenu(gi, holder, layer.GetGameController() as inkGameController);
    let sys = NetWarSystem.GetInstance(gi);
    if IsDefined(sys) {
      sys.SetMenuScreen(screen);
    }
  }

  // Remove a tela da camada de menus (não sai do cenário).
  public static func Unmount(gi: GameInstance) -> Void {
    let current = NetWarSystem.GetInstance(gi);
    if IsDefined(current) {
      let screen = current.GetMenuScreen() as NetWarMapPopup;
      if IsDefined(screen) {
        screen.Detach();
      }
    }
    let layer = GameInstance.GetInkSystem().GetLayer(n"inkMenuLayer");
    if IsDefined(layer) && IsDefined(layer.GetVirtualWindow()) {
      let window = layer.GetVirtualWindow();
      let holder = window.GetWidgetByPathName(NWMenuHost.HolderName());
      if IsDefined(holder) {
        window.RemoveChild(holder);
      }
    }
    let sys = NetWarSystem.GetInstance(gi);
    if IsDefined(sys) {
      sys.SetMenuScreen(null);
    }
  }

  // Fecha a tela e volta ao jogo.
  public static func Close(gi: GameInstance) -> Void {
    let sys = NetWarSystem.GetInstance(gi);
    if IsDefined(sys) {
      sys.StopHackMusic();
      sys.PlayUISound(NWSound.Close());
    }
    NWMenuHost.Unmount(gi);
    let evt = new inkMenuInstance_SpawnEvent();
    evt.Init(n"OnArcadeMinigameEnd");
    GameInstance.GetUISystem(gi).QueueEvent(evt);
  }
}

@addField(MenuScenario_ArcadeMinigame)
private let m_netwarActive: Bool;

@addField(MenuScenario_ArcadeMinigame)
private let m_netwarGame: GameInstance;

@wrapMethod(MenuScenario_ArcadeMinigame)
protected cb func OnEnterScenario(prevScenario: CName, userData: ref<IScriptable>) -> Bool {
  let data = userData as NetWarMenuUserData;
  if IsDefined(data) {
    this.m_netwarActive = true;
    this.m_netwarGame = data.game;
    let cursor = new inkMenuLayer_SetCursorVisibility();
    cursor.Init(true);
    this.QueueEvent(cursor);
    NWMenuHost.Mount(data.game);
    return true;
  }
  this.m_netwarActive = false;
  return wrappedMethod(prevScenario, userData);
}

@wrapMethod(MenuScenario_ArcadeMinigame)
protected cb func OnBack() -> Bool {
  if this.m_netwarActive {
    this.m_netwarActive = false;
    NWMenuHost.Close(this.m_netwarGame);
    return true;
  }
  return wrappedMethod();
}
