# ============================================================================
#  ylh-autolike.ps1 - Gagne des points sur YouLikeHits (Twitter Likes)
# ----------------------------------------------------------------------------
#  Cycle complet :
#    1. Trouve (ou ouvre) Chrome profil "Livre" (Profile 2) sur la page
#       Twitter Likes : favtweets.php
#    2. Clique le lien "Like" de la premiere carte -> un popup X s'ouvre.
#    3. Dans le popup X, clique le bouton "Like" du tweet principal
#       (via UI Automation / InvokePattern : on declenche le vrai bouton de
#        la page, pas un clic au hasard).
#    4. Ferme le popup X et revient sur YouLikeHits.
#    5. Clique le lien "V I Liked" (la confirmation) -> le site affiche
#       "You got N Points for Liking ...!".
#    6. Recharge la liste (le solde en haut ne se met a jour qu'apres
#       rechargement) et recommence.
#
#  Aucune touche clavier n'est envoyee.
#
#  Usage :
#    powershell -NoProfile -ExecutionPolicy Bypass -File ylh-autolike.ps1 -Cycles 30
#
#  Options :
#    -Cycles N             nombre de tweets (defaut 30)
#    -MaxWait N            attente maxi du message de credit (defaut 45 s)
#    -Profile X            profil Chrome (defaut "Profile 2" = Livre)
#    -Url X                page cible
#    -EteindreOrdinateur   planifie l'arret de Windows 1 h apres le lancement
#    -DryRun               n'effectue aucun clic, affiche seulement la page
#
#  Annuler l'arret :  shutdown /a
# ============================================================================

param(
    [int]$Cycles = 30,
    [int]$MaxWait = 45,
    [string]$Profile = 'Profile 2',
    [string]$Url = 'https://www.youlikehits.com/favtweets.php',
    [switch]$EteindreOrdinateur,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Chrome  = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$LogPath = Join-Path $PSScriptRoot 'ylh-autolike.log'

function Log([string]$msg) {
    $line = '{0}  {1}' -f (Get-Date -Format 'HH:mm:ss'), $msg
    Write-Host $line
    try { Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8 } catch {}
}

Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class LikeNative {
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
        System.Threading.Thread.Sleep(180);
        mouse_event(0x0002, 0, 0, 0, IntPtr.Zero);
        System.Threading.Thread.Sleep(80);
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

# Retourne @{ Amount = N; Text = "You got N Points for Liking" } ou $null.
function Get-CreditInfo($doc) {
    if (-not $doc) { return $null }
    try {
        $all = $doc.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        foreach ($e in $all) {
            $n = ($e.Current.Name -replace '\s+', ' ').Trim()
            $m = [regex]::Match($n, 'You got\s+(\d+)\s+Points?\s+for Liking')
            if ($m.Success) {
                $amount = [int]$m.Groups[1].Value
                return @{ Amount = $amount; Text = "You got $amount Points for Liking" }
            }
        }
    } catch {}
    return $null
}

function Find-TargetWindow {
    foreach ($w in Get-ChromeWindows) {
        if ((Get-WindowUrl $w) -match 'favtweets') { return $w }
    }
    return $null
}

function Test-XWindow($w) {
    return ((Get-WindowUrl $w) -match 'twitter\.com|x\.com|t\.co')
}

function Find-XWindows {
    return @(Get-ChromeWindows | Where-Object { Test-XWindow $_ })
}

function Activate-Window($w) {
    try {
        $hwnd = [IntPtr]$w.Current.NativeWindowHandle
        if ($w.Current.WindowInteractionState -eq [System.Windows.Automation.WindowInteractionState]::Minimized) {
            [LikeNative]::ShowWindow($hwnd, 9) | Out-Null
        }
        [LikeNative]::ShowWindow($hwnd, 5) | Out-Null
        [LikeNative]::BringWindowToTop($hwnd) | Out-Null
        [LikeNative]::SetForegroundWindow($hwnd) | Out-Null
        Start-Sleep -Milliseconds 600
        return $true
    } catch { return $false }
}

function Close-Window($w) {
    if (-not $w) { return $false }
    try { $w.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern).Close(); return $true } catch {}
    try { [LikeNative]::PostMessage([IntPtr]$w.Current.NativeWindowHandle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null; return $true } catch {}
    return $false
}

function Get-Hyperlinks($doc) {
    if (-not $doc) { return @() }
    try {
        $hc = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Hyperlink)
        return @($doc.FindAll([System.Windows.Automation.TreeScope]::Descendants, $hc))
    } catch { return @() }
}

# Cherche un lien visible dont le texte correspond a $pattern (regex).
function Find-YlhLinkMatch($doc, [string]$pattern) {
    foreach ($l in Get-Hyperlinks $doc) {
        $n = $l.Current.Name.Trim()
        if ($n -notmatch $pattern) { continue }
        $r = $l.Current.BoundingRectangle
        if (-not $r.IsEmpty -and $r.Width -ge 30 -and $r.Height -ge 12) { return $l }
    }
    return $null
}

function Invoke-ByMouse($e) {
    $r = $e.Current.BoundingRectangle
    $x = [int]($r.X + $r.Width / 2); $y = [int]($r.Y + $r.Height / 2)
    $save = New-Object LikeNative+POINT
    [LikeNative]::GetCursorPos([ref]$save) | Out-Null
    [LikeNative]::LeftClick($x, $y)
    [LikeNative]::SetCursorPos($save.X, $save.Y) | Out-Null
    return "$x,$y"
}

# Bouton "Like" du tweet PRINCIPAL : le premier de la page.
# Nom accessible : "284 Likes. Like" ou "284 Likes. Liked".
function Find-MainLikeButton($doc) {
    if (-not $doc) { return $null }
    try {
        $bc = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
        foreach ($b in $doc.FindAll([System.Windows.Automation.TreeScope]::Descendants, $bc)) {
            $n = $b.Current.Name.Trim()
            if ($n -notmatch '^[\d,.]+\s*[KMB]?\s+Likes?\.\s+(Like|Liked)$') { continue }
            $r = $b.Current.BoundingRectangle
            if ($r.IsEmpty -or $r.Width -lt 20) { continue }
            return $b
        }
    } catch {}
    return $null
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

function Start-TargetChrome {
    if (-not (Test-Path -LiteralPath $Chrome)) { throw "Chrome introuvable : $Chrome" }
    Log "Ouverture de Chrome ($Profile) sur la page Twitter Likes..."
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
    Log "La page Twitter Likes n'est pas apparue."
}

function Ensure-TargetWindow {
    $win = Find-TargetWindow
    if ($win) { return $win }
    Start-TargetChrome
    return (Find-TargetWindow)
}

# --------------------------------------------------------------------- start
Log "=== Demarrage : $Cycles tweets demandes ==="
Log "Profil Chrome : $Profile"

if ($EteindreOrdinateur) {
    Log "ARRET de l'ordinateur dans 1 heure (a partir de maintenant)."
    Log "Pour annuler : invite de commandes -> shutdown /a"
    try { shutdown.exe /s /t 3600 /c "YouLikeHits : extinction automatique dans 1 heure" | Out-Null } catch { Log "Echec de la planification de l'arret : $_" }
}

$win = Ensure-TargetWindow
if (-not $win) {
    Log "ERREUR : la page Twitter Likes n'a pas pu etre ouverte."
    Log "Ouvre manuellement : $Url (profil Chrome « Livre » / Profile 2), puis relance."
    exit 1
}
Log "Fenetre trouvee : $(Get-WindowTitle $win)"

$failures = 0
$done     = 0
$total    = 0

for ($i = 1; $i -le $Cycles; $i++) {
    Log "--- Cycle $i / $Cycles ---"

    $win = Ensure-TargetWindow
    if (-not $win) { Log "Fenetre perdue, arret."; break }

    Activate-Window $win | Out-Null
    Start-Sleep -Milliseconds 700

    $doc = Get-Doc $win
    $pointsBefore = Get-Points $doc
    Log "points avant : $pointsBefore"

    $likeLink = Find-YlhLinkMatch $doc '^Like$'
    if (-not $likeLink) {
        Log "Aucun bouton Like visible : rechargement de la page."
        Invoke-Reload $win | Out-Null
        Start-Sleep -Seconds 9
        $doc = Get-Doc $win
        $likeLink = Find-YlhLinkMatch $doc '^Like$'
    }
    if (-not $likeLink) {
        Log "Toujours aucun bouton Like (plus de tweets disponibles ?). Fin."
        break
    }

    if ($DryRun) {
        Log "DryRun : Like trouve, clic non effectue. Fin du test."
        break
    }

    # fenetres X deja ouvertes AVANT le clic : on ne les touchera jamais
    $before = @(Find-XWindows | ForEach-Object { $_.Current.NativeWindowHandle })

    $pos = Invoke-ByMouse $likeLink
    Log "Clic Like sur YouLikeHits a ($pos)"

    # attendre le popup X (2 tentatives : un clic peut arriver avant le chargement)
    $xwin = $null
    for ($attempt = 1; $attempt -le 2 -and -not $xwin; $attempt++) {
        for ($t = 0; $t -lt 12; $t++) {
            Start-Sleep -Seconds 1
            foreach ($v in Find-XWindows) {
                if ($before -notcontains $v.Current.NativeWindowHandle) { $xwin = $v; break }
            }
            if ($xwin) { break }
        }
        if (-not $xwin -and $attempt -eq 1) {
            Log "Pas de popup, nouvelle tentative de clic..."
            Activate-Window $win | Out-Null
            $again = Find-YlhLinkMatch (Get-Doc $win) '^Like$'
            if ($again) { Log "Clic Like (2e) a ($(Invoke-ByMouse $again))" }
            Start-Sleep -Seconds 2
        }
    }

    if (-not $xwin) {
        Log "Le popup X ne s'est pas ouvert (pop-up bloquee ?)."
        $failures++
        if ($failures -ge 3) {
            Log "3 echecs : arret. Autorise les pop-ups pour youlikehits.com."
            break
        }
        Invoke-Reload $win | Out-Null
        Start-Sleep -Seconds 6
        continue
    }

    Log "Popup X : $(Get-WindowUrl $xwin)"
    Start-Sleep -Seconds 4
    Activate-Window $xwin | Out-Null

    $xdoc = Get-Doc $xwin
    $btn = $null
    for ($t = 0; $t -lt 10; $t++) {
        $btn = Find-MainLikeButton $xdoc
        if ($btn) { break }
        Start-Sleep -Seconds 2
        $xdoc = Get-Doc $xwin
    }

    $liked = $false
    if (-not $btn) {
        Log "Bouton Like introuvable dans le popup X (page non chargee ?)."
    } elseif ($btn.Current.Name -match 'Liked$') {
        Log "Tweet deja like sur X : $($btn.Current.Name)"
        $liked = $true
    } else {
        $nameBefore = $btn.Current.Name
        for ($try = 1; $try -le 2 -and -not $liked; $try++) {
            try {
                $btn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
                Log "Like envoye ($nameBefore) [essai $try]"
            } catch {
                Log "Invoke impossible : $_"
                try { Invoke-ByMouse $btn | Out-Null; Log "Clic souris de secours [essai $try]" } catch {}
            }
            Start-Sleep -Seconds 3
            $xdoc = Get-Doc $xwin
            $btn2 = Find-MainLikeButton $xdoc
            if ($btn2 -and $btn2.Current.Name -match 'Liked$') {
                $liked = $true
                Log "Like confirme : $($btn2.Current.Name)"
            } elseif ($btn2) {
                $nameBefore = $btn2.Current.Name
                Log "Toujours pas like ($nameBefore)"
            }
        }
    }

    Close-Window $xwin | Out-Null
    Start-Sleep -Seconds 1

    # retour sur YouLikeHits : c'est ICI que le credit se declenche
    Activate-Window $win | Out-Null
    Start-Sleep -Seconds 2

    # clic sur la confirmation "V I Liked"
    $claim = $null
    for ($t = 0; $t -lt 10 -and -not $claim; $t++) {
        $claim = Find-YlhLinkMatch (Get-Doc $win) 'I Liked'
        if (-not $claim) { Start-Sleep -Seconds 1 }
    }

    if (-not $claim) {
        Log "Lien de confirmation 'I Liked' introuvable."
        $failures++
        Invoke-Reload $win | Out-Null
        Start-Sleep -Seconds 6
        if ($failures -ge 3) { Log "3 echecs : arret."; break }
        continue
    }

    Log "Clic confirmation a ($(Invoke-ByMouse $claim))"

    # attendre le message "You got N Points for Liking ..."
    $credited = $false
    $waited = 0
    while ($waited -lt $MaxWait) {
        Start-Sleep -Seconds 2
        $waited += 2
        $doc = Get-Doc $win
        $info = Get-CreditInfo $doc
        if ($info) {
            Log "CREDIT : $($info.Text)"
            $credited = $true
            $total += $info.Amount
            break
        }
    }

    if ($credited) {
        $done++
        $failures = 0
    } else {
        Log "Message de credit non vu apres $MaxWait s."
        # verification apres rechargement
        Invoke-Reload $win | Out-Null
        Start-Sleep -Seconds 8
        $pAfter = Get-Points (Get-Doc $win)
        if ($pointsBefore -ge 0 -and $pAfter -gt $pointsBefore) {
            Log "Credit visible apres rechargement : $pointsBefore -> $pAfter pts"
            $done++
            $failures = 0
        } else {
            $failures++
        }
    }

    Invoke-Reload $win | Out-Null
    Start-Sleep -Seconds 7

    $pNow = Get-Points (Get-Doc $win)
    Log "solde apres rechargement : $pNow pts (total gagne : $total)"

    if ($failures -ge 3) { Log "3 echecs consecutifs : arret."; break }
}

Log "=== Termine : $done tweet(s) credite(s), +$total points, sur $Cycles demande(s) ==="
Log "Journal : $LogPath"
