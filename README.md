# QueteAddons

Suite d'addons pour World of Warcraft (beta Classic 1.60), avec une base de données **communautaire** : plus il y a de joueurs qui les utilisent, plus ils deviennent précis pour tout le monde.

| Addon | Rôle | Commande |
|---|---|---|
| **AutoQuete** | Accepte et rend les quêtes automatiquement (Shift pour suspendre) | `/aq` |
| **QueteGPS** | Flèche et distance en yards vers le point de quête le plus proche (`?` rendre, `!` prendre, `x` objectif), ou vers l'étape de route | `/gps` |
| **QueteCibles** | Liste cliquable des mobs, PNJ et objets de tes quêtes en cours, façon "Targets" de RestedXP. Apprend et partage les liens quête → cible | `/cibles` |
| **QueteRoute** | Guide de leveling communautaire : enregistre ton parcours, suit la route agrégée de tous les contributeurs, étape par étape | `/route` |

## Installation

1. **Code** > **Download ZIP**, décompresse.
2. Copie les dossiers `AutoQuete`, `QueteGPS`, `QueteCibles` et `QueteRoute` dans `World of Warcraft\_classic_beta_\Interface\AddOns\`.
3. Relance le jeu.

Mise à jour : refais la même chose, ou `git pull` si tu as cloné le dépôt.

## Contribuer (une minute, aucune compétence requise)

Tout ce que les addons apprennent en jouant peut être versé dans la base commune :

- **Cibles de quête** : en jeu `/cibles export`, Ctrl+A, Ctrl+C, puis ouvre une issue avec le modèle *Export de base* et colle le texte.
- **Parcours de leveling** : en jeu `/route export`, puis issue avec le modèle *Parcours de leveling*.

Un robot fusionne automatiquement la contribution (`QueteCibles/Data.lua` ou `QueteRoute/Route.lua`), commente l'issue avec le résultat et la ferme. Tout le monde en profite au prochain téléchargement, et en jeu la synchro par messages d'addon propage aussi les cibles apprises entre membres d'un groupe ou d'une guilde.

## Comment la route communautaire est construite

Chaque joueur avec QueteRoute enregistre, sans rien faire, où et à quel niveau il prend chaque quête, où chaque objectif se termine, et où il la rend. Le script `tools/merge-route.js` agrège les parcours de tous les contributeurs : position médiane de chaque point, niveau médian, ordre moyen des quêtes. En jeu, QueteRoute compare cette route à ton journal et affiche l'étape suivante ("Prendre X chez Y", "Faire X : objectif", "Rendre X à Y"), en pointant la flèche de QueteGPS dessus. Le bouton **Passer** saute une étape qui ne te convient pas.

## Détails par addon

- [QueteCibles](QueteCibles/README-QueteCibles.md)
