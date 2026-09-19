-- Route communautaire, generee par tools/merge-route.js a partir des issues [route] sur GitHub. Ne pas editer a la main.
-- ns.route[faction] = { ordre = { questID... }, quetes = { [questID] = { titre, niveau, contributeurs, prendre, rendre, objectifs } }, niveaux = { [niveau] = { duree, n } }, services = { { t = "R"/"A"/"V", map, x, y, nom, n } } }
local _, ns = ...
ns.route = {
    ["Horde"] = {
        ordre = { 887, 97253, 891 },
        quetes = {
            [887] = { titre = "Quete 887", niveau = 0, contributeurs = 0, prendre = nil, rendre = nil, objectifs = { [1] = { map = 1413, x = 0.639, y = 0.46, points = { { map = 1413, x = 0.639, y = 0.46, n = 3 }, { map = 1413, x = 0.627, y = 0.503, n = 2 } } }, [2] = { map = 1413, x = 0.627, y = 0.505 } } },
            [97253] = { titre = "Quete 97253", niveau = 0, contributeurs = 0, prendre = nil, rendre = nil, objectifs = { [1] = { map = 1413, x = 0.619, y = 0.444 } } },
            [891] = { titre = "The Guns of Northwatch", niveau = 15, contributeurs = 1, prendre = nil, rendre = { map = 1413, x = 0.623, y = 0.391, pnj = "Captain Thalo'thas Brightsun" }, objectifs = { [2] = { map = 1413, x = 0.605, y = 0.548 } } },
        },
        niveaux = {  },
        services = {  },
    },
}
