-- Route communautaire, generee par tools/merge-route.js a partir des issues [route] sur GitHub.
-- ns.route.ordre  : liste ordonnee de questID (ordre moyen constate chez les contributeurs)
-- ns.route.quetes : [questID] = {
--     titre = "...", niveau = 7, contributeurs = 3,
--     prendre = { map = 1426, x = 0.451, y = 0.380, pnj = "Nom" },   -- ou est prise la quete
--     rendre  = { map = 1426, x = 0.478, y = 0.369, pnj = "Nom" },   -- ou elle est rendue
--     objectifs = { [1] = { map = 1426, x = 0.46, y = 0.40 }, ... }  -- ou chaque objectif a ete termine
-- }
-- Une route par faction : ns.route["Alliance"], ns.route["Horde"], ns.route["Neutral"]
local _, ns = ...
ns.route = {}
