-- Route communautaire, generee par tools/merge-route.js a partir des issues [route] sur GitHub. Ne pas editer a la main.
-- ns.route[faction] = { ordre = { questID... }, quetes = { [questID] = { titre, niveau, contributeurs, prendre, rendre, objectifs } }, niveaux = { [niveau] = { duree, n } }, services = { { t = "R"/"A"/"V", map, x, y, nom, n } } }
local _, ns = ...
ns.route = {
    ["Horde"] = {
        ordre = {  },
        quetes = {
        },
        niveaux = {  },
        services = { { t = "A", map = 1424, x = 0.627, y = 0.191, nom = "Innkeeper Shay", n = 1 } },
    },
}
