-- NET War — painel de debug e protótipo jogável (fase 1).
-- Só lê o estado do NetWarSystem (redscript) e envia ações. Nenhuma regra de jogo vive aqui.
-- Abra o overlay do CET para ver a janela. Log: NetWarDebug.log nesta pasta.

local SYSTEM_NAME = "NetWar.NetWarSystem"

local ui = {
    selected = 0,
    message = "",
    autoSync = false,
    syncTimer = 0,
    syncProbe = nil, -- nil = não testado, true/false = GetGameTimeStamp disponível
    interface = 6,
    overlay = false,
}

local ACTIONS = {
    { id = 0, label = "Escanear" },
    { id = 1, label = "Descer" },
    { id = 8, label = "Descer pela direita" },
    { id = 2, label = "Backdoor" },
    { id = 9, label = "Eye-Dee" },
    { id = 3, label = "Controlar" },
    { id = 4, label = "Zap" },
    { id = 10, label = "Slide" },
    { id = 5, label = "Camuflar" },
    { id = 7, label = "Encerrar turno" },
    { id = 6, label = "Desconectar" },
}

local RESULT_TEXT = { [0] = "EM ANDAMENTO", [1] = "NÓ DOMINADO", [2] = "DESCONECTADO", [3] = "EXPULSO" }

-- A fonte padrão do ImGui no CET não tem alguns glifos; troca só na hora de desenhar.
local GLYPHS = { ["—"] = "-", ["–"] = "-", ["−"] = "-", ["€"] = "E", ["→"] = "->" }
local function fix(t)
    t = tostring(t)
    for from, to in pairs(GLYPHS) do t = t:gsub(from, to) end
    return t
end

local Gui = setmetatable({}, { __index = ImGui })
Gui.Text = function(t) ImGui.Text(fix(t)) end
Gui.TextWrapped = function(t) ImGui.TextWrapped(fix(t)) end
Gui.TextColored = function(r, g, b, a, t) ImGui.TextColored(r, g, b, a, fix(t)) end
Gui.Button = function(label, ...) return ImGui.Button(fix(label), ...) end
Gui.Selectable = function(label, ...) return ImGui.Selectable(fix(label), ...) end
Gui.Begin = function(name, ...) return ImGui.Begin(fix(name), ...) end
Gui.ProgressBar = function(f, w, h, overlay) ImGui.ProgressBar(f, w, h, fix(overlay)) end

local function log(text)
    spdlog.info("[NetWarDebug] " .. tostring(text))
end

local function getSystem()
    local ok, sys = pcall(function()
        return Game.GetScriptableSystemsContainer():Get(CName.new(SYSTEM_NAME))
    end)
    if ok then return sys end
    return nil
end

local function hexToRgba(hex)
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 255
    local b = tonumber(hex:sub(5, 6), 16) or 255
    return r / 255, g / 255, b / 255, 1
end

local function coloredText(hex, text)
    local r, g, b, a = hexToRgba(hex)
    Gui.TextColored(r, g, b, a, text)
end

local function say(text)
    if text and text ~= "" then
        ui.message = text
        log(text)
    end
end

-- Testa uma vez se Game.GetTimeSystem():GetGameTimeStamp() existe; se não, só tempo manual.
local function readGameStamp()
    local ok, ts = pcall(function() return Game.GetTimeSystem():GetGameTimeStamp() end)
    if ui.syncProbe == nil then
        ui.syncProbe = ok and type(ts) == "number"
        log("Sondagem GetGameTimeStamp: " .. tostring(ui.syncProbe) .. (ok and "" or (" — " .. tostring(ts))))
    end
    if ok and type(ts) == "number" then return ts end
    return nil
end

registerForEvent("onInit", function()
    local sys = getSystem()
    if sys then
        log("NetWarSystem encontrado, versão " .. tostring(sys:GetModVersion()))
    else
        log("NetWarSystem ainda não disponível (normal no menu principal).")
    end
end)

registerForEvent("onOverlayOpen", function() ui.overlay = true end)
registerForEvent("onOverlayClose", function() ui.overlay = false end)

registerForEvent("onUpdate", function(delta)
    if not ui.autoSync then return end
    ui.syncTimer = ui.syncTimer + delta
    if ui.syncTimer < 2 then return end
    ui.syncTimer = 0
    local sys = getSystem()
    if not sys then return end
    sys:CatchUpGameTime()
end)

local function drawHeader(sys)
    coloredText("#FF6158", "NET::ACESSO — V")
    Gui.Text(string.format("Interface %d   RAM %d/%d   Banco NetWatch €$ %d",
        sys:GetInterface(), sys:GetRam(), sys:GetRamMax(), sys:GetEddies()))
    Gui.Text(string.format("Territórios %d/%d   Slots de daemon %d   Tempo %s",
        sys:GetTerritoryCount(), sys:GetNodeCount(), sys:GetDaemonSlots(), sys:GetTimeLabel()))
    Gui.Text(string.format("Versão %s   Esquema no save %d", sys:GetModVersion(), sys:GetSaveSchema()))
    local trace = sys:GetTrace()
    Gui.Text("Rastreio Netwatch")
    Gui.SameLine()
    Gui.ProgressBar(trace / 100, 200, 0, tostring(trace) .. "%")
    local lock = sys:GetLockoutHours()
    if lock > 0 then
        coloredText("#4D8DFF", "ACESSO BLOQUEADO PELA NETWATCH: " .. lock .. "h")
    end
    if sys:GetPendingHealthPenalty() > 0 then
        coloredText("#FF2E6B", "Penalidades de saúde pendentes: " .. sys:GetPendingHealthPenalty())
    end
    if ui.message ~= "" then
        coloredText("#F3E600", "> " .. ui.message)
    end
end

local function drawNodeList(sys)
    Gui.BeginChild("nw_nodes", 300, 330, true)
    for i = 0, sys:GetNodeCount() - 1 do
        local owner = sys:GetNodeOwner(i)
        local r, g, b, a = hexToRgba(sys:GetFactionColor(owner))
        Gui.PushStyleColor(ImGuiCol.Text, r, g, b, a)
        local mark = sys:IsNodeReachable(i) and "" or "  (fora de alcance)"
        local label = string.format("%s — %s %d%%%s##node%d",
            sys:GetNodeName(i), sys:GetNodeOwnerName(i), sys:GetNodeControl(i), mark, i)
        if Gui.Selectable(label, ui.selected == i) then
            ui.selected = i
        end
        Gui.PopStyleColor(1)
    end
    Gui.EndChild()
end

local function drawTarget(sys)
    local i = ui.selected
    Gui.BeginChild("nw_target", 0, 330, true)
    local owner = sys:GetNodeOwner(i)
    coloredText(sys:GetFactionColor(owner), string.upper(sys:GetNodeName(i)))
    Gui.Text(sys:GetNodeSubtitle(i))
    Gui.Separator()
    Gui.Text(string.format("Controle: %s · %d%%", sys:GetNodeOwnerName(i), sys:GetNodeControl(i)))
    Gui.Text(string.format("Andares %s   DV %s   ICE próprio %d",
        sys:GetNodeFloorsText(i), sys:GetNodeDVText(i), sys:GetNodeIceLevel(i)))
    Gui.Text(string.format("Posição no mapa: x %.0f  y %.0f", sys:GetNodeX(i), sys:GetNodeY(i)))
    Gui.Text("Black ICE detectado:")
    coloredText("#FF6158", "  " .. sys:GetNodeIceText(i))
    Gui.Text("Recompensa ao dominar:")
    Gui.TextWrapped("  " .. sys:GetNodeRewardText(i))
    Gui.Separator()

    local cta = sys:GetNodeCTA(i)
    if cta == "REFORÇAR NÓ" then
        if Gui.Button(string.format("Adicionar Black ICE (€$ %d)", sys:ReinforceCost(i))) then
            say(sys:ReinforceNode(i))
        end
    else
        if Gui.Button(cta) then
            say(sys:StartBreach(i))
        end
    end
    Gui.SameLine()
    if Gui.Button("Escanear · 2 RAM") then
        say(sys:ScanNode(i))
    end
    Gui.EndChild()
end

local function drawBreach(sys)
    local result = sys:GetBreachResult()
    if result < 0 then
        Gui.Text("Nenhuma invasão ainda. Escolha um nó na aba Mapa e use JACK-IN.")
        return
    end
    coloredText("#5EF6FF", string.format("INVASÃO: %s — %s",
        string.upper(sys:GetBreachNodeName()), RESULT_TEXT[result] or "?"))
    Gui.Text(string.format("Turno %d   Ações restantes %d   HP %d/%d   Rastreio na sessão +%d%s",
        sys:GetBreachTurn(), sys:GetBreachActionsLeft(), sys:GetBreachHP(), sys:GetBreachHPMax(),
        sys:GetBreachTraceGained(), sys:IsBreachCloaked() and "   [CAMUFLADO]" or ""))

    Gui.BeginChild("nw_tower", 330, 300, true)
    local count = sys:GetBreachFloorCount()
    local current = sys:GetBreachCurrentFloor()
    for k = 0, count - 1 do
        local prefix = (k == current) and ">> " or "   "
        local text = string.format("%sAndar %d: %s", prefix, k + 1, sys:GetBreachFloorLabel(k))
        if k == current then coloredText("#5EF6FF", text) else Gui.Text(text) end
    end
    Gui.EndChild()
    Gui.SameLine()
    Gui.BeginChild("nw_actions", 0, 300, true)
    local useMini, changedMini = Gui.Checkbox("Minigames (desmarcado: d10)", sys:UseMinigames())
    if changedMini then sys:SetUseMinigames(useMini) end
    if sys:HasMiniGame() then
        coloredText("#F3E600", "Minigame aberto (jogue na tela do mod).")
        if Gui.Button("Desistir do minigame", 200, 0) then sys:AbortMiniGame() end
    elseif sys:IsBreachActive() then
        for _, action in ipairs(ACTIONS) do
            if Gui.Button(action.label, 160, 0) then
                say(sys:BreachAction(action.id))
            end
        end
    else
        Gui.Text("Sessão encerrada.")
    end
    Gui.EndChild()

    Gui.Text("Registro da invasão")
    Gui.BeginChild("nw_breach_log", 0, 160, true)
    for k = 0, sys:GetBreachLogCount() - 1 do
        Gui.Text(sys:GetBreachLogLine(k))
    end
    Gui.EndChild()
end

local function drawWorld(sys)
    Gui.Text("Tempo de jogo")
    if Gui.Button("+1h") then sys:AdvanceHours(1) end
    Gui.SameLine()
    if Gui.Button("+6h") then sys:AdvanceHours(6) end
    Gui.SameLine()
    if Gui.Button("+24h") then sys:AdvanceHours(24) end
    Gui.SameLine()
    if Gui.Button("Forçar tick") then sys:DebugRunTick() end

    local changed
    ui.autoSync, changed = Gui.Checkbox("Sincronizar com o relógio do jogo", ui.autoSync)
    if changed and ui.autoSync then ui.syncProbe = nil end
    if Gui.Button("Atualizar pelo relógio do jogo agora") then sys:CatchUpGameTime() end

    Gui.Separator()
    Gui.Text("Trapaças de teste")
    Gui.Text("Interface: " .. sys:GetInterface() .. "  (" .. sys:GetInterfaceSource() .. ")")
    ui.interface, changed = Gui.SliderInt("Fixar Interface base", ui.interface, 1, 20)
    if changed then sys:SetInterfaceBase(ui.interface) end
    if not sys:IsInterfaceAuto() then
        Gui.SameLine()
        if Gui.Button("Voltar ao automático") then sys:SetInterfaceAuto() end
    end
    if Gui.Button("Dar daemon aleatório") then
        sys:DebugGiveDaemon(math.random(0, sys:GetDaemonCount() - 1), math.random(0, 3))
        say("Daemon de teste entregue (veja o Registro).")
    end
    if Gui.Button("+€$ 10.000") then sys:DebugAddEddies(10000) end
    Gui.SameLine()
    if Gui.Button("+25 rastreio") then sys:DebugAddTrace(25) end
    Gui.SameLine()
    if Gui.Button("Liberar bloqueio") then sys:DebugClearLockout() end
    Gui.SameLine()
    if Gui.Button("Resetar guerra") then
        sys:ResetState()
        ui.selected = 0
        say("Estado resetado.")
    end
end

local function drawAccess(sys)
    Gui.TextWrapped("Computadores dentro de um apartamento do V viram ponto de acesso automaticamente. "
        .. "Registrar à mão só é preciso para outros lugares.")
    local district = sys:GetCurrentDistrictName()
    if district == "" then district = "(desconhecido)" end
    Gui.Text("Distrito atual: " .. district)
    if sys:IsInPlayerApartment() then
        coloredText("#5EF6FF", "  Dentro de um apartamento do V: todos os computadores daqui são pontos de acesso.")
    else
        Gui.Text("  Fora de um apartamento do V.")
    end
    Gui.Separator()
    if sys:HasLastComputer() then
        Gui.Text("Último computador visto:")
        Gui.TextWrapped("  " .. sys:GetLastComputerPath())
        Gui.Text(string.format("  hash %d", sys:GetLastComputerHash()))
        if sys:IsLastComputerApartment() then
            coloredText("#5EF6FF", "  Computador de apartamento: ponto de acesso automático.")
        end
        if sys:IsLastComputerAccessPoint() then
            coloredText("#5EF6FF", "  Registrado à mão como ponto de acesso.")
            if Gui.Button("Remover ponto de acesso") then say(sys:UnregisterLastComputer()) end
        else
            if Gui.Button("Registrar como ponto de acesso") then say(sys:RegisterLastComputer()) end
        end
    else
        Gui.Text("Nenhum computador visto ainda nesta sessão.")
    end
    Gui.Separator()
    Gui.Text(string.format("Pontos de acesso registrados: %d   Conexões nesta sessão: %d",
        sys:GetAccessPointCount(), sys:GetConnectCount()))
    if sys:GetUiDebug() ~= "" then Gui.TextWrapped("Tela do mapa: " .. sys:GetUiDebug()) end
    Gui.Separator()
    local menuMode, changedMode = Gui.Checkbox("Abrir como menu do jogo (tela plana)", sys:UseMenuMode())
    if changedMode then sys:SetMenuMode(menuMode) end
    local everywhere, changed = Gui.Checkbox("Teste: mostrar a opção em todos os computadores", sys:GetAccessEverywhere())
    if changed then sys:SetAccessEverywhere(everywhere) end
end

local function drawLog(sys)
    Gui.BeginChild("nw_log", 0, 0, true)
    for k = 0, sys:GetLogCount() - 1 do
        Gui.TextWrapped(sys:GetLogLine(k))
    end
    Gui.EndChild()
end

registerForEvent("onDraw", function()
    if not ui.overlay then return end
    Gui.SetNextWindowSize(820, 640, ImGuiCond.FirstUseEver)
    if Gui.Begin("NET War — Debug") then
        local sys = getSystem()
        if not sys then
            Gui.Text("NetWarSystem não encontrado. Carregue um save.")
            Gui.Text("Se persistir: verifique erros do redscript em r6/logs.")
        else
            drawHeader(sys)
            Gui.Separator()
            if Gui.BeginTabBar("nw_tabs") then
                if Gui.BeginTabItem("Mapa") then
                    drawNodeList(sys)
                    Gui.SameLine()
                    drawTarget(sys)
                    Gui.EndTabItem()
                end
                if Gui.BeginTabItem("Invasão") then
                    drawBreach(sys)
                    Gui.EndTabItem()
                end
                if Gui.BeginTabItem("Registro") then
                    drawLog(sys)
                    Gui.EndTabItem()
                end
                if Gui.BeginTabItem("Acesso") then
                    drawAccess(sys)
                    Gui.EndTabItem()
                end
                if Gui.BeginTabItem("Mundo") then
                    drawWorld(sys)
                    Gui.EndTabItem()
                end
                Gui.EndTabBar()
            end
        end
    end
    Gui.End()
end)

return {}
