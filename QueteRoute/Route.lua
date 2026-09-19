-- Route communautaire, generee par tools/merge-route.js a partir des issues [route] sur GitHub. Ne pas editer a la main.
-- ns.route[faction] = { ordre = { questID... }, quetes = { [questID] = { titre, niveau, contributeurs, prendre, rendre, objectifs } }, niveaux = { [niveau] = { duree, n } }, services = { { t = "R"/"A"/"V", map, x, y, nom, n } } }
local _, ns = ...
ns.route = {
    ["Horde"] = {
        ordre = { 844, 869 },
        quetes = {
            [844] = { titre = "Quete 844", niveau = 0, contributeurs = 0, prendre = nil, rendre = nil, objectifs = { [1] = { map = 1413, x = 0.607, y = 0.353 } } },
            [869] = { titre = "Quete 869", niveau = 0, contributeurs = 0, prendre = nil, rendre = nil, objectifs = { [1] = { map = 1413, x = 0.582, y = 0.355, points = { { map = 1413, x = 0.582, y = 0.355, n = 1 }, { map = 1413, x = 0.562, y = 0.354, n = 1 } } } } },
        },
        niveaux = {  },
        services = {  },
    },
}
