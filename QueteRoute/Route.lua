-- Route communautaire, generee par tools/merge-route.js a partir des issues [route] sur GitHub. Ne pas editer a la main.
-- ns.route[faction] = { ordre = { questID... }, quetes = { [questID] = { titre, niveau, contributeurs, prendre, rendre, objectifs } }, niveaux = { [niveau] = { duree, n } }, services = { { t = "R"/"A"/"V", map, x, y, nom, n } } }
local _, ns = ...
ns.route = {
    ["Horde"] = {
        ordre = { 93320, 92642, 92645 },
        quetes = {
            [93320] = { titre = "Tower Defense", niveau = 13, contributeurs = 1, prendre = { map = 2521, x = 0.662, y = 0.766 }, rendre = { map = 2521, x = 0.696, y = 0.671, pnj = "Yorana Windyreed" }, objectifs = {  } },
            [92642] = { titre = "Disrupting Logistics", niveau = 13, contributeurs = 1, prendre = { map = 2521, x = 0.696, y = 0.671, pnj = "Yorana Windyreed" }, rendre = { map = 2521, x = 0.696, y = 0.671, pnj = "Yorana Windyreed" }, objectifs = { [1] = { map = 2521, x = 0.665, y = 0.677, points = { { map = 2521, x = 0.665, y = 0.677, n = 2 }, { map = 2521, x = 0.653, y = 0.659, n = 2 } } }, [2] = { map = 2521, x = 0.652, y = 0.662, points = { { map = 2521, x = 0.652, y = 0.662, n = 6 }, { map = 2521, x = 0.663, y = 0.677, n = 1 } } } } },
            [92645] = { titre = "Breaking the Breaker", niveau = 13, contributeurs = 1, prendre = { map = 2521, x = 0.696, y = 0.671 }, rendre = { map = 2521, x = 0.696, y = 0.671, pnj = "Yorana Windyreed" }, objectifs = { [1] = { map = 2521, x = 0.658, y = 0.654 } } },
        },
        niveaux = {  },
        services = {  },
    },
}
