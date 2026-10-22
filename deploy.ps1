<#
  NET War — copia o mod para a instalação do jogo.
  Uso:  .\deploy.ps1                      (usa $env:CP2077_PATH ou o caminho padrão abaixo)
        .\deploy.ps1 -GamePath "D:\...\Cyberpunk 2077"
        .\deploy.ps1 -Remove              (apaga os arquivos do mod do jogo)
  Só espelha as pastas que pertencem ao NET War; nada do jogo ou de outros mods é tocado.
#>
param(
    [string]$GamePath = $env:CP2077_PATH,
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'
if (-not $GamePath) { $GamePath = 'D:\SteamLibrary\steamapps\common\Cyberpunk 2077' }
if (-not (Test-Path (Join-Path $GamePath 'bin\x64\Cyberpunk2077.exe'))) {
    throw "Cyberpunk 2077 não encontrado em '$GamePath'. Passe -GamePath ou defina CP2077_PATH."
}

$Repo = $PSScriptRoot
$Targets = @(
    @{ Src = 'r6\scripts\NetWar'; Dst = 'r6\scripts\NetWar' },
    @{ Src = 'r6\tweaks\NetWar'; Dst = 'r6\tweaks\NetWar' },
    @{ Src = 'bin\x64\plugins\cyber_engine_tweaks\mods\NetWarDebug'; Dst = 'bin\x64\plugins\cyber_engine_tweaks\mods\NetWarDebug' }
)

foreach ($t in $Targets) {
    $dst = Join-Path $GamePath $t.Dst
    if ($Remove) {
        if (Test-Path $dst) { Remove-Item -Recurse -Force $dst; Write-Host "removido  $($t.Dst)" }
        continue
    }
    $src = Join-Path $Repo $t.Src
    if (-not (Test-Path $src)) { continue }
    # /MIR espelha; /XF mantém logs e banco do CET que vivem na pasta do mod.
    robocopy $src $dst /MIR /NJH /NJS /NP /NDL /XF *.log db.sqlite3 .gitkeep | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy falhou em $($t.Src) (código $LASTEXITCODE)" }
    Write-Host "copiado   $($t.Src)"
}

# Fase 4+: o .archive empacotado pelo WolvenKit.
$packed = Join-Path $Repo 'archive\packed\archive\pc\mod\NetWar.archive'
if (-not $Remove -and (Test-Path $packed)) {
    $dstArchive = Join-Path $GamePath 'archive\pc\mod\NetWar.archive'
    $same = (Test-Path $dstArchive) -and ((Get-FileHash $packed).Hash -eq (Get-FileHash $dstArchive).Hash)
    if ($same) {
        Write-Host 'igual     NetWar.archive'
    } else {
        # Com o jogo aberto o archive fica bloqueado: avisa em vez de interromper o deploy.
        try { Copy-Item $packed $dstArchive -Force; Write-Host 'copiado   NetWar.archive' }
        catch { Write-Warning 'NetWar.archive em uso pelo jogo: feche o jogo ou recarregue os archives pelo Red Hot Tools e rode o deploy de novo.' }
    }
}
if ($Remove) {
    $arch = Join-Path $GamePath 'archive\pc\mod\NetWar.archive'
    if (Test-Path $arch) { Remove-Item -Force $arch; Write-Host 'removido  NetWar.archive' }
}

# Avisos de dependência (não bloqueiam).
$checks = @(
    @{ Name = 'RED4ext'; Paths = @('red4ext\RED4ext.dll') },
    @{ Name = 'redscript'; Paths = @('engine\tools\scc.exe', 'red4ext\plugins\redscript') },
    @{ Name = 'Codeware'; Paths = @('red4ext\plugins\Codeware') },
    @{ Name = 'Cyber Engine Tweaks'; Paths = @('bin\x64\plugins\cyber_engine_tweaks.asi') }
)
foreach ($c in $checks) {
    $found = $false
    foreach ($p in $c.Paths) { if (Test-Path (Join-Path $GamePath $p)) { $found = $true } }
    if (-not $found) { Write-Warning "$($c.Name) não encontrado — o NET War não vai carregar sem ele." }
}
Write-Host 'Pronto.'
exit 0
