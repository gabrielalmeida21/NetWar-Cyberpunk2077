<#
  NET War — monta archive\packed\archive\pc\mod\NetWar.archive com a textura do mapa.

  Requer o WolvenKit.CLI em .tools\wolvenkit (GitHub WolvenKit/WolvenKit, WolvenKit.Console-*.zip).
  Passos:
    1. node tools\gen-map\gen-map.mjs        (se out\netwar_map.png não existir)
    2. extrai do jogo a textura de UI usada como molde (vignette.xbm: TEXG_Generic_UI, sem mips)
    3. importa o PNG por cima do molde (import -k mantém as configurações de UI)
    4. converte archive\source\json\netwar\ui\netwar_map.inkatlas.json para CR2W
    5. empacota a pasta NetWar\ em NetWar.archive
  Uso:  .\tools\build-archive.ps1 [-GamePath "D:\...\Cyberpunk 2077"]
#>
param([string]$GamePath = $env:CP2077_PATH)

$ErrorActionPreference = 'Stop'
if (-not $GamePath) { $GamePath = 'D:\SteamLibrary\steamapps\common\Cyberpunk 2077' }
$repo = Split-Path $PSScriptRoot -Parent
$wk = Join-Path $repo '.tools\wolvenkit\WolvenKit.CLI.exe'
if (-not (Test-Path $wk)) { throw "WolvenKit.CLI não encontrado em $wk" }

# O WolvenKit avisa no stderr (ex.: long path); no PowerShell 5.1 isso viraria erro fatal.
# O resultado de cada passo é conferido pelos arquivos gerados.
function Invoke-WK {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $wk @args 2>&1 | Out-Null
    $ErrorActionPreference = $old
}

$png = Join-Path $repo 'tools\gen-map\out\netwar_map.png'
if (-not (Test-Path $png)) {
    Push-Location (Join-Path $repo 'tools\gen-map')
    if (-not (Test-Path 'node_modules')) { npm install --no-audit --no-fund | Out-Null }
    node gen-map.mjs
    Pop-Location
}

# Molde de textura de UI extraído do jogo (uma vez só).
$extract = Join-Path $repo '.tools\extract'
$template = Join-Path $extract 'base\gameplay\gui\widgets\notifications\vignette.xbm'
if (-not (Test-Path $template)) {
    Invoke-WK unbundle (Join-Path $GamePath 'archive\pc\content') -o $extract -w '*notifications\vignette*'
    if (-not (Test-Path $template)) { throw 'Não consegui extrair o molde vignette.xbm do jogo.' }
}

$work = Join-Path $repo '.tools\archive-build'
if (Test-Path $work) { Remove-Item -Recurse -Force $work }
$raw = Join-Path $work 'raw\netwar\ui'
$stage = Join-Path $work 'NetWar\netwar\ui'
$json = Join-Path $work 'json\netwar\ui'
New-Item -ItemType Directory -Force $raw, $stage, $json | Out-Null

Copy-Item $png (Join-Path $raw 'netwar_map.png')
Copy-Item $template (Join-Path $stage 'netwar_map.xbm')
Invoke-WK import (Join-Path $work 'raw') -o (Join-Path $work 'NetWar') -k

Copy-Item (Join-Path $repo 'archive\source\json\netwar\ui\netwar_map.inkatlas.json') $json
Invoke-WK convert deserialize (Join-Path $json 'netwar_map.inkatlas.json') -o $stage

foreach ($f in @('netwar_map.xbm', 'netwar_map.inkatlas')) {
    if (-not (Test-Path (Join-Path $stage $f))) { throw "Faltou gerar $f" }
}

$out = Join-Path $repo 'archive\packed\archive\pc\mod'
New-Item -ItemType Directory -Force $out | Out-Null
Invoke-WK pack (Join-Path $work 'NetWar') -o $out
$archive = Join-Path $out 'NetWar.archive'
if (-not (Test-Path $archive)) { throw 'NetWar.archive não foi gerado.' }
Write-Host ("OK  {0} ({1} KB)" -f $archive, [math]::Round((Get-Item $archive).Length / 1KB))
exit 0
