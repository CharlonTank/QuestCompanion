# QueteCibles

Addon World of Warcraft (beta Classic 1.60) qui affiche la liste des mobs de tes quêtes en cours, cliquables pour les cibler, dans l'esprit du cadre "Targets" de RestedXP.

- Mobs à tuer, extraits de tes objectifs de quête, avec le compteur (3/10).
- Mobs qui lâchent un objet de quête, appris automatiquement en lisant le tooltip des créatures.
- PNJ à qui parler ou rendre la quête (en vert), appris quand tu acceptes ou rends une quête.
- Point vert quand un mob de ce nom est visible autour de toi.
- Base de données **commune** : chaque joueur qui contribue enrichit `Data.lua` pour tout le monde.

## Installation

1. Télécharge le dépôt : bouton **Code** > **Download ZIP**.
2. Décompresse-le, renomme le dossier `QueteCibles-main` en `QueteCibles`.
3. Place-le dans `World of Warcraft\_classic_beta_\Interface\AddOns\`.
4. Relance le jeu.

## Commandes

| Commande | Effet |
|---|---|
| `/cibles` ou `/tgt` | Afficher / masquer le cadre |
| `/cibles add Nom` | Ajouter une cible manuelle |
| `/cibles del Nom` / `/cibles clear` | Retirer une / toutes les cibles manuelles |
| `/cibles finis` | Afficher aussi les objectifs terminés (en gris) |
| `/cibles marque` | Activer / couper les marqueurs de raid posés sur les cibles visibles |
| `/cibles export` | Ouvrir la fenêtre d'export de ta base apprise |
| `/cibles import` | Coller un export reçu d'un autre joueur |
| `/cibles sync` | Forcer une synchro avec ton groupe et ta guilde |
| `/cibles partage` | Activer / couper la synchro automatique |
| `/cibles stats` | Taille de ta base |
| `/cibles oubli` | Effacer ce qui a été appris |
| `/cibles reset` | Replacer le cadre |

## Contribuer à la base commune

Tout ce que ton addon apprend en jeu peut être versé dans la base commune, en une minute :

1. En jeu, tape `/cibles export`, puis Ctrl+A et Ctrl+C dans la fenêtre.
2. Sur GitHub, ouvre une **issue** avec le modèle **Export de base** (ou un titre commençant par `[export]`) et colle le texte.
3. Un robot fusionne automatiquement ton export dans `Data.lua`, commente l'issue avec le nombre de liens ajoutés, et la ferme.

Le fichier `Data.lua` mis à jour est distribué à tous ceux qui téléchargent l'addon. En jeu, la synchro par messages d'addon complète ça en temps réel entre joueurs d'un même groupe ou d'une même guilde.

### Format d'export

```
questID:Mob1;Mob2;?PNJ qui recoit la quete|questID:Mob3;@PNJ a qui parler
```

## Fonctionnement technique

- Les objectifs "X slain" viennent du journal de quêtes (`C_QuestLog.GetQuestObjectives`).
- Les liens quête → mob viennent du tooltip des créatures, qui affiche le titre des quêtes pour lesquelles la créature compte (`C_TooltipInfo.GetUnit`, avec repli sur un tooltip de scan).
- Le partage en jeu utilise les messages d'addon (préfixe `QCibles`) sur les canaux groupe, raid, guilde et chuchotement.
- Les clics passent par des boutons sécurisés (`SecureActionButtonTemplate`, `/targetexact`), donc la liste n'est reconstruite qu'en dehors des combats.
