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
    [switch]$Quiet,          # mode tache planifiee : aucune ecriture console (elle n'existe pas)
    [string]$Repo = "CharlonTank/QuestCompanion",
    [string]$WowFolder = ""
)

$ErrorActionPreference = "Continue"
# Jamais de question interactive (la tache planifiee n a pas de console) : sinon le script reste bloque
$env:GIT_TERMINAL_PROMPT = "0"
$env:GCM_INTERACTIVE = "Never"
$env:GH_PROMPT_DISABLED = "1"
$env:GH_NO_UPDATE_NOTIFIER = "1"
$localAppData = [Environment]::GetFolderPath("LocalApplicationData")
if (-not $localAppData) { $localAppData = $env:LOCALAPPDATA }
$etatDir = Join-Path $localAppData "QuestCompanion"
New-Item -ItemType Directory -Force $etatDir | Out-Null
$etatFile = Join-Path $etatDir "state.json"
$logFile = Join-Path $etatDir "sync.log"
# Jeton GitHub : dans le profil (%LOCALAPPDATA%\QuestCompanion\token.txt) ou a cote du script (companion\token.txt, ignore par git)
$tokenFile = Join-Path $etatDir "token.txt"
if (-not (Test-Path $tokenFile) -and (Test-Path (Join-Path $PSScriptRoot "token.txt"))) { $tokenFile = Join-Path $PSScriptRoot "token.txt" }

function Log($m) {
    $ligne = "{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $m
    try { [IO.File]::AppendAllText($logFile, $ligne + "`r`n", [Text.Encoding]::UTF8) } catch {}
    if (-not $Quiet) { Write-Host $ligne }
}

# gh peut ne pas etre dans le PATH de la tache planifiee : on le cherche aux emplacements habituels
$ghExe = $null
$cmdGh = Get-Command gh -ErrorAction SilentlyContinue
if ($cmdGh) { $ghExe = $cmdGh.Source }
if (-not $ghExe) {
    foreach ($p in @("$env:ProgramFiles\GitHub CLI\gh.exe", "${env:ProgramFiles(x86)}\GitHub CLI\gh.exe", "$localAppData\Programs\GitHub CLI\gh.exe")) {
        if ($p -and (Test-Path $p)) { $ghExe = $p; break }
    }
}

# ---------------------------------------------------------------- Tache planifiee
$taskName = "QuestCompanion Sync"
if ($Uninstall) {
    schtasks /Delete /TN "$taskName" /F | Out-Null
    Log "Tache planifiee supprimee"
    return
}
if ($Install) {
    $script = $MyInvocation.MyCommand.Path
    # Jeton GitHub : la tache planifiee n'a pas acces au coffre de gh, on garde le jeton dans le profil utilisateur
    if ($ghExe -and -not (Test-Path $tokenFile)) {
        $tok = (& $ghExe auth token 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and $tok) { [IO.File]::WriteAllText($tokenFile, $tok.Trim()); Log "Jeton GitHub enregistre pour la tache planifiee" }
    }
    # Sortie complete capturee dans task-out.log (aucune ecriture console, voir -Quiet).
    # Lanceur VBScript a cote du script : wscript demarre PowerShell sans aucune fenetre.
    $sortie = Join-Path $etatDir "task-out.log"
    $ps = "powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command ""& '$script' -Quiet *> '$sortie'"""
    $vbs = Join-Path $PSScriptRoot "QuestCompanion-Sync.vbs"
    Set-Content -Path $vbs -Encoding ASCII -Value @(
        'Set sh = CreateObject("WScript.Shell")',
        ('sh.Run "' + ($ps -replace '"', '""') + '", 0, False')
    )
    $action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "//B //Nologo `"$vbs`""
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes 15)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew
    Unregister-ScheduledTask -TaskName "$taskName (session)" -Confirm:$false -ErrorAction SilentlyContinue
    try {
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force -ErrorAction Stop | Out-Null
        Log "Tache planifiee installee : toutes les 15 minutes, sans fenetre"
    } catch { Log "Impossible de creer la tache planifiee : $($_.Exception.Message)"; return }
}
# Rotation de la sortie capturee
try { $so = Join-Path $etatDir "task-out.log"; if ((Test-Path $so) -and (Get-Item $so).Length -gt 512KB) { Remove-Item $so } } catch {}

# ---------------------------------------------------------------- Dossier du jeu
Log "Demarrage (utilisateur $env:USERNAME, interactif $([Environment]::UserInteractive))"
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
    try {
        $json = [IO.File]::ReadAllText($etatFile).TrimStart([char]0xFEFF)
        (ConvertFrom-Json $json).PSObject.Properties | ForEach-Object { $etat[$_.Name] = $_.Value }
    } catch { Log "Etat illisible ($($_.Exception.Message)), on repart de zero" }
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
    if (Test-Path $tokenFile) { return "token" }     # fiable partout, y compris depuis la tache planifiee
    if ($ghExe) {
        & $ghExe auth status 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { return "gh" }
        Log "gh trouve ($ghExe) mais pas connecte dans ce contexte"
    }
    return $null
}

function CreerIssue($titre, $corps) {
    $mode = PeutEnvoyer
    if (-not $mode) { Log "Envoi impossible : ni gh connecte, ni $tokenFile"; return $false }
    $tmp = Join-Path $etatDir "issue-body.txt"
    [IO.File]::WriteAllText($tmp, "``````" + "`n" + $corps + "`n" + "``````", [Text.Encoding]::UTF8)
    if ($mode -eq "gh") {
        $out = & $ghExe issue create --repo $Repo --title $titre --body-file $tmp 2>&1
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
Log "Lecture des sauvegardes"
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
Log "Mise a jour de la base commune"
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
    $out = git -C $repoLocal pull --ff-only --no-edit 2>&1 | Select-Object -Last 1
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
