-- Route communautaire, generee par tools/merge-route.js a partir des issues [route] sur GitHub. Ne pas editer a la main.
-- ns.route[faction] = { ordre = { questID... }, quetes = { [questID] = { titre, niveau, contributeurs, prendre, rendre, objectifs } }, niveaux = { [niveau] = { duree, n } }, services = { { t = "R"/"A"/"V", map, x, y, nom, n } } }
local _, ns = ...
ns.route = {
    ["Horde"] = {
        ordre = { 5723 },
        quetes = {
            [5723] = { titre = "Quete 5723", niveau = 0, contributeurs = 0, prendre = nil, rendre = nil, objectifs = {  } },
        },
        niveaux = {  },
        services = {  },
    },
}
