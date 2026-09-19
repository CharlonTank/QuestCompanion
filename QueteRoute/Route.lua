-- Route communautaire, generee par tools/merge-route.js a partir des issues [route] sur GitHub. Ne pas editer a la main.
-- ns.route[faction] = { ordre = { questID... }, quetes = { [questID] = { titre, niveau, contributeurs, prendre, rendre, objectifs } }, niveaux = { [niveau] = { duree, n } }, services = { { t = "R"/"A"/"V", map, x, y, nom, n } } }
local _, ns = ...
ns.route = {
    ["Horde"] = {
        ordre = { 890, 892, 888, 853, 871, 887, 895, 92706, 97253, 3281, 872, 744, 264, 962, 869, 5041, 97003 },
        quetes = {
            [890] = { titre = "The Missing Shipment", niveau = 15, contributeurs = 1, prendre = { map = 1413, x = 0.627, y = 0.363 }, rendre = { map = 1413, x = 0.633, y = 0.384, pnj = "Wharfmaster Dizzywig" }, objectifs = {  } },
            [892] = { titre = "The Missing Shipment", niveau = 15, contributeurs = 1, prendre = { map = 1413, x = 0.633, y = 0.384 }, rendre = { map = 1413, x = 0.627, y = 0.363, pnj = "Gazlowe" }, objectifs = {  } },
            [888] = { titre = "Stolen Booty", niveau = 15, contributeurs = 1, prendre = { map = 1413, x = 0.627, y = 0.363 }, rendre = nil, objectifs = {  } },
            [853] = { titre = "Apothecary Zamah", niveau = 15, contributeurs = 1, prendre = { map = 1413, x = 0.515, y = 0.302 }, rendre = { map = 1456, x = 0.231, y = 0.211, pnj = "Apothecary Zamah" }, objectifs = {  } },
            [871] = { titre = "Disrupt the Attacks", niveau = 15, contributeurs = 1, prendre = nil, rendre = { map = 1413, x = 0.515, y = 0.309, pnj = "Thork" }, objectifs = {  } },
            [887] = { titre = "Southsea Freebooters", niveau = 15, contributeurs = 1, prendre = nil, rendre = { map = 1413, x = 0.627, y = 0.363, pnj = "Gazlowe" }, objectifs = {  } },
            [895] = { titre = "WANTED: Baron Longshore", niveau = 15, contributeurs = 1, prendre = nil, rendre = { map = 1413, x = 0.627, y = 0.363, pnj = "Gazlowe" }, objectifs = {  } },
            [92706] = { titre = "WANTED: Bruuz", niveau = 15, contributeurs = 1, prendre = nil, rendre = { map = 1413, x = 0.627, y = 0.363, pnj = "Gazlowe" }, objectifs = { [1] = { map = 1413, x = 0.648, y = 0.391 } } },
            [97253] = { titre = "Parts and Pieces", niveau = 15, contributeurs = 1, prendre = nil, rendre = { map = 1413, x = 0.631, y = 0.363, pnj = "Wrenix the Wretched" }, objectifs = {  } },
            [3281] = { titre = "Stolen Silver", niveau = 16, contributeurs = 1, prendre = { map = 1413, x = 0.519, y = 0.303 }, rendre = nil, objectifs = {  } },
            [872] = { titre = "The Disruption Ends", niveau = 16, contributeurs = 1, prendre = { map = 1413, x = 0.515, y = 0.308 }, rendre = nil, objectifs = {  } },
            [744] = { titre = "Preparation for Ceremony", niveau = 16, contributeurs = 1, prendre = { map = 1456, x = 0.378, y = 0.594 }, rendre = { map = 1456, x = 0.376, y = 0.599, pnj = "Eyahn Eagletalon" }, objectifs = { [1] = { map = 1412, x = 0.331, y = 0.324, points = { { map = 1412, x = 0.331, y = 0.324, n = 3 }, { map = 1412, x = 0.327, y = 0.3, n = 2 }, { map = 1412, x = 0.324, y = 0.346, n = 1 } } }, [2] = { map = 1412, x = 0.333, y = 0.318, points = { { map = 1412, x = 0.333, y = 0.318, n = 2 }, { map = 1412, x = 0.327, y = 0.338, n = 2 }, { map = 1412, x = 0.334, y = 0.354, n = 2 } } } } },
            [264] = { titre = "Until Death Do Us Part", niveau = 16, contributeurs = 1, prendre = { map = 1456, x = 0.282, y = 0.255 }, rendre = nil, objectifs = {  } },
            [962] = { titre = "Serpentbloom", niveau = 16, contributeurs = 1, prendre = { map = 1456, x = 0.231, y = 0.211 }, rendre = nil, objectifs = {  } },
            [869] = { titre = "Raptor Thieves", niveau = 16, contributeurs = 1, prendre = nil, rendre = { map = 1413, x = 0.519, y = 0.303, pnj = "Gazrog" }, objectifs = {  } },
            [5041] = { titre = "Supplies for the Crossroads", niveau = 16, contributeurs = 1, prendre = nil, rendre = { map = 1413, x = 0.516, y = 0.308, pnj = "Thork" }, objectifs = {  } },
            [97003] = { titre = "Chol'aruk the Ravener", niveau = 16, contributeurs = 1, prendre = { map = 1413, x = 0.526, y = 0.291 }, rendre = nil, objectifs = {  } },
        },
        niveaux = { [15] = { duree = 5742, n = 1 } },
        services = { { t = "V", map = 1413, x = 0.631, y = 0.371, nom = "Bragok", n = 1 }, { t = "V", map = 1413, x = 0.515, y = 0.303, nom = "Devrak", n = 1 }, { t = "R", map = 1456, x = 0.516, y = 0.546, nom = "Sura Wildmane", n = 1 }, { t = "R", map = 1456, x = 0.496, y = 0.491, nom = "Sunn Ragetotem", n = 1 } },
    },
}
