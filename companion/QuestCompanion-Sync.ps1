<#
QuestCompanion-Sync.ps1 : compagnon de synchronisation (Windows PowerShell 5.1+)

  - Envoie automatiquement ce que les addons ont appris (exports QueteCibles / QueteRoute)
    vers le depot GitHub, sous forme d'issues [export] / [route] que le robot fusionne.
  - Recupere la base commune a jour (QueteCibles/Data.lua, QueteRoute/Route.lua) dans le dossier AddOns.

Usage :
  .\QuestCompanion-Sync.ps1            synchronise une fois
  .\QuestCompanion-Sync.ps1 -Install   cree une tache planifiee (toutes les 15 min + a l'ouverture de session)
  .\QuestCompanion-Sync.ps1 -Uninstall supprime la tache

Envoi : utilise GitHub CLI (gh) s'il est installe et connecte. Sinon, colle un jeton GitHub (scope "repo"
ou "public_repo") dans %LOCALAPPDATA%\QuestCompanion\token.txt. Sans les deux, seule la reception fonctionne.
Le jeu n'ecrit ses sauvegardes qu'au /reload, a la deconnexion ou a la fermeture : les envois suivent ce rythme.
#>
param(
    [switch]$Install,
    [switch]$Uninstall,
    [string]$Repo = "CharlonTank/QuestCompanion",
    [string]$WowFolder = ""
)

$ErrorActionPreference = "Continue"
$etatDir = Join-Path $env:LOCALAPPDATA "QuestCompanion"
New-Item -ItemType Directory -Force $etatDir | Out-Null
$etatFile = Join-Path $etatDir "state.json"
$logFile = Join-Path $etatDir "sync.log"
$tokenFile = Join-Path $etatDir "token.txt"

function Log($m) { $ligne = "{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $m; Write-Host $ligne; Add-Content -Path $logFile -Value $ligne -Encoding UTF8 }

# ---------------------------------------------------------------- Tache planifiee
$taskName = "QuestCompanion Sync"
if ($Uninstall) {
    schtasks /Delete /TN "$taskName" /F | Out-Null
    Log "Tache planifiee supprimee"
    return
}
if ($Install) {
    $script = $MyInvocation.MyCommand.Path
    $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
    schtasks /Create /TN "$taskName" /SC MINUTE /MO 15 /TR "$cmd" /F | Out-Null
    schtasks /Create /TN "$taskName (session)" /SC ONLOGON /TR "$cmd" /F | Out-Null
    Log "Tache planifiee installee : toutes les 15 minutes et a l'ouverture de session"
}

# ---------------------------------------------------------------- Dossier du jeu
$candidats = @()
if ($WowFolder) { $candidats += $WowFolder }
$candidats += @(
    "C:\Program Files (x86)\World of Warcraft\_classic_beta_",
    "C:\Program Files\World of Warcraft\_classic_beta_",
    "D:\World of Warcraft\_classic_beta_",
    "D:\Games\World of Warcraft\_classic_beta_"
)
$wow = $candidats | Where-Object { Test-Path (Join-Path $_ "Interface\AddOns") } | Select-Object -First 1
if (-not $wow) { Log "Dossier du jeu introuvable (passe -WowFolder)"; return }
$addons = Join-Path $wow "Interface\AddOns"

# ---------------------------------------------------------------- Etat (ce qui a deja ete envoye)
$etat = @{}
if (Test-Path $etatFile) {
    try { (Get-Content $etatFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $etat[$_.Name] = $_.Value } } catch {}
}

function Hash($s) { $sha = [System.Security.Cryptography.SHA1]::Create(); ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($s)))).Replace("-", "") }

# Lit une chaine Lua ["cle"] = "..." dans un SavedVariables et la decode
function LireChaineLua($contenu, $cle) {
    $m = [regex]::Match($contenu, '\["' + [regex]::Escape($cle) + '"\]\s*=\s*"((?:[^"\\]|\\.)*)"', 'Singleline')
    if (-not $m.Success) { return $null }
    $s = $m.Groups[1].Value
    $s = $s -replace '\\n', "`n"
    $s = $s -replace '\\"', '"'
    $s = $s -replace '\\\\', '\'
    return $s
}

# ---------------------------------------------------------------- Envoi d'une issue
function PeutEnvoyer {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        gh auth status 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { return "gh" }
    }
    if (Test-Path $tokenFile) { return "token" }
    return $null
}

function CreerIssue($titre, $corps) {
    $mode = PeutEnvoyer
    if (-not $mode) { Log "Envoi impossible : ni gh connecte, ni $tokenFile"; return $false }
    $tmp = Join-Path $etatDir "issue-body.txt"
    [IO.File]::WriteAllText($tmp, "``````" + "`n" + $corps + "`n" + "``````", [Text.Encoding]::UTF8)
    if ($mode -eq "gh") {
        $out = gh issue create --repo $Repo --title $titre --body-file $tmp 2>&1
        if ($LASTEXITCODE -eq 0) { Log "Issue creee : $out"; return $true }
        Log "Echec gh issue create : $out"; return $false
    }
    $token = (Get-Content $tokenFile -Raw).Trim()
    $body = @{ title = $titre; body = [IO.File]::ReadAllText($tmp) } | ConvertTo-Json -Compress
    try {
        $r = Invoke-RestMethod -Method Post -Uri "https://api.github.com/repos/$Repo/issues" -Headers @{ Authorization = "token $token"; "User-Agent" = "QuestCompanion" } -Body $body -ContentType "application/json"
        Log "Issue creee : $($r.html_url)"; return $true
    } catch { Log "Echec API GitHub : $($_.Exception.Message)"; return $false }
}

# ---------------------------------------------------------------- 1. Envoi des exports
$fichiers = Get-ChildItem -Path (Join-Path $wow "WTF\Account") -Recurse -Filter "*.lua" -ErrorAction SilentlyContinue |
    Where-Object { $_.Directory.Name -eq "SavedVariables" -and ($_.Name -eq "QueteRoute.lua" -or $_.Name -eq "QueteCibles.lua") }

foreach ($f in $fichiers) {
    $contenu = Get-Content $f.FullName -Raw -Encoding UTF8
    if ($f.Name -eq "QueteCibles.lua") {
        $export = LireChaineLua $contenu "export"
        if ($export -and $export.Length -gt 5) {
            $h = Hash $export
            if ($etat["cibles:" + $f.Directory.Parent.Name] -ne $h) {
                if (CreerIssue "[export] auto $env:USERNAME" $export) { $etat["cibles:" + $f.Directory.Parent.Name] = $h }
            }
        }
    } else {
        # QueteRoute : un export par personnage dans ["exports"] = { ["Perso-Royaume"] = "R1;..." }
        $bloc = [regex]::Match($contenu, '\["exports"\]\s*=\s*\{(.*?)\n\s*\},?\s*\n', 'Singleline')
        if ($bloc.Success) {
            $matches = [regex]::Matches($bloc.Groups[1].Value, '\["([^"]+)"\]\s*=\s*"((?:[^"\\]|\\.)*)"', 'Singleline')
            foreach ($m in $matches) {
                $perso = $m.Groups[1].Value
                $export = LireChaineLua ('["x"] = "' + $m.Groups[2].Value + '"') "x"
                if ($export -and $export.Length -gt 10) {
                    $h = Hash $export
                    if ($etat["route:" + $perso] -ne $h) {
                        if (CreerIssue "[route] auto $perso" $export) { $etat["route:" + $perso] = $h }
                    }
                }
            }
        }
    }
}
$etat | ConvertTo-Json | Set-Content $etatFile -Encoding UTF8

# ---------------------------------------------------------------- 2. Reception de la base commune
$routeDir = Join-Path $addons "QueteRoute"
$repoLocal = $null
try {
    $item = Get-Item $routeDir -ErrorAction Stop
    $cible = if ($item.Target) { [string]$item.Target } else { $routeDir }
    $cible = $cible -replace '^\\\\\?\\', ''
    $top = git -C $cible rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and $top) { $repoLocal = $top }
} catch {}

if ($repoLocal) {
    $out = git -C $repoLocal pull --ff-only 2>&1 | Select-Object -Last 1
    Log "git pull ($repoLocal) : $out"
} else {
    foreach ($rel in @("QueteCibles/Data.lua", "QueteRoute/Route.lua")) {
        $dest = Join-Path $addons ($rel -replace "/", "\")
        if (Test-Path (Split-Path $dest)) {
            try {
                $url = "https://raw.githubusercontent.com/$Repo/main/$rel"
                $tmp = "$dest.tmp"
                Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
                $ancien = if (Test-Path $dest) { Hash (Get-Content $dest -Raw) } else { "" }
                $nouveau = Hash (Get-Content $tmp -Raw)
                if ($ancien -ne $nouveau) { Move-Item -Force $tmp $dest; Log "Mis a jour : $rel" } else { Remove-Item $tmp }
            } catch { Log "Telechargement impossible : $rel ($($_.Exception.Message))" }
        }
    }
}
Log "Synchro terminee"
