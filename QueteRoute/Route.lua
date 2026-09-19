-- Route communautaire, generee par tools/merge-route.js a partir des issues [route] sur GitHub. Ne pas editer a la main.
-- ns.route[faction] = { ordre = { questID... }, quetes = { [questID] = { titre, niveau, contributeurs, prendre, rendre, objectifs } } }
local _, ns = ...
ns.route = {
    ["Horde"] = {
        ordre = { 93736, 94896, 94897, 93165, 94487, 94488, 94489, 94485, 94486, 93459, 94490 },
        quetes = {
            [93736] = { titre = "Quete 93736", niveau = 0, contributeurs = 0, prendre = nil, rendre = nil, objectifs = { [1] = { map = 2521, x = 0.581, y = 0.313, points = { { map = 2521, x = 0.581, y = 0.313, n = 8 }, { map = 2521, x = 0.59, y = 0.343, n = 1 }, { map = 2521, x = 0.575, y = 0.341, n = 1 } } } } },
            [94896] = { titre = "Quete 94896", niveau = 0, contributeurs = 0, prendre = nil, rendre = nil, objectifs = { [1] = { map = 2521, x = 0.569, y = 0.336, points = { { map = 2521, x = 0.569, y = 0.336, n = 3 }, { map = 2521, x = 0.591, y = 0.343, n = 2 }, { map = 2521, x = 0.575, y = 0.315, n = 2 }, { map = 2521, x = 0.59, y = 0.317, n = 1 } } } } },
            [94897] = { titre = "Quete 94897", niveau = 0, contributeurs = 0, prendre = nil, rendre = nil, objectifs = { [1] = { map = 2521, x = 0.571, y = 0.294 } } },
            [93165] = { titre = "Mercy Falls on Deaf Ears", niveau = 10, contributeurs = 1, prendre = { map = 2521, x = 0.638, y = 0.361 }, rendre = { map = 2521, x = 0.638, y = 0.361, pnj = "Vayn Moongaze" }, objectifs = { [1] = { map = 2521, x = 0.627, y = 0.382, points = { { map = 2521, x = 0.627, y = 0.382, n = 4 }, { map = 2521, x = 0.631, y = 0.363, n = 4 }, { map = 2521, x = 0.639, y = 0.373, n = 1 } } } } },
            [94487] = { titre = "Quete 94487", niveau = 10, contributeurs = 1, prendre = nil, rendre = { map = 2521, x = 0.618, y = 0.391, pnj = "Elegael Thornpaw" }, objectifs = { [1] = { map = 2521, x = 0.626, y = 0.384, points = { { map = 2521, x = 0.626, y = 0.384, n = 6 }, { map = 2521, x = 0.632, y = 0.375, n = 2 }, { map = 2521, x = 0.64, y = 0.367, n = 1 } } } } },
            [94488] = { titre = "The Ties That Bind", niveau = 11, contributeurs = 1, prendre = { map = 2521, x = 0.618, y = 0.391 }, rendre = { map = 2521, x = 0.618, y = 0.391, pnj = "Elegael Thornpaw" }, objectifs = { [1] = { map = 2521, x = 0.654, y = 0.369 } } },
            [94489] = { titre = "The Wounds of Betrayal", niveau = 11, contributeurs = 1, prendre = { map = 2521, x = 0.618, y = 0.391 }, rendre = { map = 2521, x = 0.618, y = 0.391, pnj = "Elegael Thornpaw" }, objectifs = { [1] = { map = 2521, x = 0.648, y = 0.348, points = { { map = 2521, x = 0.648, y = 0.348, n = 2 }, { map = 2521, x = 0.658, y = 0.334, n = 2 }, { map = 2521, x = 0.642, y = 0.32, n = 1 } } }, [2] = { map = 2521, x = 0.645, y = 0.347 } } },
            [94485] = { titre = "Quete 94485", niveau = 11, contributeurs = 1, prendre = nil, rendre = { map = 2521, x = 0.618, y = 0.391, pnj = "Elegael Thornpaw" }, objectifs = { [1] = { map = 2521, x = 0.595, y = 0.399, points = { { map = 2521, x = 0.595, y = 0.399, n = 5 }, { map = 2521, x = 0.589, y = 0.387, n = 1 }, { map = 2521, x = 0.606, y = 0.388, n = 1 } } } } },
            [94486] = { titre = "Quete 94486", niveau = 11, contributeurs = 1, prendre = nil, rendre = { map = 2521, x = 0.618, y = 0.391, pnj = "Elegael Thornpaw" }, objectifs = { [1] = { map = 2521, x = 0.608, y = 0.383, points = { { map = 2521, x = 0.608, y = 0.383, n = 3 }, { map = 2521, x = 0.625, y = 0.382, n = 2 }, { map = 2521, x = 0.562, y = 0.408, n = 2 }, { map = 2521, x = 0.575, y = 0.401, n = 1 } } } } },
            [93459] = { titre = "Quete 93459", niveau = 12, contributeurs = 1, prendre = nil, rendre = { map = 2521, x = 0.637, y = 0.361, pnj = "Vayn Moongaze" }, objectifs = {  } },
            [94490] = { titre = "Ripped Missive", niveau = 12, contributeurs = 1, prendre = { map = 2521, x = 0.59, y = 0.343 }, rendre = nil, objectifs = {  } },
        },
    },
}
