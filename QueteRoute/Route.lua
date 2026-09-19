-- Route communautaire, generee par tools/merge-route.js a partir des issues [route] sur GitHub. Ne pas editer a la main.
-- ns.route[faction] = { ordre = { questID... }, quetes = { [questID] = { titre, niveau, contributeurs, prendre, rendre, objectifs } }, niveaux = { [niveau] = { duree, n } }, services = { { t = "R"/"A"/"V", map, x, y, nom, n } } }
local _, ns = ...
ns.route = {
    ["Horde"] = {
        ordre = { 887 },
        quetes = {
            [887] = { titre = "Quete 887", niveau = 0, contributeurs = 0, prendre = nil, rendre = nil, objectifs = { [1] = { map = 1413, x = 0.64, y = 0.455, points = { { map = 1413, x = 0.64, y = 0.455, n = 1 }, { map = 1413, x = 0.64, y = 0.468, n = 1 } } } } },
        },
        niveaux = {  },
        services = {  },
    },
}
