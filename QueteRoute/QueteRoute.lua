local addonName, ns = ...
local PREFIX = "|cff00ff88[QueteRoute]|r "

-- Client Midnight (Forever) : certaines valeurs (noms d'unites, lignes d'infobulle) sont "secretes" et interdites
-- aux addons dans certains contextes. On les ignore plutot que de planter.
local function estSecret(v) return issecretvalue and issecretvalue(v) or false end
local function nomUnite(unit)
    local n = UnitName(unit)
    if n == nil or estSecret(n) then return nil end
    return n
end

-- ================================================================ Utilitaires
local function position()
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not map then return end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
    if not ok or not pos then return map end
    return map, math.floor(pos.x * 1000 + 0.5) / 1000, math.floor(pos.y * 1000 + 0.5) / 1000
end

local function titreQuete(qid)
    return (C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(qid)) or ("Quete " .. qid)
end

local function questIndex(qid)
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then return C_QuestLog.GetLogIndexForQuestID(qid) end
    if GetQuestLogIndexByID then local i = GetQuestLogIndexByID(qid); if i and i > 0 then return i end end
end

local function queteComplete(qid)
    return C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(qid)
end

local function queteDejaFaite(qid)
    return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(qid)
end

local function objectifs(qid)
    return (C_QuestLog and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(qid)) or {}
end

-- Niveau de la quete (couleur de difficulte) : orange a partir de +3, rouge a partir de +5 par rapport au joueur
local function niveauQuete(qid)
    local idx = questIndex(qid)
    if not idx then return end
    if C_QuestLog and C_QuestLog.GetInfo then
        local info = C_QuestLog.GetInfo(idx)
        return info and (info.difficultyLevel or info.level)
    elseif GetQuestLogTitle then
        local _, lvl = GetQuestLogTitle(idx)
        return lvl
    end
end

-- Seules les quetes suivies dans le suivi de quetes sont proposees : retire le suivi d'une quete pour l'ignorer.
-- (/route suivi pour proposer toutes les quetes du journal)
local function suivie(qid)
    if C_QuestLog and C_QuestLog.GetQuestWatchType then return C_QuestLog.GetQuestWatchType(qid) ~= nil end
    local idx = questIndex(qid)
    return idx and IsQuestWatched and IsQuestWatched(idx) or false
end

local function tropDure(qid)
    return not QueteRouteDB.toutesQuetes and not suivie(qid)
end

-- ================================================================ Enregistrement du parcours
-- Chaque evenement : { k = "A"/"O"/"T", q = questID, t = heure, lvl = niveau, map=, x=, y=, npc=, n = titre, i = index objectif }
local cle                    -- "Perso-Royaume"
local pnjDialogue = {}       -- questID -> nom du PNJ vu dans le dialogue de quete
local etatObjectifs = {}     -- questID -> { [i] = { fini=, fait= } }
-- Quetes "en zone" : tu es dans leur zone d'objectif. Deux signaux, sans aucun timer :
--  1. le jeu marque la quete comme proche (hasLocalPOI, ce que le suivi de quetes utilise pour la mettre en avant)
--  2. des cibles de cette quete sont visibles autour de toi (barres de nom, via QueteCibles)
-- Retourne un ensemble { [questID] = true }
function QueteRoute_QuetesEnZone()
    local res = {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.questID and info.hasLocalPOI then res[info.questID] = true end
        end
    end
    if QueteCibles_QuetesAvecCiblesVisibles then
        for qid in pairs(QueteCibles_QuetesAvecCiblesVisibles()) do res[qid] = true end
    end
    return res
end

local function journal()
    QueteRouteDB.journal[cle] = QueteRouteDB.journal[cle] or {}
    return QueteRouteDB.journal[cle]
end

local function enregistrer(ev)
    if QueteRouteDB.enregistrer == false then return end
    ev.t = time()
    ev.lvl = UnitLevel("player")
    ev.map, ev.x, ev.y = position()
    local j = journal()
    j[#j + 1] = ev
end

-- ================================================================ Passage de niveau (message facon RestedXP)
-- Temps de jeu via RequestTimePlayed, sans afficher la ligne "Temps joue" de Blizzard dans le chat
local framesChatCoupes = {}
local attenteTemps = nil        -- fonction a appeler a la reponse

local function demanderTempsJoue(cb)
    attenteTemps = cb
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame" .. i]
        if f and f:IsEventRegistered("TIME_PLAYED_MSG") then f:UnregisterEvent("TIME_PLAYED_MSG"); framesChatCoupes[#framesChatCoupes + 1] = f end
    end
    RequestTimePlayed()
end

local function reponseTempsJoue(total, niveau)
    for _, f in ipairs(framesChatCoupes) do f:RegisterEvent("TIME_PLAYED_MSG") end
    wipe(framesChatCoupes)
    local cb = attenteTemps; attenteTemps = nil
    if cb then cb(total or 0, niveau or 0) end
end

local function duree(sec, avecSecondes)
    sec = math.floor(sec or 0)
    local h, m, s = math.floor(sec / 3600), math.floor((sec % 3600) / 60), sec % 60
    if avecSecondes then
        if h > 0 then return ("%dh %02dm %02ds"):format(h, m, s) end
        return ("%dm %02ds"):format(m, s)
    end
    if h > 0 then return ("%dh %02dm"):format(h, m) end
    return ("%dm"):format(m)
end

local function debutsNiveaux()
    QueteRouteDB.niveaux = QueteRouteDB.niveaux or {}
    QueteRouteDB.niveaux[cle] = QueteRouteDB.niveaux[cle] or {}
    return QueteRouteDB.niveaux[cle]
end

-- A la connexion : on note quand le niveau actuel a commence (temps total - temps sur ce niveau)
local function initNiveau()
    demanderTempsJoue(function(total, surNiveau)
        local d = debutsNiveaux()
        local lvl = UnitLevel("player")
        if not d[lvl] then d[lvl] = total - surNiveau end
    end)
end

local function annoncerNiveau(nouveau)
    demanderTempsJoue(function(total)
        local d = debutsNiveaux()
        local precedent = nouveau - 1
        local dureePrec = d[precedent] and (total - d[precedent]) or nil
        d[nouveau] = total
        enregistrer({ k = "L", lvl = nouveau, total = total, d = dureePrec })

        local route = ns.route and ns.route[UnitFactionGroup("player") or "Neutral"]
        local commu = route and route.niveaux and route.niveaux[precedent]
        -- Format RestedXP : "Niveau 14 -> 15 : 1h 12m 33s"
        local gros = dureePrec and ("Niveau %d -> %d : %s"):format(precedent, nouveau, duree(dureePrec, true))
            or ("Niveau %d !"):format(nouveau)
        if RaidNotice_AddMessage and RaidWarningFrame then
            RaidNotice_AddMessage(RaidWarningFrame, gros, ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.8, b = 0 })
        else
            UIErrorsFrame:AddMessage(gros, 1, 0.8, 0)
        end
        local detail = "|cff00ff88[QueteRoute]|r " .. gros
        if dureePrec and commu and commu.duree then
            local ecart = dureePrec - commu.duree
            detail = detail .. (" (communaute : %s, %s%s|r)"):format(duree(commu.duree, true),
                ecart <= 0 and "|cff00ff00-" or "|cffff6060+", duree(math.abs(ecart), true))
        end
        detail = detail .. (". Temps de jeu total : %s."):format(duree(total, true))
        print(detail)
    end)
end

local function surveillerObjectifs()
    for qid, etat in pairs(etatObjectifs) do
        if not questIndex(qid) then etatObjectifs[qid] = nil end
    end
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return end
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then
            local qid = info.questID
            local etat = etatObjectifs[qid]
            local objs = objectifs(qid)
            if not etat then
                etat = {}
                for k, o in ipairs(objs) do etat[k] = { fini = o.finished, fait = o.numFulfilled or 0 } end
                etatObjectifs[qid] = etat
            else
                for k, o in ipairs(objs) do
                    local e = etat[k] or { fini = false, fait = 0 }
                    local fait = o.numFulfilled or 0
                    -- On note la position a chaque progres (objet ramasse, mob tue, PNJ trouve) et a la fin,
                    -- en evitant les doublons trop proches : c'est ce qui permet de tracer un parcours
                    if (o.finished and not e.fini) or fait > e.fait then
                        local map, x, y = position()
                        local dx, dy = (x or 0) - (e.x or -1), (y or 0) - (e.y or -1)
                        local loin = (map ~= e.map) or (dx * dx + dy * dy) > 0.003 * 0.003
                        if loin or (o.finished and not e.fini) then
                            enregistrer({ k = "O", q = qid, i = k, f = o.finished and 1 or 0 })
                            e.map, e.x, e.y = map, x, y
                        end
                    end
                    etat[k] = { fini = o.finished, fait = fait, map = e.map, x = e.x, y = e.y }
                end
            end
        end
    end
end

-- ================================================================ Suivi de la route communautaire
local frame = CreateFrame("Frame", "QueteRouteFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
frame:SetSize(300, 110)
frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
frame:SetMovable(true); frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    QueteRouteDB.pos = { p, rp, x, y }
end)
frame:SetClampedToScreen(true)
if frame.SetBackdrop then
    frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
        insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    frame:SetBackdropColor(0, 0, 0, 0.55)
end

local entete = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
entete:SetPoint("TOPLEFT", 8, -6)
entete:SetText("Route communautaire")

local etapeTxt = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
etapeTxt:SetPoint("TOPLEFT", 8, -26)
etapeTxt:SetPoint("RIGHT", -8, 0)
etapeTxt:SetJustifyH("LEFT")
etapeTxt:SetWordWrap(true)

-- Case "a faire" : les actions concretes de l'etape (tuer X, ramasser Y sur Z, parler a W)
local actionTxt = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
actionTxt:SetPoint("TOPLEFT", etapeTxt, "BOTTOMLEFT", 10, -3)
actionTxt:SetPoint("RIGHT", -8, 0)
actionTxt:SetJustifyH("LEFT")
actionTxt:SetWordWrap(true)

local suiteTxt = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
suiteTxt:SetPoint("TOPLEFT", actionTxt, "BOTTOMLEFT", -10, -5)
suiteTxt:SetPoint("RIGHT", -8, 0)
suiteTxt:SetJustifyH("LEFT")
suiteTxt:SetWordWrap(true)

local btnPasser = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
btnPasser:SetSize(70, 20)
btnPasser:SetPoint("BOTTOMRIGHT", -8, 6)
btnPasser:SetText("Passer")

local btnRetour = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
btnRetour:SetSize(70, 20)
btnRetour:SetPoint("RIGHT", btnPasser, "LEFT", -4, 0)
btnRetour:SetText("Retour")

local etapes = {}       -- etapes calculees : { type=, qid=, q=, point={map,x,y,pnj}, dist=, details= }

-- ---- Positions : route communautaire, sinon les points de quete que le client affiche sur la carte
local function mondeDepuisCarte(map, x, y)
    if not (map and x and y and C_Map and C_Map.GetWorldPosFromMapPos) then return end
    local ok, _, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
    if ok and pos then return pos.x, pos.y end
end

local function distanceDepuisJoueur(point)
    if not point or not point.map then return end
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
    if not ok or not pos then return end
    local px, py = mondeDepuisCarte(map, pos.x, pos.y)
    local tx, ty = mondeDepuisCarte(point.map, point.x, point.y)
    if not px or not tx then return end
    return math.sqrt((tx - px) ^ 2 + (ty - py) ^ 2)
end

local function pointClient(qid)
    local map = C_Map.GetBestMapForUnit("player")
    if not map or not C_QuestLog then return end
    if C_QuestLog.GetNextWaypointForMap then
        local ok, x, y = pcall(C_QuestLog.GetNextWaypointForMap, qid, map)
        if ok and x and y and (x > 0 or y > 0) then return { map = map, x = x, y = y } end
    end
    if C_QuestLog.GetQuestsOnMap then
        local ok, list = pcall(C_QuestLog.GetQuestsOnMap, map)
        if ok and list then
            for _, q in ipairs(list) do if q.questID == qid then return { map = map, x = q.x, y = q.y } end end
        end
    end
end

-- ================================================================ Services : reparation (R), auberge (A), vol (V)
-- Appris en jeu (marchand qui repare, aubergiste, maitre de vol), partages via la route communautaire.
-- Les points de vol de la carte viennent en plus de l'API du client quand elle existe.
local TYPES_SERVICE = { R = "Reparer", A = "Auberge", V = "Vol" }
local destinationManuelle = nil    -- { map, x, y, nom } : choisie en cliquant un service, prioritaire sur la route
local attente = 0                  -- delai avant recalcul de l'affichage (utilise par les evenements et les clics)

local function servicesLocaux()
    QueteRouteDB.services = QueteRouteDB.services or {}
    return QueteRouteDB.services
end

local function enregistrerService(t, nom)
    if not nom or nom == "" then return end
    local map, x, y = position()
    if not map or not x then return end
    local liste = servicesLocaux()
    for _, s in ipairs(liste) do
        if s.t == t and s.nom == nom and s.map == map then s.x, s.y = x, y; return end
    end
    liste[#liste + 1] = { t = t, map = map, x = x, y = y, nom = nom }
    enregistrer({ k = "S", s = t, nom = nom })
    print(("|cff00ff88[QueteRoute]|r %s note : %s (partage a la communaute)"):format(TYPES_SERVICE[t] or t, nom))
end

-- Aubergiste : une option de dialogue "Make this inn your home" / "Faire de cette auberge votre foyer"
local function detecterAubergiste()
    local options = {}
    if C_GossipInfo and C_GossipInfo.GetOptions then
        for _, o in ipairs(C_GossipInfo.GetOptions() or {}) do options[#options + 1] = (o.name or ""):lower() end
    elseif GetGossipOptions then
        local t = { GetGossipOptions() }
        for i = 1, #t, 2 do options[#options + 1] = tostring(t[i]):lower(); if t[i + 1] == "binder" then return true end end
    end
    for _, o in ipairs(options) do
        if (o:find("inn") and o:find("home")) or o:find("auberge") or o:find("foyer") then return true end
    end
    return false
end

local function tousLesServices()
    local res = {}
    local route = ns.route and ns.route[UnitFactionGroup("player") or "Neutral"]
    for _, s in ipairs((route and route.services) or {}) do res[#res + 1] = s end
    for _, s in ipairs(servicesLocaux()) do res[#res + 1] = s end
    -- Points de vol connus du client sur la carte courante
    local map = C_Map.GetBestMapForUnit("player")
    if map and C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap then
        local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, map)
        if ok and nodes then
            for _, n in ipairs(nodes) do
                if n.position then
                    res[#res + 1] = { t = "V", map = map, x = n.position.x, y = n.position.y, nom = n.name or "Point de vol", client = true }
                end
            end
        end
    end
    return res
end

local function plusProcheParType()
    local best = {}
    for _, s in ipairs(tousLesServices()) do
        local d = distanceDepuisJoueur(s)
        if d and (not best[s.t] or d < best[s.t].d) then best[s.t] = { s = s, d = d } end
    end
    return best
end

local function durabiliteMin()
    local mini
    for slot = 1, 18 do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            local p = cur / max
            if not mini or p < mini then mini = p end
        end
    end
    return mini
end

-- ---- Cadre "Services"
local svc = CreateFrame("Frame", "QueteRouteServices", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
svc:SetSize(230, 74)
svc:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -260)
svc:SetMovable(true); svc:EnableMouse(true); svc:RegisterForDrag("LeftButton")
svc:SetScript("OnDragStart", svc.StartMoving)
svc:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    QueteRouteDB.posServices = { p, rp, x, y }
end)
svc:SetClampedToScreen(true)
if svc.SetBackdrop then
    svc:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    svc:SetBackdropColor(0, 0, 0, 0.5)
end
local svcTitre = svc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
svcTitre:SetPoint("TOPLEFT", 8, -5)
svcTitre:SetText("Services")
local svcLignes = {}
for i, t in ipairs({ "R", "A", "V" }) do
    local b = CreateFrame("Button", nil, svc)
    b:SetSize(214, 16)
    b:SetPoint("TOPLEFT", 8, -22 - (i - 1) * 17)
    b.txt = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.txt:SetPoint("LEFT"); b.txt:SetPoint("RIGHT"); b.txt:SetJustifyH("LEFT"); b.txt:SetWordWrap(false)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.1)
    b.type = t
    b:SetScript("OnClick", function(self)
        if self.cible then
            if destinationManuelle and destinationManuelle.nom == self.cible.nom then destinationManuelle = nil
            else destinationManuelle = { map = self.cible.map, x = self.cible.x, y = self.cible.y, nom = (TYPES_SERVICE[self.type] or "") .. " : " .. self.cible.nom } end
            attente = 0.1
        end
    end)
    svcLignes[t] = b
end

local function rafraichirServices()
    if not svc:IsShown() then return end
    local best = plusProcheParType()
    local dur = durabiliteMin()
    for t, b in pairs(svcLignes) do
        local e = best[t]
        local libelle = TYPES_SERVICE[t]
        if t == "R" and dur and dur < 0.25 then libelle = ("|cffff4040%s (equipement a %d%%)|r"):format(libelle, math.floor(dur * 100)) end
        if e then
            b.cible = e.s
            local actif = destinationManuelle and destinationManuelle.nom == ((TYPES_SERVICE[t] or "") .. " : " .. e.s.nom)
            b.txt:SetText(("%s%s : %s |cffa0a0a0(%d yards)|r"):format(actif and "|cff00ff88>|r " or "", libelle, e.s.nom, e.d))
        else
            b.cible = nil
            b.txt:SetText(("%s : |cff808080inconnu, a decouvrir|r"):format(libelle))
        end
    end
end

-- ---- Ce que QueteCibles a appris pour une quete (mobs qui lachent l'objet, PNJ a qui rendre)
local function apprisPour(qid)
    local mobs, pnjs, receveur, donneur = {}, {}, nil, nil
    local appris = QueteCiblesDB and QueteCiblesDB.appris and QueteCiblesDB.appris[qid]
    for nom, role in pairs(appris or {}) do
        if role == true then mobs[#mobs + 1] = nom
        elseif role == "pnj" then pnjs[#pnjs + 1] = nom
        elseif role == "rend" then receveur = nom
        elseif role == "donne" then donneur = nom end
    end
    table.sort(mobs); table.sort(pnjs)
    return mobs, pnjs, receveur or donneur
end

-- PNJ (non joueurs) visibles autour de toi : barres de nom, cible, survol
local function pnjVisibles()
    local t = {}
    local function voir(u)
        if UnitExists(u) and not UnitIsPlayer(u) and not UnitCanAttack("player", u) then
            local n = nomUnite(u); if n then t[n] = true end
        end
    end
    voir("target"); voir("mouseover")
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, np in ipairs(C_NamePlate.GetNamePlates()) do
            if np.namePlateUnitToken then voir(np.namePlateUnitToken) end
        end
    end
    return t
end

-- Quetes dont ce PNJ est le donneur d'apres QueteCibles (role "donne") : qid -> titre
local function donneursConnus(nom)
    local res = {}
    local appris = QueteCiblesDB and QueteCiblesDB.appris
    if not appris then return res end
    for qid, noms in pairs(appris) do
        if type(qid) == "number" and noms[nom] == "donne" then res[qid] = titreQuete(qid) end
    end
    return res
end

-- ---- Parcours : pour un objectif connu a plusieurs endroits (objets disperses, PNJ a trouver),
--      on enchaine les spots, le plus proche d'abord, en cochant ceux atteints ou ou l'objectif a progresse
local parcours = {}   -- "qid:k" -> { visites = { [idx] = true }, fait = dernier compteur }

local function spotsObjectif(q, k)
    local o = q and q.objectifs and q.objectifs[k]
    if not o then return {} end
    if o.points and #o.points > 0 then return o.points end
    if o.map then return { o } end
    return {}
end

-- Retourne le prochain spot a visiter, son index et le nombre total
local function prochainSpot(qid, k, q, fait)
    local spots = spotsObjectif(q, k)
    if #spots == 0 then return end
    local cle = qid .. ":" .. k
    local p = parcours[cle]
    if not p then p = { visites = {}, fait = fait or 0 }; parcours[cle] = p end
    -- Spot atteint (a moins de 20 yards) ou objectif qui vient de progresser pres d'un spot : coche
    local plusProche, dMin
    for idx, s in ipairs(spots) do
        local d = distanceDepuisJoueur(s)
        if d and (not dMin or d < dMin) then plusProche, dMin = idx, d end
    end
    if plusProche and dMin and (dMin < 20 or ((fait or 0) > p.fait and dMin < 60)) then p.visites[plusProche] = true end
    p.fait = fait or p.fait
    -- Prochain : le plus proche parmi les non visites ; si tout est visite, on repart de zero
    local best, bestD
    for idx, s in ipairs(spots) do
        if not p.visites[idx] then
            local d = distanceDepuisJoueur(s) or 1e9
            if not bestD or d < bestD then best, bestD = idx, d end
        end
    end
    if not best then wipe(p.visites); best = plusProche or 1 end
    local n = 0
    for _ in pairs(p.visites) do n = n + 1 end
    return spots[best], n + 1, #spots
end

-- Actions concretes d'une quete en cours : "Tuer X (3/8)", "Ramasser Y (0/7) sur Z", "Parler a W"
local VERBES_KILL = { "slain", "killed", "exterminated", "destroyed", "defeated", "eliminated", "hunted", "culled" }
local function actionsPour(qid)
    local lignes = {}
    local sources, pnjs = {}, {}
    for _, r in ipairs((QueteCibles_LignesPour and QueteCibles_LignesPour(qid)) or {}) do
        if r.genre == "mob" and r.detail and not r.fini then
            local cible = r.detail:match("^Lache : (.+)$") or r.detail:match("^Compte pour : (.+)$")
            if cible then sources[cible] = sources[cible] or {}; table.insert(sources[cible], r.nom) end
        elseif r.genre == "pnj" then
            pnjs[#pnjs + 1] = r.nom
        end
    end
    for _, o in ipairs(objectifs(qid)) do
        if not o.finished and o.text then
            local fait, total, nom = o.text:match("^(%d+)%s*/%s*(%d+)%s+(.-)%s*$")
            if not nom then nom, fait, total = o.text:match("^(.-):%s*(%d+)%s*/%s*(%d+)%s*$") end
            local compte = fait and (" (" .. fait .. "/" .. total .. ")") or ""
            if nom then
                local l, kill = nom:lower(), false
                for _, v in ipairs(VERBES_KILL) do
                    if l:sub(-#v - 1) == " " .. v then nom = nom:sub(1, -#v - 2); kill = true break end
                end
                local s = sources[nom] and table.concat(sources[nom], ", ")
                if kill then
                    lignes[#lignes + 1] = "Tuer " .. nom .. compte .. (s and (" (= " .. s .. ")") or "")
                elseif o.type == "item" then
                    lignes[#lignes + 1] = "Ramasser " .. nom .. compte .. (s and (" sur " .. s) or "")
                else
                    lignes[#lignes + 1] = nom .. compte .. (s and (" : " .. s) or "")
                end
            else
                lignes[#lignes + 1] = o.text
            end
        end
    end
    if #pnjs > 0 then lignes[#lignes + 1] = "Parler a / interagir : " .. table.concat(pnjs, ", ") end
    return lignes
end

local function decrireEtape(e, court)
    local titre = (e.q and e.q.titre) or titreQuete(e.qid)
    local pnj = e.point and e.point.pnj
    if e.type == "prendre" then
        return ("%sPrendre |cffffff00%s|r%s"):format(e.visible and "|cff00ff00[PNJ en vue]|r " or "",
            titre, pnj and (" chez " .. pnj) or "")
    elseif e.type == "rendre" then
        return ("Rendre |cffffff00%s|r%s"):format(titre, pnj and (" a " .. pnj) or "")
    else
        local etape = e.spotIndex and e.spotTotal and e.spotTotal > 1 and (" |cffa0d0ff(spot %d/%d)|r"):format(e.spotIndex, e.spotTotal) or ""
        if court then return ("Faire |cffffff00%s|r%s"):format(titre, etape) end
        local reste = {}
        for _, o in ipairs(objectifs(e.qid)) do if not o.finished and o.text then reste[#reste + 1] = o.text end end
        return ("Faire |cffffff00%s|r : %s%s"):format(titre, table.concat(reste, ", "), etape)
    end
end

-- Ligne d'aide sous l'etape : mobs qui lachent l'objet, PNJ / objet a trouver, distance
local function detailsEtape(e)
    local t = {}
    if e.type == "faire" then
        local mobs, pnjs = apprisPour(e.qid)
        if #mobs > 0 then t[#t + 1] = "Lache par : " .. table.concat(mobs, ", ") end
        if #pnjs > 0 then t[#t + 1] = "Interagir avec : " .. table.concat(pnjs, ", ") end
    end
    if e.dist then t[#t + 1] = ("%d yards"):format(e.dist) end
    return table.concat(t, "  |  ")
end

local function calculerEtapes()
    wipe(etapes)
    local route = (ns.route and ns.route[UnitFactionGroup("player") or "Neutral"]) or { ordre = {}, quetes = {} }
    local niveau = UnitLevel("player")
    local vues = {}

    -- 1. Ton journal : quetes a rendre et quetes en cours, triees par distance (la plus proche d'abord)
    local locales = {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            local qid = info and not info.isHeader and info.questID
            if qid and not QueteRouteDB.passes[qid] then
                vues[qid] = true
                local q = route.quetes[qid] or { titre = info.title }
                local e
                if tropDure(qid) then
                    -- Quete non suivie dans le suivi de quetes : on ne la propose pas
                elseif queteComplete(qid) then
                    e = { type = "rendre", qid = qid, q = q, point = q.rendre or pointClient(qid) or q.prendre }
                    if e.point and not e.point.pnj then
                        local pnj
                        if QueteCibles_PNJRendu then
                            local ok, _, texte = pcall(GetQuestLogQuestText, i)
                            pnj = QueteCibles_PNJRendu(qid, ok and texte or nil)
                        else
                            local _, _, p = apprisPour(qid); pnj = p
                        end
                        if pnj then e.point = { map = e.point.map, x = e.point.x, y = e.point.y, pnj = pnj } end
                    end
                else
                    local point, spotIndex, spotTotal
                    for k, o in ipairs(objectifs(qid)) do
                        if not o.finished and q.objectifs and q.objectifs[k] then
                            point, spotIndex, spotTotal = prochainSpot(qid, k, q, o.numFulfilled)
                            if point then break end
                        end
                    end
                    e = { type = "faire", qid = qid, q = q, point = point or pointClient(qid) or (q.objectifs and q.objectifs[1]),
                        spotIndex = spotIndex, spotTotal = spotTotal }
                end
                if e then
                    e.dist = distanceDepuisJoueur(e.point)
                    locales[#locales + 1] = e
                end
            end
        end
    end
    -- Priorite : les quetes dont tu es dans la zone d'abord (la plus proche en premier) ; puis les autres par
    -- distance, un rendu comptant double (on reste ou il y a quelque chose a faire avant d'aller rendre)
    local enZone = QueteRoute_QuetesEnZone()
    for _, e in ipairs(locales) do
        local d = e.dist or 1e8
        if enZone[e.qid] then e.score = -1e9 + d
        else e.score = d * (e.type == "rendre" and 2 or 1) end
    end
    table.sort(locales, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        return a.qid < b.qid
    end)
    for _, e in ipairs(locales) do etapes[#etapes + 1] = e end

    -- 2. La route communautaire : quetes a prendre. Une quete a portee (rayon) ou dont le PNJ donneur est
    --    visible autour de toi passe EN PREMIER : on la prend avant de continuer.
    local rayon = QueteRouteDB.rayon or 200
    local visibles = pnjVisibles()
    local proches, plusTard = {}, {}
    for _, qid in ipairs(route.ordre) do
        local q = route.quetes[qid]
        if q and not vues[qid] and not QueteRouteDB.passes[qid] and not queteDejaFaite(qid) and (q.niveau or 0) <= niveau + 2 then
            local e = { type = "prendre", qid = qid, q = q, point = q.prendre }
            e.dist = distanceDepuisJoueur(e.point)
            local pnj = q.prendre and q.prendre.pnj
            if pnj and visibles[pnj] then
                e.visible = true
                proches[#proches + 1] = e
            elseif e.dist and e.dist <= rayon then
                proches[#proches + 1] = e
            else
                plusTard[#plusTard + 1] = e
            end
        end
    end
    -- PNJ donneurs connus de QueteCibles (nom seul, sans position) visibles autour de toi
    for nom in pairs(visibles) do
        for qid, titre in pairs(donneursConnus(nom)) do
            if not vues[qid] and not QueteRouteDB.passes[qid] and not queteDejaFaite(qid) and not route.quetes[qid] then
                proches[#proches + 1] = { type = "prendre", qid = qid, q = { titre = titre }, point = { pnj = nom }, visible = true }
            end
        end
    end
    table.sort(proches, function(a, b)
        if a.visible ~= b.visible then return a.visible == true end
        return (a.dist or 1e9) < (b.dist or 1e9)
    end)
    -- Ordre final : quetes a prendre a portee, puis ton journal par distance, puis le reste de la route
    local final = {}
    for _, e in ipairs(proches) do final[#final + 1] = e end
    for _, e in ipairs(etapes) do final[#final + 1] = e end
    for _, e in ipairs(plusTard) do final[#final + 1] = e end
    wipe(etapes)
    for i = 1, math.min(#final, 5) do etapes[i] = final[i] end
end

-- Points "quete a prendre" connus de la communaute, pour QueteGPS (quetes pas faites, pas dans le journal, niveau ok)
function QueteRoute_PointsPrendre()
    local res = {}
    local route = ns.route and ns.route[UnitFactionGroup("player") or "Neutral"]
    if not route then return res end
    local niveau = UnitLevel("player")
    for qid, q in pairs(route.quetes) do
        if q.prendre and q.prendre.map and not QueteRouteDB.passes[qid] and not queteDejaFaite(qid) and not questIndex(qid)
            and (q.niveau or 0) <= niveau + 2 then
            res[#res + 1] = { map = q.prendre.map, x = q.prendre.x, y = q.prendre.y,
                nom = (q.titre or titreQuete(qid)) .. (q.prendre.pnj and (" (" .. q.prendre.pnj .. ")") or "") }
        end
    end
    return res
end

local function afficher()
    -- Panneau masque (ex. quand RestedXP guide) : on continue d'enregistrer, mais on ne pilote pas la fleche du GPS
    if not frame:IsShown() then
        rafraichirServices()
        if destinationManuelle then
            local d = distanceDepuisJoueur(destinationManuelle)
            if d and d < 15 then destinationManuelle = nil end
        end
        if QueteGPS then
            if destinationManuelle and QueteGPS.Definir then QueteGPS.Definir(destinationManuelle.map, destinationManuelle.x, destinationManuelle.y, destinationManuelle.nom, ">")
            elseif QueteGPS.Effacer then QueteGPS.Effacer() end
        end
        return
    end
    calculerEtapes()
    rafraichirServices()
    -- Destination choisie a la main (service) : prioritaire jusqu'a l'arrivee (15 yards)
    if destinationManuelle then
        local d = distanceDepuisJoueur(destinationManuelle)
        if d and d < 15 then destinationManuelle = nil
        elseif QueteGPS and QueteGPS.Definir then
            QueteGPS.Definir(destinationManuelle.map, destinationManuelle.x, destinationManuelle.y, destinationManuelle.nom, ">")
            etapeTxt:SetText("|cff00ff88But :|r " .. destinationManuelle.nom .. (d and (" (" .. math.floor(d) .. " yards)") or ""))
            actionTxt:SetText("")
            suiteTxt:SetText("Clique a nouveau le service pour annuler")
            frame:SetHeight(70)
            return
        end
    end
    local e = etapes[1]
    if not e then
        etapeTxt:SetText("|cff00ff88But :|r rien pour l'instant, prends des quetes !")
        actionTxt:SetText("")
        suiteTxt:SetText("Ton parcours est enregistre pour la communaute.")
        if QueteGPS and QueteGPS.Effacer then QueteGPS.Effacer() end
        frame:SetHeight(70)
        return
    end
    -- But : ou aller / quoi faire, en une ligne, avec la distance
    etapeTxt:SetText("|cff00ff88But :|r " .. decrireEtape(e, true) .. (e.dist and (" |cffa0a0a0(%d yards)|r"):format(e.dist) or ""))
    -- A faire : les actions concretes
    local actions = {}
    if e.type == "faire" then
        actions = actionsPour(e.qid)
    elseif e.type == "rendre" then
        actions = { "Rendre la quete" .. (e.point and e.point.pnj and (" a " .. e.point.pnj) or "") }
    elseif e.type == "prendre" then
        actions = { "Prendre la quete" .. (e.point and e.point.pnj and (" chez " .. e.point.pnj) or "") }
    end
    for i, a in ipairs(actions) do actions[i] = "|cffffcc00-|r " .. a end
    actionTxt:SetText(table.concat(actions, "\n"))
    -- Ensuite
    local suite = {}
    for i = 2, math.min(#etapes, 3) do suite[#suite + 1] = "Ensuite : " .. decrireEtape(etapes[i], true) end
    suiteTxt:SetText(table.concat(suite, "\n"))
    if QueteGPS and QueteGPS.Definir then
        if e.point and e.point.map then
            QueteGPS.Definir(e.point.map, e.point.x, e.point.y, decrireEtape(e, true):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""), ">")
        else
            QueteGPS.Effacer()
        end
    end
    frame:SetHeight(44 + math.max(#actions, 1) * 13 + #suite * 13 + 30)
end

btnPasser:SetScript("OnClick", function()
    local e = etapes[1]
    if e then
        QueteRouteDB.passes[e.qid] = true
        QueteRouteDB.ordrePasses[#QueteRouteDB.ordrePasses + 1] = e.qid
        afficher()
    end
end)
btnRetour:SetScript("OnClick", function()
    local qid = table.remove(QueteRouteDB.ordrePasses)
    if qid then QueteRouteDB.passes[qid] = nil; afficher() end
end)

-- ================================================================ Export du parcours
-- Une ligne par evenement, separees par "|" :
--   A;qid;lvl;map;x;y;npc;titre     T;qid;lvl;map;x;y;npc     O;qid;i;f;lvl;map;x;y
local function propre(s)
    local r = tostring(s or ""):gsub("[|;\n]", ",")   -- gsub renvoie 2 valeurs : on n'en garde qu'une
    return r
end
local function exporter()
    local lignes = { "R1;" .. propre(cle) .. ";" .. (UnitFactionGroup("player") or "") }
    for _, ev in ipairs(journal()) do
        if ev.k == "A" then
            lignes[#lignes + 1] = table.concat({ "A", ev.q, ev.lvl or 0, ev.map or 0, ev.x or 0, ev.y or 0, propre(ev.npc), propre(ev.n) }, ";")
        elseif ev.k == "T" then
            lignes[#lignes + 1] = table.concat({ "T", ev.q, ev.lvl or 0, ev.map or 0, ev.x or 0, ev.y or 0, propre(ev.npc), propre(ev.n) }, ";")
        elseif ev.k == "O" then
            lignes[#lignes + 1] = table.concat({ "O", ev.q, ev.i or 0, ev.f or 0, ev.lvl or 0, ev.map or 0, ev.x or 0, ev.y or 0 }, ";")
        elseif ev.k == "L" then
            lignes[#lignes + 1] = table.concat({ "L", ev.lvl or 0, ev.total or 0, ev.d or 0 }, ";")
        elseif ev.k == "S" then
            lignes[#lignes + 1] = table.concat({ "S", ev.s or "?", ev.map or 0, ev.x or 0, ev.y or 0, propre(ev.nom) }, ";")
        end
    end
    return table.concat(lignes, "|")
end

local fenetre
local function ouvrirExport()
    if not fenetre then
        fenetre = CreateFrame("Frame", "QueteRouteExport", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        fenetre:SetSize(520, 300); fenetre:SetPoint("CENTER"); fenetre:SetFrameStrata("DIALOG")
        fenetre:SetMovable(true); fenetre:EnableMouse(true); fenetre:RegisterForDrag("LeftButton")
        fenetre:SetScript("OnDragStart", fenetre.StartMoving); fenetre:SetScript("OnDragStop", fenetre.StopMovingOrSizing)
        if fenetre.SetBackdrop then
            fenetre:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 } })
        end
        local t = fenetre:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        t:SetPoint("TOP", 0, -16); t:SetText("QueteRoute - Export du parcours (Ctrl+A, Ctrl+C, puis issue [route] sur GitHub)")
        local scroll = CreateFrame("ScrollFrame", "QueteRouteExportScroll", fenetre, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 20, -45); scroll:SetPoint("BOTTOMRIGHT", -40, 50)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true); edit:SetFontObject(ChatFontNormal); edit:SetWidth(440); edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function() fenetre:Hide() end)
        scroll:SetScrollChild(edit)
        fenetre.edit = edit
        local fermer = CreateFrame("Button", nil, fenetre, "UIPanelButtonTemplate")
        fermer:SetSize(100, 24); fermer:SetPoint("BOTTOMRIGHT", -20, 16); fermer:SetText("Fermer")
        fermer:SetScript("OnClick", function() fenetre:Hide() end)
    end
    fenetre.edit:SetText(exporter())
    fenetre:Show()
    fenetre.edit:SetFocus(); fenetre.edit:HighlightText()
end

-- ================================================================ Evenements
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("QUEST_DETAIL")
ev:RegisterEvent("QUEST_PROGRESS")
ev:RegisterEvent("QUEST_COMPLETE")
ev:RegisterEvent("QUEST_ACCEPTED")
ev:RegisterEvent("QUEST_TURNED_IN")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("TIME_PLAYED_MSG")
ev:RegisterEvent("MERCHANT_SHOW")
ev:RegisterEvent("TAXIMAP_OPENED")
ev:RegisterEvent("GOSSIP_SHOW")
ev:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
pcall(ev.RegisterEvent, ev, "QUEST_REMOVED")
pcall(ev.RegisterEvent, ev, "QUEST_WATCH_LIST_CHANGED")
pcall(ev.RegisterEvent, ev, "NAME_PLATE_UNIT_ADDED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
ev:RegisterEvent("ZONE_CHANGED")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")

attente = 0
ev:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        QueteRouteDB = QueteRouteDB or {}
        QueteRouteDB.journal = QueteRouteDB.journal or {}
        QueteRouteDB.passes = QueteRouteDB.passes or {}
        QueteRouteDB.ordrePasses = QueteRouteDB.ordrePasses or {}
        if QueteRouteDB.shown == nil then QueteRouteDB.shown = true end
        if QueteRouteDB.pos then
            frame:ClearAllPoints()
            frame:SetPoint(QueteRouteDB.pos[1], UIParent, QueteRouteDB.pos[2], QueteRouteDB.pos[3], QueteRouteDB.pos[4])
        end
        if QueteRouteDB.shown then frame:Show() else frame:Hide() end
        if QueteRouteDB.posServices then
            svc:ClearAllPoints()
            svc:SetPoint(QueteRouteDB.posServices[1], UIParent, QueteRouteDB.posServices[2], QueteRouteDB.posServices[3], QueteRouteDB.posServices[4])
        end
        if QueteRouteDB.servicesShown == false then svc:Hide() else svc:Show() end
    elseif event == "PLAYER_LOGOUT" then
        -- Export pret a l'emploi dans la sauvegarde : le compagnon (companion/QuestCompanion-Sync.ps1) le lit et l'envoie
        if cle then
            QueteRouteDB.exports = QueteRouteDB.exports or {}
            QueteRouteDB.exports[cle] = exporter()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        cle = (nomUnite("player") or "?") .. "-" .. (GetRealmName() or "?")
        wipe(etatObjectifs)
        attente = 1
        C_Timer.After(5, initNiveau)   -- a chaque chargement (connexion ou /reload) : ne note que si le niveau n'est pas deja connu
    elseif event == "TIME_PLAYED_MSG" then
        reponseTempsJoue(arg1, arg2)
    elseif event == "PLAYER_LEVEL_UP" then
        if arg1 and cle then annoncerNiveau(tonumber(arg1)) end
        attente = 0.5
    elseif event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
        local qid = GetQuestID and GetQuestID()
        if qid and qid > 0 and UnitExists("npc") and not UnitIsPlayer("npc") then
            pnjDialogue[qid] = nomUnite("npc")
        end
    elseif event == "MERCHANT_SHOW" then
        if CanMerchantRepair and CanMerchantRepair() and UnitExists("npc") then enregistrerService("R", nomUnite("npc")) end
    elseif event == "TAXIMAP_OPENED" then
        if UnitExists("npc") then enregistrerService("V", nomUnite("npc")) end
    elseif event == "GOSSIP_SHOW" then
        if UnitExists("npc") and detecterAubergiste() then enregistrerService("A", nomUnite("npc")) end
    elseif event == "UPDATE_INVENTORY_DURABILITY" then
        attente = 1
    elseif event == "QUEST_ACCEPTED" then
        local qid = (type(arg2) == "number" and arg2 > 0) and arg2 or arg1
        if qid and cle then
            enregistrer({ k = "A", q = qid, n = titreQuete(qid), npc = pnjDialogue[qid] })
            etatObjectifs[qid] = nil
            attente = 0.5
        end
    elseif event == "QUEST_TURNED_IN" then
        if arg1 and cle then
            enregistrer({ k = "T", q = arg1, npc = pnjDialogue[arg1], n = titreQuete(arg1) })
            etatObjectifs[arg1] = nil
            attente = 0.5
        end
    elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_REMOVED" or event == "PLAYER_LEVEL_UP" or event == "QUEST_WATCH_LIST_CHANGED"
        or event == "NAME_PLATE_UNIT_ADDED" or event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT"
        or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
        attente = 0.5
    end
end)
local periodique = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    -- Recalcul periodique : les distances changent quand tu te deplaces (quete a prendre qui entre dans le rayon)
    periodique = periodique + elapsed
    if periodique > 4 then periodique = 0; if attente <= 0 then attente = 0.01 end end
    if attente > 0 then
        attente = attente - elapsed
        if attente <= 0 and cle then
            surveillerObjectifs()
            afficher()
        end
    end
end)

-- ================================================================ Commandes
SLASH_QUETEROUTE1 = "/route"
SlashCmdList["QUETEROUTE"] = function(msg)
    msg = strtrim((msg or ""):lower())
    if msg == "export" then
        ouvrirExport()
    elseif msg == "passer" then
        btnPasser:Click()
    elseif msg == "retour" then
        btnRetour:Click()
    elseif msg == "reset" then
        wipe(QueteRouteDB.passes); wipe(QueteRouteDB.ordrePasses)
        QueteRouteDB.pos = nil
        frame:ClearAllPoints(); frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
        afficher()
    elseif msg == "services" then
        QueteRouteDB.servicesShown = not (QueteRouteDB.servicesShown ~= false)
        if QueteRouteDB.servicesShown then svc:Show() else svc:Hide() end
        print(PREFIX .. "Cadre Services : " .. (QueteRouteDB.servicesShown and "affiche" or "masque"))
        afficher()
    elseif msg == "stop" then
        destinationManuelle = nil
        afficher()
    elseif msg == "suivi" then
        QueteRouteDB.toutesQuetes = not QueteRouteDB.toutesQuetes
        print(PREFIX .. (QueteRouteDB.toutesQuetes and "Toutes les quetes du journal sont proposees" or "Seules les quetes suivies sont proposees"))
        afficher()
    elseif msg:match("^rayon") then
        local n = tonumber(msg:match("%d+"))
        if n then QueteRouteDB.rayon = n end
        print(PREFIX .. "Rayon de detour pour une quete a prendre : " .. (QueteRouteDB.rayon or 200) .. " yards  (/route rayon 300)")
        afficher()
    elseif msg == "enregistrer" then
        QueteRouteDB.enregistrer = (QueteRouteDB.enregistrer == false) and true or false
        print(PREFIX .. "Enregistrement du parcours : " .. (QueteRouteDB.enregistrer and "actif" or "coupe"))
    elseif msg == "stats" then
        local j = journal()
        local a, t, o = 0, 0, 0
        for _, e in ipairs(j) do if e.k == "A" then a = a + 1 elseif e.k == "T" then t = t + 1 else o = o + 1 end end
        print(PREFIX .. ("Parcours de %s : %d quetes prises, %d rendues, %d objectifs notes. Route chargee : %d quetes."):format(
            cle or "?", a, t, o, #(((ns.route or {})[UnitFactionGroup("player") or "Neutral"] or {}).ordre or {})))
    else
        QueteRouteDB.shown = not QueteRouteDB.shown
        if QueteRouteDB.shown then frame:Show() else frame:Hide() end
        print(PREFIX .. (QueteRouteDB.shown and "affiche" or "masque") .. "  (/route export, passer, retour, reset, enregistrer, stats)")
    end
end
