# YouLikeHits Auto — YouTube Views & Twitter Likes

Scripts PowerShell qui gagnent des points automatiquement sur
[YouLikeHits](https://www.youlikehits.com/), avec Google Chrome
(profil « Livre » / `Profile 2`) :

| Automatisation | Page | Fichier |
|---|---|---|
| **YouTube Views** | `youtubenew2.php` | `ylh-autoview.ps1` / `Lancer-autoview.bat` |
| **Twitter Likes** | `favtweets.php` | `ylh-autolike.ps1` / `Lancer-autolike.bat` |

> ⚠️ **Avertissement** : automatiser un site « get paid to » peut être contraire
> à ses conditions d'utilisation, et les likes automatisés peuvent être
> contraires aux règles de X (Twitter). Ce projet est fourni à titre personnel
> et éducatif. Tu l'utilises sur **ton propre compte**, à tes risques.

---

## Ce que font les scripts

### 1. YouTube Views (`ylh-autoview.ps1`)

Pour chaque vidéo :

1. trouve (ou ouvre) la fenêtre Chrome sur la page **YouTube Views** ;
2. lit la page via l'accessibilité Windows (UI Automation) ;
3. clique le lien **« View »** à ses coordonnées réelles ;
4. attend **5 secondes** que la vidéo démarre, puis **ferme la fenêtre YouTube** ;
5. reste sur l'onglet YouLikeHits : le minuteur du site continue de tourner ;
6. attend le crédit (message **« You viewed… N Points Added! »** ou hausse du
   solde `N pts`) ;
7. recharge la liste et recommence.

**Aucune touche clavier n'est envoyée.** Seule la souris bouge une fois par
cycle (le clic sur « View »).

Mesures réelles :

- le minuteur tourne **sur l'onglet YouLikeHits**, pas dans la fenêtre YouTube ;
- le crédit arrive environ **85 à 140 secondes** après le clic sur « View ».

```text
--- Cycle 1 / 2 ---
Bouton View a (1930, 931) - taille 319x38
points avant : 0
Video ouverte : youtube.com/watch?v=...&autoplay=1
Fenetre video fermee apres 5 s.
Points encaisses apres 85 s (solde : 4).
```

### 2. Twitter Likes (`ylh-autolike.ps1`)

Pour chaque tweet :

1. trouve (ou ouvre) la fenêtre Chrome sur la page **Twitter Likes** ;
2. clique le lien **« Like »** de la première carte → un popup X s'ouvre ;
3. dans le popup X, clique le bouton **« Like »** du tweet principal
   (via UI Automation / `InvokePattern` : on déclenche le vrai bouton de la
   page, pas un clic au hasard) ;
4. ferme le popup X et **revient sur YouLikeHits** ;
5. clique la confirmation **« ✔ I Liked »** → le site affiche
   **« You got N Points for Liking …! »** ;
6. recharge la liste (le solde en haut ne se met à jour qu'après rechargement)
   et recommence.

> **Point clé** : c'est le clic sur **« I Liked »** qui crédite les points.
> Sans lui, le like est bien fait sur X mais aucun point n'est ajouté.

```text
--- Cycle 1 / 2 ---
points avant : 4
Clic Like sur YouLikeHits a (1657,616)
Popup X : x.com/twitter/status/...
Like envoye (105 Likes. Like) [essai 1]
Like confirme : 106 Likes. Liked
Clic confirmation a (1657,616)
CREDIT : You got 21 Points for Liking
solde apres rechargement : 25 pts (total gagne : 21)
```

---

## Prérequis

- Windows 10 / 11
- Google Chrome installé à l'emplacement standard :
  `C:\Program Files\Google\Chrome\Application\chrome.exe`
- Un profil Chrome nommé **Livre** correspondant au dossier **`Profile 2`**
  (visible dans `chrome://version`, ligne « Chemin du profil »)
- Être **connecté** à YouLikeHits **et à X (Twitter)** dans ce profil
- PowerShell 5.1 (fourni avec Windows)

Si ton profil « Livre » n'est pas `Profile 2`, modifie le paramètre
`-Profile` (voir plus bas).

---

## Installation

1. Copie le dossier `autoview` où tu veux, par exemple :
   `C:\Users\<toi>\Documents\Macros\autoview`
2. Garde les `.ps1` et les `.bat` dans le même dossier.
3. C'est tout : aucun module à installer.

---

## Utilisation

### Méthode 1 — double-clic (la plus simple)

- **`Lancer-autoview.bat`** → YouTube Views (30 vidéos)
- **`Lancer-autolike.bat`** → Twitter Likes (30 tweets)

Une fenêtre noire s'ouvre, Chrome démarre sur la bonne page, et le script
enchaîne les cycles. Laisse la fenêtre ouverte.

### Méthode 2 — depuis Super Macro

Le dossier `macros/` contient les sources :

- `ma_macro.sms` — version lisible (YouTube Views)
- `ma_macro.mcr` — version à ouvrir dans Super Macro

Dans Super Macro : **Macro > Ouvrir** → `ma_macro.mcr`, puis **Exécuter**.

La ligne exécutée est :

```text
Execute;C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe;-NoProfile -ExecutionPolicy Bypass -File "C:\Users\everb\Documents\Macros\autoview\ylh-autoview.ps1" -Cycles 30 -StartWatch 5 -MaxWatch 140 -EteindreOrdinateur
Quitter
```

> Le chemin du programme (`powershell.exe`) ne doit **jamais** être entre
> guillemets. Les guillemets restent corrects **dans les arguments**
> (chemin du `.ps1`, nom du profil).

Adapte le chemin du `.ps1` si tu déplaces le dossier.

### Ligne de commande directe

```powershell
# YouTube Views
powershell -NoProfile -ExecutionPolicy Bypass -File .\ylh-autoview.ps1 -Cycles 30

# Twitter Likes
powershell -NoProfile -ExecutionPolicy Bypass -File .\ylh-autolike.ps1 -Cycles 30
```

---

## Réglages

### YouTube Views — `ylh-autoview.ps1`

| Paramètre | Défaut | Rôle |
|---|---|---|
| `-Cycles` | `30` | Nombre de vidéos à traiter |
| `-StartWatch` | `5` | Secondes avant de fermer la fenêtre YouTube |
| `-MaxWatch` | `140` | Attente maximale du crédit (secondes) |
| `-Profile` | `Profile 2` | Dossier du profil Chrome (« Livre ») |
| `-Url` | `.../youtubenew2.php?fmt=all` | Page cible |
| `-EteindreOrdinateur` | *(off)* | Arrêt de Windows 1 h après le lancement |
| `-DryRun` | *(off)* | Test : ne clique pas, affiche ce qu'il trouve |

### Twitter Likes — `ylh-autolike.ps1`

| Paramètre | Défaut | Rôle |
|---|---|---|
| `-Cycles` | `30` | Nombre de tweets à traiter |
| `-MaxWait` | `120` | Attente maxi du crédit, réessais compris (secondes) |
| `-ConfirmDelay` | `15` | Attente avant « I Liked » (propagation du like par Twitter) |
| `-Profile` | `Profile 2` | Dossier du profil Chrome (« Livre ») |
| `-Url` | `.../favtweets.php` | Page cible |
| `-EteindreOrdinateur` | *(off)* | Arrêt de Windows 1 h après le lancement |
| `-DryRun` | *(off)* | Test : ne clique pas, affiche ce qu'il trouve |

Exemples :

```powershell
# test de détection uniquement
powershell -NoProfile -ExecutionPolicy Bypass -File .\ylh-autolike.ps1 -DryRun

# autre profil Chrome
powershell -NoProfile -ExecutionPolicy Bypass -File .\ylh-autolike.ps1 -Profile "Profile 1"
```

### Extinction automatique (1 heure)

Avec `-EteindreOrdinateur`, le script planifie :

```text
shutdown /s /t 3600
```

L'ordinateur s'éteint **1 heure après le lancement**, même si les cycles sont
déjà terminés.

Pour annuler à tout moment, dans une invite de commandes :

```bat
shutdown /a
```

---

## Journal

Chaque cycle écrit dans :

- **`ylh-autoview.log`** (YouTube Views)
- **`ylh-autolike.log`** (Twitter Likes)

On y trouve : points avant, position des boutons, ouverture/fermeture du popup,
confirmation et montant crédité. C'est le premier fichier à regarder en cas de
problème.

---

## Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| « Le popup X ne s'est pas ouvert » | Pop-up bloquée | Autoriser les pop-ups pour `youlikehits.com` (icône à droite de la barre d'adresse → Toujours autoriser) |
| Le like est fait mais 0 point | Le clic « I Liked » n'a pas eu lieu | Vérifier le journal : ligne `Clic confirmation` puis `CREDIT :` |
| « Uh Oh — We didn't find this Like » | Twitter n'a pas encore propagé le like | Le script attend 15 s puis réessaie (3 fois, 25 s entre chaque). Augmenter `-ConfirmDelay` si ça arrive souvent |
| « Bouton Like introuvable dans le popup X » | Tweet supprimé / page non chargée | Le script passe au tweet suivant (`Skip`) |
| « Aucun bouton Like visible » | Mauvaise page ou plus de tweets | Vérifier `favtweets.php` ; recharger la page |
| « La page … n'est pas apparue » | Chrome déjà ouvert sur un autre profil | Ouvrir manuellement la page dans le profil « Livre », puis relancer |
| Le script clique à côté | Fenêtre déplacée / zoom modifié | Laisser Chrome maximisé, zoom 100 % |
| Rien ne se passe | Non connecté à YouLikeHits / X | Se connecter dans le profil « Livre » |

### Remarques importantes

- Le script **ne ferme que le popup X / la fenêtre YouTube qu'il a ouvert**.
  Les fenêtres déjà présentes ne sont jamais touchées.
- Il ne se base pas sur `TAB` : le focus clavier de Chrome est trop instable.
  Il lit la position réelle des éléments via l'accessibilité Windows et
  déclenche le bouton de la page (`InvokePattern`).
- Si tu utilises l'ordinateur pendant l'exécution, la souris bouge une fois par
  cycle : c'est normal.
- Le site peut changer son interface : si un bouton n'est plus trouvé, le
  journal l'indique.

---

## Structure du dépôt

```text
autoview/
├── README.md
├── Lancer-autoview.bat        # lanceur YouTube Views
├── Lancer-autolike.bat        # lanceur Twitter Likes
├── ylh-autoview.ps1           # moteur YouTube Views
├── ylh-autolike.ps1           # moteur Twitter Likes
├── macros/
│   ├── ma_macro.sms           # source lisible (Super Macro)
│   └── ma_macro.mcr           # macro prête à ouvrir
├── ylh-autoview.log           # créé à l'exécution (ignoré par git)
└── ylh-autolike.log           # créé à l'exécution (ignoré par git)
```

---

## Licence

Usage personnel. Aucune garantie. Tu es responsable de l'usage que tu fais de
ces scripts vis-à-vis des conditions d'utilisation de YouLikeHits, de X
(Twitter) et de YouTube.
