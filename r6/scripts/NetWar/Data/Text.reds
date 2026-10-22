// NET War — utilidades de texto. StrUpper do jogo não converte letras acentuadas
// ("México" vira "MéXICO"), então completamos as do português.
module NetWar.Data

// Idioma do mod = idioma de texto do jogo (Configurações > Idioma > Texto na tela, /language OnScreen,
// o mesmo que o LocalizationSystem do Codeware lê). Português em "pt-*"; inglês em qualquer outro.
// Lido a cada texto: trocar o idioma do jogo troca o mod sem reiniciar (registros antigos ficam como estavam).
public abstract class NWL {
  public static func LanguageCode() -> String {
    let settings = GameInstance.GetSettingsSystem(GetGameInstance());
    if !IsDefined(settings) {
      return "";
    }
    let v = settings.GetVar(n"/language", n"OnScreen") as ConfigVarListName;
    return IsDefined(v) ? NameToString(v.GetValue()) : "";
  }

  public static func IsEnglish() -> Bool {
    let code = NWL.LanguageCode();
    return StrLen(code) > 0 && !StrBeginsWith(code, "pt");
  }

  public static func T(pt: String, en: String) -> String {
    return NWL.IsEnglish() ? en : pt;
  }
}

public abstract class NWText {
  public static func Upper(text: String) -> String {
    let s = StrUpper(text);
    s = StrReplaceAll(s, "á", "Á");
    s = StrReplaceAll(s, "à", "À");
    s = StrReplaceAll(s, "â", "Â");
    s = StrReplaceAll(s, "ã", "Ã");
    s = StrReplaceAll(s, "é", "É");
    s = StrReplaceAll(s, "ê", "Ê");
    s = StrReplaceAll(s, "í", "Í");
    s = StrReplaceAll(s, "ó", "Ó");
    s = StrReplaceAll(s, "ô", "Ô");
    s = StrReplaceAll(s, "õ", "Õ");
    s = StrReplaceAll(s, "ú", "Ú");
    s = StrReplaceAll(s, "ç", "Ç");
    return s;
  }
}
