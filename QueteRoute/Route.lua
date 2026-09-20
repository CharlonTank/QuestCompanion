-- Route communautaire, generee par tools/merge-route.js a partir des issues [route] sur GitHub. Ne pas editer a la main.
-- ns.route[faction] = { ordre = { questID... }, quetes = { [questID] = { titre, niveau, contributeurs, prendre, rendre, objectifs } }, niveaux = { [niveau] = { duree, n } }, services = { { t = "R"/"A"/"V", map, x, y, nom, n } } }
local _, ns = ...
ns.route = {
    ["Horde"] = {
        ordre = { 3921 },
        quetes = {
            [3921] = { titre = "Wenikee Boltbucket", niveau = 19, contributeurs = 1, prendre = { map = 1413, x = 0.629, y = 0.37 }, rendre = nil, objectifs = {  } },
        },
        niveaux = {  },
        services = {  },
    },
}
