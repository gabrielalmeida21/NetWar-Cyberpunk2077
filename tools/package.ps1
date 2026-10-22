<#
  NET War — monta os arquivos para o Nexus em dist\ (na estrutura de pastas do jogo).
    NetWar-<versão>.zip              principal: scripts, tweaks, NetWar.archive e o README em inglês
    NetWar-DebugPanel-<versão>.zip   opcional: painel de debug do CET
  Uso: .\tools\package.ps1   (rode antes .\tools\check-scripts.ps1 e .\tools\build-archive.ps1)
  Também regenera nexus\description.bbcode a partir de nexus\README.md.
#>
$ErrorActionPreference = 'Stop'
$Repo = Split-Path $PSScriptRoot -Parent

$sys = Get-Content (Join-Path $Repo 'r6\scripts\NetWar\Core\NetWarSystem.reds') -Raw
if ($sys -notmatch 'func Version\(\) -> String \{ return "([^"]+)"') { throw 'Versão não encontrada em NetWarSystem.reds.' }
$version = $Matches[1]
# Canal do lançamento no nome dos arquivos (0.6.0 sai como beta).
$channel = 'beta'
$tag = if ($channel) { "$version-$channel" } else { $version }

$archive = Join-Path $Repo 'archive\packed\archive\pc\mod\NetWar.archive'
if (-not (Test-Path $archive)) { throw 'NetWar.archive não encontrado: rode .\tools\build-archive.ps1 antes.' }

$dist = Join-Path $Repo 'dist'
$stage = Join-Path $dist 'stage'
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force $stage | Out-Null

function Copy-Tree($src, $dst) {
    robocopy $src $dst /E /NJH /NJS /NP /NDL /XF *.log db.sqlite3 .gitkeep | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy falhou em $src (código $LASTEXITCODE)" }
}

# Principal.
$main = Join-Path $stage 'main'
Copy-Tree (Join-Path $Repo 'r6\scripts\NetWar') (Join-Path $main 'r6\scripts\NetWar')
Copy-Tree (Join-Path $Repo 'r6\tweaks\NetWar') (Join-Path $main 'r6\tweaks\NetWar')
New-Item -ItemType Directory -Force (Join-Path $main 'archive\pc\mod') | Out-Null
Copy-Item $archive (Join-Path $main 'archive\pc\mod\NetWar.archive')
Copy-Item (Join-Path $Repo 'nexus\README.md') (Join-Path $main 'r6\scripts\NetWar\README.md')

# Opcional: painel do CET.
$debug = Join-Path $stage 'debug'
Copy-Tree (Join-Path $Repo 'bin\x64\plugins\cyber_engine_tweaks\mods\NetWarDebug') (Join-Path $debug 'bin\x64\plugins\cyber_engine_tweaks\mods\NetWarDebug')

$mainZip = Join-Path $dist "NetWar-$tag.zip"
$debugZip = Join-Path $dist "NetWar-DebugPanel-$tag.zip"
foreach ($z in @($mainZip, $debugZip)) { if (Test-Path $z) { Remove-Item -Force $z } }
Compress-Archive -Path (Join-Path $main '*') -DestinationPath $mainZip
Compress-Archive -Path (Join-Path $debug '*') -DestinationPath $debugZip
Remove-Item -Recurse -Force $stage

# Descrição do Nexus em BBCode, gerada do README (os dois nunca ficam diferentes).
python -I (Join-Path $PSScriptRoot 'md2bbcode.py') (Join-Path $Repo 'nexus\README.md') (Join-Path $Repo 'nexus\description.bbcode')
if ($LASTEXITCODE -ne 0) { throw 'Falha ao gerar nexus\description.bbcode.' }

Write-Host "Pronto: dist\NetWar-$tag.zip e dist\NetWar-DebugPanel-$tag.zip"
Get-ChildItem $dist -Filter *.zip | ForEach-Object { Write-Host ("  {0}  {1:N0} KB" -f $_.Name, ($_.Length / 1KB)) }
