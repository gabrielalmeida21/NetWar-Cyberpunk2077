// NET War — ponto de acesso no PC de casa (fase 3).
// Adiciona a opção "Conectar à NET" aos computadores registrados como ponto de acesso.
// API conferida no código-fonte dos scripts do jogo (CDPR-Modding-Documentation/Cyberpunk-Scripts):
//   ComputerControllerPS.GetActions / ActionToggleOpen   (devices/masters/computerController.script)
//   Device.ExecuteAction(DeviceAction, executor)          (devices/core/deviceBase.script)
//   DeviceComponentPS.GetMyEntityID                       (devices/core/deviceComponentBase.script)
module NetWar.Access

import NetWar.*
import NetWar.UI.*

public class NetWarConnectAction extends ActionBool {
  public func SetProperties() -> Void {
    this.actionName = n"NetWarConnect";
    this.prop = DeviceActionPropertyFunctions.SetUpProperty_Bool(n"NetWarConnect", true, n"NetWarConnect", n"NetWarConnect");
  }

  public func GetTweakDBChoiceRecord() -> String {
    return "NetWarConnect";
  }

  // O texto padrão sai de LocKeyToString(Interactions.<registro>.Caption()), que só entende
  // LocKeys; um texto simples no TweakXL vira vazio. Preenchendo captionParts aqui, o jogo usa
  // estas partes direto (ScriptableDeviceAction.GetInteractionChoice só gera partes se vazias).
  public func SetCaption(text: String) -> Void {
    this.interactionChoice.caption = text;
    InteractionChoiceCaption.Clear(this.interactionChoice.captionParts);
    InteractionChoiceCaption.AddTextPart(this.interactionChoice.captionParts, text);
  }
}

// Monta a escolha do mesmo jeito que ComputerControllerPS.ActionToggleOpen.
// O texto vem do registro TweakXL Interactions.NetWarConnect (r6/tweaks/NetWar/interactions.yaml).
@wrapMethod(ComputerControllerPS)
public func GetActions(out actions: array<ref<DeviceAction>>, context: GetActionsContext) -> Bool {
  let result = wrappedMethod(actions, context);
  let sys = NetWarSystem.GetInstance(this.GetGameInstance());
  if IsDefined(sys) {
    let id = this.GetMyEntityID();
    let hash = Cast<Int32>(EntityID.GetHash(id));
    let path = EntityID.ToDebugString(id);
    sys.NoteComputerSeen(hash, path);
    if sys.IsAccessPoint(hash, path) {
      let action = new NetWarConnectAction();
      action.clearanceLevel = DefaultActionsParametersHolder.GetToggleOpenClearance();
      action.SetUp(this);
      action.SetProperties();
      action.AddDeviceName(this.GetDeviceName());
      action.OverrideInteractionRecord(t"Interactions.NetWarConnect", t"Interactions.NetWarConnect");
      action.SetCaption("NetWar");
      action.CreateActionWidgetPackage();
      ArrayPush(actions, action);
    }
  }
  return result;
}

// Toda escolha de interação de um device passa por aqui antes de virar evento no PS.
// A nossa ação é tratada aqui e não segue para o PS, que não saberia o que fazer com ela.
@wrapMethod(Device)
protected const func ExecuteAction(action: ref<DeviceAction>, opt executor: wref<GameObject>) -> Bool {
  if IsDefined(action as NetWarConnectAction) {
    let sys = NetWarSystem.GetInstance(this.GetGame());
    if IsDefined(sys) && sys.ConnectFromComputer() {
      if sys.UseMenuMode() {
        NWMenuHost.Open(this.GetGame());
      } else {
        NetWarMapPopup.Show(this.GetGame());
      }
    }
    return true;
  }
  return wrappedMethod(action, executor);
}
