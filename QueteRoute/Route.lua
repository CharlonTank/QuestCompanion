-- Route communautaire, generee par tools/merge-route.js a partir des issues [route] sur GitHub. Ne pas editer a la main.
-- ns.route[faction] = { ordre = { questID... }, quetes = { [questID] = { titre, niveau, contributeurs, prendre, rendre, objectifs } } }
local _, ns = ...
ns.route = {
    ["Horde"] = {
        ordre = { 93927, 93926, 92579, 93948, 97970, 93317, 92679, 94484, 93949, 92700, 94896, 94897, 92708, 93735, 93736, 93737, 92682, 92698, 92684, 92683, 92516, 92550, 92551, 93951, 92685, 94485, 94486, 94487 },
        quetes = {
            [93927] = { titre = "A Last Request", niveau = 8, contributeurs = 1, prendre = { map = 2521, x = 0.423, y = 0.621 }, rendre = { map = 2521, x = 0.456, y = 0.455, pnj = "Constable Aonda" }, objectifs = {  } },
            [93926] = { titre = "Quete 93926", niveau = 8, contributeurs = 1, prendre = nil, rendre = { map = 2521, x = 0.423, y = 0.621, pnj = "Peacekeeper Vaaniel" }, objectifs = {  } },
            [92579] = { titre = "To Valanaar", niveau = 9, contributeurs = 1, prendre = { map = 2521, x = 0.457, y = 0.455, pnj = "Constable Aonda" }, rendre = { map = 2521, x = 0.662, y = 0.766, pnj = "Valennia Stormfist" }, objectifs = {  } },
            [93948] = { titre = "Deliver the Signet", niveau = 9, contributeurs = 1, prendre = { map = 2521, x = 0.457, y = 0.455 }, rendre = { map = 2521, x = 0.662, y = 0.765, pnj = "Talaanis Shadowsong" }, objectifs = {  } },
            [97970] = { titre = "Camping 101: Mining", niveau = 9, contributeurs = 1, prendre = { map = 2521, x = 0.417, y = 0.448 }, rendre = nil, objectifs = {  } },
            [93317] = { titre = "Crab Season", niveau = 9, contributeurs = 1, prendre = { map = 2521, x = 0.606, y = 0.727 }, rendre = nil, objectifs = {  } },
            [92679] = { titre = "Blood Tithe", niveau = 9, contributeurs = 1, prendre = { map = 2521, x = 0.621, y = 0.733 }, rendre = { map = 2521, x = 0.467, y = 0.819, pnj = "Aamelia Windfield" }, objectifs = {  } },
            [94484] = { titre = "Unnerving Silence", niveau = 9, contributeurs = 1, prendre = { map = 2521, x = 0.64, y = 0.751 }, rendre = { map = 2521, x = 0.617, y = 0.392, pnj = "Elegael Thornpaw" }, objectifs = {  } },
            [93949] = { titre = "Bugged", niveau = 9, contributeurs = 1, prendre = { map = 2521, x = 0.662, y = 0.766, pnj = "Valennia Stormfist" }, rendre = { map = 2521, x = 0.662, y = 0.766, pnj = "Valennia Stormfist" }, objectifs = {  } },
            [92700] = { titre = "The Grand Skyseer", niveau = 9, contributeurs = 1, prendre = { map = 2521, x = 0.662, y = 0.766 }, rendre = { map = 2521, x = 0.592, y = 0.798, pnj = "Ayessa Dawnsinger" }, objectifs = {  } },
            [94896] = { titre = "Aid For The Refugees", niveau = 9, contributeurs = 1, prendre = { map = 2521, x = 0.659, y = 0.744 }, rendre = nil, objectifs = {  } },
            [94897] = { titre = "The Fate of a Loved One", niveau = 9, contributeurs = 1, prendre = { map = 2521, x = 0.659, y = 0.744 }, rendre = nil, objectifs = {  } },
            [92708] = { titre = "A Grand Adventure", niveau = 9, contributeurs = 1, prendre = { map = 2521, x = 0.592, y = 0.798, pnj = "Ayessa Dawnsinger" }, rendre = { map = 2521, x = 0.591, y = 0.797, pnj = "Ayessa Dawnsinger" }, objectifs = {  } },
            [93735] = { titre = "The Broken Construct", niveau = 9, contributeurs = 1, prendre = { map = 2521, x = 0.592, y = 0.798 }, rendre = { map = 2521, x = 0.591, y = 0.73, pnj = "Riaani Nightwind" }, objectifs = {  } },
            [93736] = { titre = "Unwelcome Spirits", niveau = 9, contributeurs = 1, prendre = { map = 2521, x = 0.582, y = 0.784 }, rendre = nil, objectifs = {  } },
            [93737] = { titre = "The Broken Construct", niveau = 9, contributeurs = 1, prendre = { map = 2521, x = 0.591, y = 0.73 }, rendre = nil, objectifs = {  } },
            [92682] = { titre = "Make Yourself Useful", niveau = 9, contributeurs = 1, prendre = { map = 2521, x = 0.467, y = 0.819 }, rendre = { map = 2521, x = 0.468, y = 0.817, pnj = "Aamelia Windfield" }, objectifs = {  } },
            [92698] = { titre = "What Is My Purpose?", niveau = 9, contributeurs = 1, prendre = { map = 2521, x = 0.487, y = 0.781 }, rendre = { map = 2521, x = 0.467, y = 0.819, pnj = "Aamelia Windfield" }, objectifs = {  } },
            [92684] = { titre = "Ornery Ornery Galestriders", niveau = 9, contributeurs = 1, prendre = { map = 2521, x = 0.467, y = 0.818, pnj = "Aamelia Windfield" }, rendre = { map = 2521, x = 0.475, y = 0.785, pnj = "Aamelia Windfield" }, objectifs = {  } },
            [92683] = { titre = "Flutterfly Dust", niveau = 9, contributeurs = 1, prendre = { map = 2521, x = 0.466, y = 0.817 }, rendre = { map = 2521, x = 0.467, y = 0.819, pnj = "Aamelia Windfield" }, objectifs = {  } },
            [92516] = { titre = "Quete 92516", niveau = 9, contributeurs = 1, prendre = nil, rendre = { map = 2521, x = 0.444, y = 0.45, pnj = "Teeri Wellwind" }, objectifs = {  } },
            [92550] = { titre = "Quete 92550", niveau = 9, contributeurs = 1, prendre = nil, rendre = { map = 2521, x = 0.456, y = 0.455, pnj = "Constable Aonda" }, objectifs = { [3] = { map = 2521, x = 0.502, y = 0.568 } } },
            [92551] = { titre = "Quete 92551", niveau = 9, contributeurs = 1, prendre = nil, rendre = { map = 2521, x = 0.452, y = 0.452, pnj = "Danarii Bellowveil" }, objectifs = {  } },
            [93951] = { titre = "Quete 93951", niveau = 9, contributeurs = 1, prendre = nil, rendre = { map = 2521, x = 0.449, y = 0.442, pnj = "Taleen Shimmerthread" }, objectifs = {  } },
            [92685] = { titre = "The Hills Have Eyes", niveau = 10, contributeurs = 1, prendre = { map = 2521, x = 0.467, y = 0.819 }, rendre = nil, objectifs = {  } },
            [94485] = { titre = "Tears of the Lady", niveau = 10, contributeurs = 1, prendre = { map = 2521, x = 0.617, y = 0.392 }, rendre = nil, objectifs = {  } },
            [94486] = { titre = "Feathers for Binding", niveau = 10, contributeurs = 1, prendre = { map = 2521, x = 0.617, y = 0.392 }, rendre = nil, objectifs = {  } },
            [94487] = { titre = "Unwanted and Unworthy", niveau = 10, contributeurs = 1, prendre = { map = 2521, x = 0.617, y = 0.392 }, rendre = nil, objectifs = {  } },
        },
    },
}
