# ============================================================================
#  ylh-autoview.ps1 - Gagne des points sur YouLikeHits (YouTube Views)
# ----------------------------------------------------------------------------
#  Cycle :
#    1. Trouve (ou ouvre) Chrome profil "Livre" (Profile 2) sur la page
#       YouTube Views : youtubenew2.php?fmt=all
#    2. Clique le lien "View" a ses coordonnees reelles.
#    3. Attend 5 s que la video demarre, puis FERME la fenetre YouTube.
#       (le minuteur du site tourne sur l'onglet YouLikeHits, pas besoin
#        de garder la video ouverte)
#    4. Reste sur l'onglet YouLikeHits et attend le credit (jusqu'a 140 s).
#    5. Recharge la liste et recommence.
#
#  Aucune touche clavier n'est envoyee. Seule la souris bouge 1 fois par cycle.
#
#  Usage :
#    powershell -NoProfile -ExecutionPolicy Bypass -File ylh-autoview.ps1 -Cycles 30
#
#  Options :
#    -Cycles N             nombre de videos (defaut 30)
#    -StartWatch N         secondes avant fermeture de la video (defaut 5)
#    -MaxWatch N           attente maxi du credit (defaut 140)
#    -Profile X            profil Chrome (defaut "Profile 2" = Livre)
#    -Url X                page cible
#    -EteindreOrdinateur   planifie l'arret de Windows 1 h apres le lancement
#    -DryRun               ne clique pas, affiche seulement ce qu'il trouve
#
#  Annuler l'arret :  shutdown /a
# ============================================================================

param(
    [int]$Cycles = 30,
    [int]$StartWatch = 5,
    [int]$MaxWatch = 140,
    [string]$Profile = 'Profile 2',
    [string]$Url = 'https://www.youlikehits.com/youtubenew2.php?fmt=all',
    [switch]$EteindreOrdinateur,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Chrome  = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$LogPath = Join-Path $PSScriptRoot 'ylh-autoview.log'

function Log([string]$msg) {
    $line = '{0}  {1}' -f (Get-Date -Format 'HH:mm:ss'), $msg
    Write-Host $line
    try { Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8 } catch {}
}

Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class YlhNative {
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, IntPtr e);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
    public static void LeftClick(int x, int y) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(150);
        mouse_event(0x0002, 0, 0, 0, IntPtr.Zero);
        System.Threading.Thread.Sleep(70);
        mouse_event(0x0004, 0, 0, 0, IntPtr.Zero);
    }
}
"@

# ------------------------------------------------------------------ helpers
function Get-ChromeWindows {
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $out = @()
    foreach ($p in (Get-Process chrome -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 })) {
        try {
            $pc = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $p.Id)
            foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $pc)) { $out += $w }
        } catch {}
    }
    return $out
}

function Get-WindowUrl($w) {
    try {
        $ec = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Edit)
        $eds = $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, $ec)
        if ($eds.Count -gt 0) { return $eds[0].GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value }
    } catch {}
    return ''
}

function Get-WindowTitle($w) {
    try { return [string]$w.Current.Name } catch { return '' }
}

function Get-Doc($w) {
    try {
        $dc = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Document)
        return $w.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $dc)
    } catch { return $null }
}

# Le solde est le lien "N pts" en haut de page.
function Get-Points($doc) {
    if (-not $doc) { return -1 }
    try {
        $hc = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Hyperlink)
        foreach ($l in $doc.FindAll([System.Windows.Automation.TreeScope]::Descendants, $hc)) {
            $n = $l.Current.Name.Trim()
            if ($n -match '^(\d+)\s*pts$') { return [int]$Matches[1] }
        }
    } catch {}
    return -1
}

# La page cible est UNIQUEMENT YouTube Views (pas Twitter Likes, etc.).
function Test-TargetWindow($w) {
    $u = Get-WindowUrl $w
    if ($u -match 'youtubenew2|youtubenew\.php') { return $true }
    return $false
}

function Test-VideoWindow($w) {
    $u = Get-WindowUrl $w
    if ($u -match 'youtube\.com|youtu\.be') { return $true }
    $t = Get-WindowTitle $w
    if ($t -match 'YouTube') { return $true }
    return $false
}

function Find-TargetWindow {
    foreach ($w in Get-ChromeWindows) {
        if (Test-TargetWindow $w) { return $w }
    }
    return $null
}

function Find-VideoWindows {
    return @(Get-ChromeWindows | Where-Object { Test-VideoWindow $_ })
}

function Activate-Window($w) {
    try {
        $hwnd = [IntPtr]$w.Current.NativeWindowHandle
        if ($w.Current.WindowInteractionState -eq [System.Windows.Automation.WindowInteractionState]::Minimized) {
            [YlhNative]::ShowWindow($hwnd, 9) | Out-Null   # SW_RESTORE
        }
        [YlhNative]::ShowWindow($hwnd, 5) | Out-Null       # SW_SHOW
        [YlhNative]::BringWindowToTop($hwnd) | Out-Null
        [YlhNative]::SetForegroundWindow($hwnd) | Out-Null
        Start-Sleep -Milliseconds 500
        return $true
    } catch { return $false }
}

function Select-TargetTab($w) {
    try {
        $tc = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::TabItem)
        $tabs = $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)
        $target = $null
        foreach ($t in $tabs) {
            if ($t.Current.Name -match 'YouTube Views|YouLikeHits') { $target = $t; break }
        }
        if ($target) {
            $sel = $target.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
            if (-not $sel.Current.IsSelected) { $sel.Select(); Start-Sleep -Milliseconds 500 }
        }
    } catch {}
}

function Find-ViewLink($doc) {
    if (-not $doc) { return $null }
    try {
        $hc = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Hyperlink)
        foreach ($l in $doc.FindAll([System.Windows.Automation.TreeScope]::Descendants, $hc)) {
            if ($l.Current.Name.Trim() -ne 'View') { continue }
            $r = $l.Current.BoundingRectangle
            if (-not $r.IsEmpty -and $r.Width -ge 40 -and $r.Height -ge 15) { return $l }
        }
    } catch {}
    return $null
}

function Get-ViewRect($link) {
    $r = $link.Current.BoundingRectangle
    return @{
        X    = [int]($r.X + $r.Width / 2)
        Y    = [int]($r.Y + $r.Height / 2)
        Left = [int]$r.X
        Top  = [int]$r.Y
        W    = [int]$r.Width
        H    = [int]$r.Height
    }
}

function Invoke-Reload($w) {
    try {
        $bc = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
        foreach ($b in $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, $bc)) {
            if ($b.Current.Name -match '^(Actualiser|Reload|Recharger)') {
                $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
                return $true
            }
        }
    } catch {}
    return $false
}

function Close-VideoWindow($video) {
    # Ne ferme QUE la fenetre video ouverte par cette macro.
    if (-not $video) { return $false }
    try { if (-not (Test-VideoWindow $video)) { return $false } } catch { return $false }

    try {
        $video.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern).Close()
        return $true
    } catch {}

    try {
        $hwnd = [IntPtr]$video.Current.NativeWindowHandle
        [YlhNative]::PostMessage($hwnd, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
        return $true
    } catch { return $false }
}

function Start-TargetChrome {
    if (-not (Test-Path -LiteralPath $Chrome)) { throw "Chrome introuvable : $Chrome" }
    Log "Ouverture de Chrome ($Profile) sur la page YouTube Views..."
    try {
        Start-Process -FilePath $Chrome -ArgumentList @(
            '--new-window',
            "--profile-directory=`"$Profile`"",
            "`"$Url`""
        ) | Out-Null
    } catch { Log "Echec du lancement : $_" }

    for ($s = 0; $s -lt 30; $s++) {
        Start-Sleep -Seconds 1
        if (Find-TargetWindow) { return }
    }
    Log "La page YouTube Views n'est pas apparue."
}

function Ensure-TargetWindow {
    $win = Find-TargetWindow
    if ($win) { return $win }
    Start-TargetChrome
    return (Find-TargetWindow)
}

# Message de credit affiche par le site (ex. « 7 Points Added! »).
function Get-CreditMessage($doc) {
    if (-not $doc) { return '' }
    $parts = @()
    try {
        $all = $doc.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        foreach ($e in $all) {
            $n = ($e.Current.Name -replace '\s+', ' ').Trim()
            if ($n -match 'Points Added|You viewed') { $parts += $n }
        }
    } catch {}
    return ($parts -join ' | ')
}

# Attend le credit : message "Points Added / You viewed" OU solde qui monte.
function Wait-Credit($win, [int]$pointsBefore, [string]$messageBefore, [int]$maxSeconds) {
    $waited = 0
    while ($waited -lt $maxSeconds) {
        $doc = Get-Doc $win
        $p = Get-Points $doc
        if ($p -ge 0 -and $pointsBefore -ge 0 -and $p -gt $pointsBefore) {
            return @{ Ok = $true; Seconds = $waited; Points = $p }
        }
        $msg = Get-CreditMessage $doc
        if ($msg -and $msg -ne $messageBefore) {
            return @{ Ok = $true; Seconds = $waited; Points = $p }
        }
        Start-Sleep -Seconds 5
        $waited += 5
    }
    return @{ Ok = $false; Seconds = $waited; Points = (Get-Points (Get-Doc $win)) }
}

# --------------------------------------------------------------------- start
Log "=== Demarrage : $Cycles videos demandees ==="
Log "Profil Chrome : $Profile"
Log "Fermeture video apres $StartWatch s, attente credit max $MaxWatch s"

if ($EteindreOrdinateur) {
    Log "ARRET de l'ordinateur dans 1 heure (a partir de maintenant)."
    Log "Pour annuler : invite de commandes -> shutdown /a"
    try { shutdown.exe /s /t 3600 /c "YouLikeHits : extinction automatique dans 1 heure" | Out-Null } catch { Log "Echec de la planification de l'arret : $_" }
}

$win = Ensure-TargetWindow
if (-not $win) {
    Log "ERREUR : la page YouTube Views n'a pas pu etre ouverte."
    Log "Ouvre manuellement : $Url (profil Chrome « Livre » / Profile 2), puis relance."
    exit 1
}
Log "Fenetre trouvee : $(Get-WindowTitle $win)"

$failures = 0
$done     = 0

for ($i = 1; $i -le $Cycles; $i++) {
    Log "--- Cycle $i / $Cycles ---"

    $win = Ensure-TargetWindow
    if (-not $win) { Log "Fenetre perdue, arret."; break }

    Activate-Window $win | Out-Null
    Select-TargetTab $win
    Start-Sleep -Milliseconds 600

    $doc  = Get-Doc $win
    $view = Find-ViewLink $doc

    if (-not $view) {
        Log "Aucun bouton View visible : rechargement de la page."
        Invoke-Reload $win | Out-Null
        Start-Sleep -Seconds 8
        $doc  = Get-Doc $win
        $view = Find-ViewLink $doc
    }
    if (-not $view) {
        Log "Toujours aucun bouton View (plus de videos disponibles ?). Fin."
        break
    }

    try {
        $view.GetCurrentPattern([System.Windows.Automation.ScrollItemPattern]::Pattern).ScrollIntoView()
        Start-Sleep -Milliseconds 400
    } catch {}

    $rect = Get-ViewRect $view
    $pointsBefore = Get-Points $doc
    $messageBefore = Get-CreditMessage $doc
    Log "Bouton View a ($($rect.X), $($rect.Y)) - taille $($rect.W)x$($rect.H)"
    Log "points avant : $pointsBefore"

    if ($rect.W -lt 15 -or $rect.H -lt 10 -or $rect.X -lt 0 -or $rect.Y -lt 0) {
        Log "Bouton View hors ecran ou invisible : cycle ignore."
        continue
    }

    if ($DryRun) {
        Log "DryRun : clic non effectue."
        break
    }

    # fenetres YouTube deja ouvertes AVANT le clic : on ne les touchera jamais
    $before = @(Find-VideoWindows | ForEach-Object { $_.Current.NativeWindowHandle })

    # clic reel (geste utilisateur -> la fenetre video n'est pas bloquee)
    $save = New-Object YlhNative+POINT
    [YlhNative]::GetCursorPos([ref]$save) | Out-Null
    [YlhNative]::LeftClick($rect.X, $rect.Y)
    [YlhNative]::SetCursorPos($save.X, $save.Y) | Out-Null

    # attendre la NOUVELLE fenetre video
    $video = $null
    for ($t = 0; $t -lt 15; $t++) {
        Start-Sleep -Seconds 1
        foreach ($v in Find-VideoWindows) {
            if ($before -notcontains $v.Current.NativeWindowHandle) { $video = $v; break }
        }
        if ($video) { break }
    }
    if (-not $video) {
        Log "La fenetre video ne s'est pas ouverte (pop-up bloque ?)."
        $failures++
        if ($failures -ge 3) {
            Log "3 echecs : arret. Autorise les pop-ups pour youlikehits.com."
            break
        }
        continue
    }
    Log "Video ouverte : $(Get-WindowTitle $video)"

    # le minuteur demarre au clic : on ferme la video tres vite
    Start-Sleep -Seconds $StartWatch
    if (Close-VideoWindow $video) {
        Log "Fenetre video fermee apres $StartWatch s."
    } else {
        Log "La fenetre video s'etait deja fermee."
    }

    # rester sur l'onglet YouLikeHits : c'est ce retour qui declenche le credit
    Activate-Window $win | Out-Null
    Select-TargetTab $win
    Start-Sleep -Milliseconds 900

    $res = Wait-Credit $win $pointsBefore $messageBefore $MaxWatch
    if (-not $res.Ok) {
        # un rechargement peut reveler un credit deja applique en arriere-plan
        Invoke-Reload $win | Out-Null
        Start-Sleep -Seconds 7
        $docAfter = Get-Doc $win
        $pAfter = Get-Points $docAfter
        $msgAfter = Get-CreditMessage $docAfter
        if (($pAfter -ge 0 -and $pointsBefore -ge 0 -and $pAfter -gt $pointsBefore) -or
            ($msgAfter -and $msgAfter -ne $messageBefore)) {
            $res = @{ Ok = $true; Seconds = $res.Seconds; Points = $pAfter }
            Log "Credit detecte apres rechargement."
        }
    }

    if ($res.Ok) {
        Log "Points encaisses apres $($res.Seconds) s (solde : $($res.Points))."
        $done++
        $failures = 0
    } else {
        Log "Points non detectes apres $($res.Seconds) s (solde : $($res.Points))."
    }

    Invoke-Reload $win | Out-Null
    Start-Sleep -Seconds 6
}

Log "=== Termine : $done video(s) creditee(s) sur $Cycles demandee(s) ==="
Log "Journal : $LogPath"
