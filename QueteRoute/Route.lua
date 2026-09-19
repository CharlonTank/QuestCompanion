-- Route communautaire, generee par tools/merge-route.js a partir des issues [route] sur GitHub. Ne pas editer a la main.
-- ns.route[faction] = { ordre = { questID... }, quetes = { [questID] = { titre, niveau, contributeurs, prendre, rendre, objectifs } }, niveaux = { [niveau] = { duree, n } }, services = { { t = "R"/"A"/"V", map, x, y, nom, n } } }
local _, ns = ...
ns.route = {
    ["Horde"] = {
        ordre = { 92947, 93065, 93958, 92646, 93836, 93090, 95349, 97244, 97245, 97257, 92693, 92703, 97243 },
        quetes = {
            [92947] = { titre = "Making Our Move", niveau = 13, contributeurs = 1, prendre = { map = 2521, x = 0.612, y = 0.71 }, rendre = { map = 2521, x = 0.638, y = 0.505, pnj = "Hyusaa Quickbreeze" }, objectifs = { [1] = { map = 2521, x = 0.62, y = 0.516, points = { { map = 2521, x = 0.62, y = 0.516, n = 5 }, { map = 2521, x = 0.613, y = 0.505, n = 3 } } }, [2] = { map = 2521, x = 0.62, y = 0.517, points = { { map = 2521, x = 0.62, y = 0.517, n = 5 }, { map = 2521, x = 0.628, y = 0.532, n = 1 } } }, [3] = { map = 2521, x = 0.601, y = 0.517, points = { { map = 2521, x = 0.601, y = 0.517, n = 3 }, { map = 2521, x = 0.625, y = 0.535, n = 1 }, { map = 2521, x = 0.622, y = 0.516, n = 1 } } }, [4] = { map = 2521, x = 0.638, y = 0.505 } } },
            [93065] = { titre = "Prepare for Battle", niveau = 13, contributeurs = 1, prendre = nil, rendre = { map = 2521, x = 0.612, y = 0.71, pnj = "Valennia Stormfist" }, objectifs = {  } },
            [93958] = { titre = "The Inner Sanctum", niveau = 14, contributeurs = 1, prendre = { map = 2521, x = 0.638, y = 0.505 }, rendre = { map = 2521, x = 0.652, y = 0.504, pnj = "Valennia Stormfist" }, objectifs = {  } },
            [92646] = { titre = "Confront Lorthuna", niveau = 14, contributeurs = 1, prendre = { map = 2521, x = 0.652, y = 0.504 }, rendre = { map = 2521, x = 0.591, y = 0.797, pnj = "Ayessa Dawnsinger" }, objectifs = { [1] = { map = 2521, x = 0.711, y = 0.504 } } },
            [93836] = { titre = "The Fate of Zephras", niveau = 14, contributeurs = 1, prendre = { map = 2521, x = 0.591, y = 0.797 }, rendre = { map = 2521, x = 0.662, y = 0.766, pnj = "Talaanis Shadowsong" }, objectifs = { [1] = { map = 2521, x = 0.662, y = 0.766 } } },
            [93090] = { titre = "What Comes Next", niveau = 14, contributeurs = 1, prendre = { map = 2521, x = 0.662, y = 0.766 }, rendre = { map = 2521, x = 0.592, y = 0.798, pnj = "Ayessa Dawnsinger" }, objectifs = {  } },
            [95349] = { titre = "The Earthen Ring", niveau = 14, contributeurs = 1, prendre = { map = 2521, x = 0.592, y = 0.798 }, rendre = nil, objectifs = {  } },
            [97244] = { titre = "Call of Fire", niveau = 14, contributeurs = 1, prendre = { map = 2521, x = 0.513, y = 0.861 }, rendre = { map = 2521, x = 0.512, y = 0.861, pnj = "Olariaan Swiftburn" }, objectifs = { [1] = { map = 2521, x = 0.645, y = 0.637 } } },
            [97245] = { titre = "Call of Fire", niveau = 14, contributeurs = 1, prendre = { map = 2521, x = 0.512, y = 0.861 }, rendre = { map = 2521, x = 0.512, y = 0.861, pnj = "Olariaan Swiftburn" }, objectifs = { [1] = { map = 2521, x = 0.426, y = 0.696 } } },
            [97257] = { titre = "Call of Fire", niveau = 14, contributeurs = 1, prendre = { map = 2521, x = 0.512, y = 0.861 }, rendre = { map = 2521, x = 0.583, y = 0.786, pnj = "Sessaria Skystride" }, objectifs = { [1] = { map = 2521, x = 0.512, y = 0.86 }, [2] = { map = 2521, x = 0.583, y = 0.789 } } },
            [92693] = { titre = "Standing Our Ground", niveau = 14, contributeurs = 1, prendre = nil, rendre = { map = 2521, x = 0.475, y = 0.784, pnj = "Aamelia Windfield" }, objectifs = { [1] = { map = 2521, x = 0.467, y = 0.819 }, [2] = { map = 2521, x = 0.475, y = 0.785 } } },
            [92703] = { titre = "Deliver the News", niveau = 14, contributeurs = 1, prendre = { map = 2521, x = 0.475, y = 0.784 }, rendre = { map = 2521, x = 0.621, y = 0.733, pnj = "Alvarion Windfield" }, objectifs = {  } },
            [97243] = { titre = "Call of Fire", niveau = 14, contributeurs = 1, prendre = nil, rendre = { map = 2521, x = 0.513, y = 0.861, pnj = "Olariaan Swiftburn" }, objectifs = {  } },
        },
        niveaux = {  },
        services = { { t = "A", map = 2521, x = 0.622, y = 0.727, nom = "Donaal Downbreeze", n = 1 }, { t = "R", map = 2521, x = 0.597, y = 0.759, nom = "Ergaan Eastwind", n = 1 } },
    },
}
