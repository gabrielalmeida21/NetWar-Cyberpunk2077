<#
  NET War — compila os scripts do mod junto com Codeware e TweakXL, fora da pasta do jogo.
  Não mexe no cache do jogo: copia tudo para uma pasta temporária e compila lá com o scc do redscript.
  Uso:  .\tools\check-scripts.ps1 [-GamePath "D:\...\Cyberpunk 2077"]
#>
param([string]$GamePath = $env:CP2077_PATH)

$ErrorActionPreference = 'Stop'
if (-not $GamePath) { $GamePath = 'D:\SteamLibrary\steamapps\common\Cyberpunk 2077' }
$scc = Join-Path $GamePath 'engine\tools\scc.exe'
if (-not (Test-Path $scc)) { throw "scc.exe não encontrado em $scc (redscript instalado?)" }

$repo = Split-Path $PSScriptRoot -Parent
$work = Join-Path ([IO.Path]::GetTempPath()) 'netwar-scc'
# O scc só lista os arquivos quando a pasta tem o formato r6\scripts.
$src = Join-Path $work 'r6\scripts'
$cache = Join-Path $work 'cache'
if (Test-Path $work) { Remove-Item -Recurse -Force $work }
New-Item -ItemType Directory -Force $src, $cache | Out-Null

Copy-Item -Recurse (Join-Path $repo 'r6\scripts\NetWar') (Join-Path $src 'NetWar')
foreach ($dep in @('Codeware', 'TweakXL')) {
    $p = Join-Path $GamePath "red4ext\plugins\$dep\Scripts"
    if (Test-Path $p) { Copy-Item -Recurse $p (Join-Path $src $dep) }
}
Copy-Item (Join-Path $GamePath 'r6\cache\final.redscripts') (Join-Path $cache 'final.redscripts')

$out = & $scc -compile $src -customCacheDir $cache 2>&1
$out | ForEach-Object { "$_" } | Where-Object { $_ -notmatch '\.reds$' }
$code = $LASTEXITCODE
Remove-Item -Recurse -Force $work
if ($code -ne 0) { Write-Host 'FALHOU' -ForegroundColor Red } else { Write-Host 'OK' -ForegroundColor Green }
exit $code
