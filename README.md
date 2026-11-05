# YouLikeHits — Auto View (YouTube Views)

Script PowerShell qui gagne des points automatiquement sur
[YouLikeHits](https://www.youlikehits.com/youtubenew2.php?fmt=all), section
**YouTube Views**, avec Google Chrome (profil « Livre » / `Profile 2`).

> ⚠️ **Avertissement** : automatiser un site « get paid to » peut être contraire
> à ses conditions d'utilisation. Ce projet est fourni à titre personnel et
> éducatif. Tu l'utilises sur **ton propre compte**, à tes risques.

---

## Ce que fait le script

Pour chaque vidéo, le script :

1. trouve (ou ouvre) la fenêtre Chrome sur la page **YouTube Views** ;
2. lit la page via l'accessibilité Windows (UI Automation) ;
3. clique le lien **« View »** à ses coordonnées réelles ;
4. attend **5 secondes** que la vidéo démarre, puis **ferme la fenêtre YouTube** ;
5. reste sur l'onglet YouLikeHits : le minuteur du site continue de tourner ;
6. attend le crédit des points (message **« You viewed… N Points Added! »** ou
   hausse du solde `N pts`) ;
7. recharge la liste et recommence.

**Aucune touche clavier n'est envoyée.** Seule la souris bouge une fois par
cycle (le clic sur « View »).

### Ce qui a été mesuré

- Le minuteur du site tourne **sur l'onglet YouLikeHits**, pas dans la fenêtre
  YouTube : la vidéo peut donc être fermée presque tout de suite.
- Le crédit arrive environ **85 à 140 secondes** après le clic sur « View »
  (variable selon la vidéo). Le script attend jusqu'à 140 s par sécurité.
- Exemple de journal :

```text
--- Cycle 1 / 2 ---
Bouton View a (1930, 931) - taille 319x38
points avant : 0
Video ouverte : youtube.com/watch?v=...&autoplay=1
Fenetre video fermee apres 5 s.
Points encaisses apres 85 s (solde : 4).
```

---

## Prérequis

- Windows 10 / 11
- Google Chrome installé à l'emplacement standard :
  `C:\Program Files\Google\Chrome\Application\chrome.exe`
- Un profil Chrome nommé **Livre** correspondant au dossier **`Profile 2`**
  (visible dans `chrome://version`, ligne « Chemin du profil »)
- Être **connecté** à YouLikeHits dans ce profil
- PowerShell 5.1 (fourni avec Windows)

Si ton profil « Livre » n'est pas `Profile 2`, modifie le paramètre
`-Profile` (voir plus bas).

---

## Installation

1. Copie le dossier `autoview` où tu veux, par exemple :
   `C:\Users\<toi>\Documents\Macros\autoview`
2. Vérifie que `ylh-autoview.ps1` et `Lancer-autoview.bat` sont bien dans le
   même dossier.
3. C'est tout : aucun module à installer.

---

## Utilisation

### Méthode 1 — double-clic (la plus simple)

Double-clique sur **`Lancer-autoview.bat`**.

Une fenêtre noire s'ouvre, Chrome démarre sur la page YouTube Views, et le
script enchaîne les vidéos. Laisse la fenêtre ouverte.

### Méthode 2 — depuis Super Macro

Le dossier `macros/` contient les sources :

- `ma_macro.sms` — version lisible
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

---

## Réglages

Tous les réglages sont des paramètres du script PowerShell :

| Paramètre | Défaut | Rôle |
|---|---|---|
| `-Cycles` | `30` | Nombre de vidéos à traiter |
| `-StartWatch` | `5` | Secondes avant de fermer la fenêtre YouTube |
| `-MaxWatch` | `140` | Attente maximale du crédit (secondes) |
| `-Profile` | `Profile 2` | Dossier du profil Chrome (« Livre ») |
| `-Url` | `.../youtubenew2.php?fmt=all` | Page cible |
| `-EteindreOrdinateur` | *(off)* | Planifie l'arrêt de Windows 1 h après le lancement |
| `-DryRun` | *(off)* | Test : ne clique pas, affiche ce qu'il trouve |

Exemples :

```powershell
# 10 vidéos, sans extinction
powershell -NoProfile -ExecutionPolicy Bypass -File .\ylh-autoview.ps1 -Cycles 10

# test de détection uniquement
powershell -NoProfile -ExecutionPolicy Bypass -File .\ylh-autoview.ps1 -DryRun

# autre profil Chrome
powershell -NoProfile -ExecutionPolicy Bypass -File .\ylh-autoview.ps1 -Profile "Profile 1"
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

Chaque cycle écrit dans **`ylh-autoview.log`** (même dossier que le script) :

- nombre de points avant ;
- position du bouton « View » ;
- ouverture/fermeture de la vidéo ;
- temps d'attente et solde après crédit.

C'est le premier fichier à regarder en cas de problème.

---

## Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| « La fenêtre vidéo ne s'est pas ouverte » | Pop-up bloquée | Autoriser les pop-ups pour `youlikehits.com` (icône à droite de la barre d'adresse → Toujours autoriser) |
| « Aucun bouton View visible » | Mauvaise page ou plus de vidéos | Vérifier `youtubenew2.php?fmt=all` ; recharger la page |
| « La page YouTube Views n'est pas apparue » | Chrome déjà ouvert sur un autre profil | Ouvrir manuellement la page dans le profil « Livre », puis relancer |
| Points non crédités | Minuteur plus long que `-MaxWatch` | Augmenter `-MaxWatch` (ex. `200`) |
| Le script clique à côté | Fenêtre déplacée / zoom modifié | Laisser Chrome maximisé, zoom 100 % |
| Rien ne se passe | Non connecté à YouLikeHits | Se connecter dans le profil « Livre » |

### Remarques importantes

- Le script **ne ferme que la fenêtre YouTube qu'il a ouverte**. Les fenêtres
  YouTube déjà présentes ne sont jamais touchées.
- Il ne se base pas sur `TAB` : le focus clavier de Chrome est trop instable.
  Il lit la position réelle du lien « View » via l'accessibilité Windows.
- Si tu utilises l'ordinateur pendant l'exécution, la souris bouge une fois par
  cycle (clic sur « View ») : c'est normal.
- Le site peut changer son interface : si le bouton « View » n'est plus trouvé,
  le journal l'indique.

---

## Structure du dépôt

```text
autoview/
├── README.md
├── Lancer-autoview.bat        # lanceur double-clic
├── ylh-autoview.ps1           # moteur
├── macros/
│   ├── ma_macro.sms           # source lisible (Super Macro)
│   └── ma_macro.mcr           # macro prête à ouvrir
└── ylh-autoview.log           # créé à l'exécution (ignoré par git)
```

---

## Licence

Usage personnel. Aucune garantie. Tu es responsable de l'usage que tu fais de
ce script vis-à-vis des conditions d'utilisation de YouLikeHits et de YouTube.
