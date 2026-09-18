local addonName = ...
local PREFIX = "|cffffcc00[QueteGPS]|r "

-- ================================================================ Fenetre
local frame = CreateFrame("Frame", "QueteGPSFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
frame:SetSize(230, 70)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    QueteGPSDB.pos = { p, rp, x, y }
end)
frame:SetClampedToScreen(true)
if frame.SetBackdrop then
    frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
        insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    frame:SetBackdropColor(0, 0, 0, 0.5)
end

local arrow = frame:CreateTexture(nil, "ARTWORK")
arrow:SetSize(44, 44)
arrow:SetPoint("LEFT", frame, "LEFT", 10, 0)
arrow:SetTexture("Interface\\AddOns\\QueteGPS\\arrow.tga")
arrow:SetVertexColor(0.2, 1, 0.2)

local icon = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
icon:SetPoint("LEFT", arrow, "RIGHT", 6, 0)
icon:SetText("?")

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, 0)
title:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
title:SetJustifyH("LEFT")
title:SetWordWrap(false)

local dist = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
dist:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
dist:SetJustifyH("LEFT")

-- ================================================================ Donnees
local candidats = {}      -- { wx=, wy= (monde, pour la distance), mx=, my= (carte, pour la direction), type=, nom= }
local mapCourante
local largeurCarte, hauteurCarte = 1, 1   -- taille de la carte courante en yards (pour corriger le ratio)
local sourcesOK = {}

-- Destination externe (posee par un autre addon, ex. QueteRoute) : prioritaire sur le plus proche
local externe, candidatExterne = nil, nil
local candidatCorps = nil   -- position du corps quand on est un fantome
QueteGPS = QueteGPS or {}
function QueteGPS.Definir(map, x, y, nom, typ)
    externe = { map = map, x = x, y = y, nom = nom or "Destination", type = typ or ">" }
    candidatExterne = nil
end
function QueteGPS.Effacer() externe, candidatExterne = nil, nil end
function QueteGPS.Destination() return externe end

local function mondeDepuisCarte(mapID, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos) then return end
    local ok, _, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
    if ok and pos then return pos.x, pos.y end
end

local function ajouter(mapID, x, y, typ, nom, src)
    if not x or not y or x <= 0 or y <= 0 then return end
    local wx, wy = mondeDepuisCarte(mapID, x, y)
    if not wx then return end
    sourcesOK[src] = (sourcesOK[src] or 0) + 1
    candidats[#candidats + 1] = { wx = wx, wy = wy, mx = x, my = y, type = typ, nom = nom or "?" }
end

local function mesurerCarte(mapID)
    largeurCarte, hauteurCarte = 1, 1
    if C_Map.GetMapWorldSize then
        local ok, w, h = pcall(C_Map.GetMapWorldSize, mapID)
        if ok and w and h and w > 0 and h > 0 then largeurCarte, hauteurCarte = w, h return end
    end
    -- Repli : distance entre les coins, independante de l'orientation des axes monde
    local x0, y0 = mondeDepuisCarte(mapID, 0, 0)
    local x1, y1 = mondeDepuisCarte(mapID, 1, 0)
    local x2, y2 = mondeDepuisCarte(mapID, 0, 1)
    if x0 and x1 and x2 then
        largeurCarte = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
        hauteurCarte = math.sqrt((x2 - x0) ^ 2 + (y2 - y0) ^ 2)
    end
end

local function titreQuete(qid)
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        return C_QuestLog.GetTitleForQuestID(qid)
    end
end

local function collecter()
    wipe(candidats); wipe(sourcesOK)
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if mapID ~= mapCourante then
        mapCourante = mapID
        if mapID then mesurerCarte(mapID) end
    end
    if not mapID then return end

    -- ---- 00. Mort : direction du corps, prioritaire sur tout le reste
    candidatCorps = nil
    if UnitIsGhost("player") then
        local cx, cy
        if C_DeathInfo and C_DeathInfo.GetCorpseMapPosition then
            local ok, pos = pcall(C_DeathInfo.GetCorpseMapPosition, mapID)
            if ok and pos then cx, cy = pos.x, pos.y end
        elseif GetCorpseMapPosition then
            cx, cy = GetCorpseMapPosition()
        end
        if cx and cy and (cx > 0 or cy > 0) then
            local wx, wy = mondeDepuisCarte(mapID, cx, cy)
            if wx then candidatCorps = { wx = wx, wy = wy, mx = cx, my = cy, type = "+", nom = "Ton corps" } end
        end
    end

    -- ---- 0. Destination externe : convertie dans la carte courante pour la direction
    candidatExterne = nil
    if externe then
        local wx, wy = mondeDepuisCarte(externe.map, externe.x, externe.y)
        if wx then
            local mx, my = externe.x, externe.y
            if externe.map ~= mapID then
                mx, my = nil, nil
                if C_Map.GetMapPosFromWorldPos then
                    local okc, continent = pcall(C_Map.GetWorldPosFromMapPos, externe.map, CreateVector2D(externe.x, externe.y))
                    if okc and continent then
                        local ok2, _, pos = pcall(C_Map.GetMapPosFromWorldPos, continent, CreateVector2D(wx, wy), mapID)
                        if ok2 and pos then mx, my = pos.x, pos.y end
                    end
                end
            end
            candidatExterne = { wx = wx, wy = wy, mx = mx, my = my, type = externe.type, nom = externe.nom }
        end
    end

    -- ---- 1. Points "?" : quetes terminees dans le journal
    local surCarte = {}
    if C_QuestLog and C_QuestLog.GetQuestsOnMap then
        local ok, list = pcall(C_QuestLog.GetQuestsOnMap, mapID)
        if ok and list then for _, q in ipairs(list) do surCarte[q.questID] = q end end
    end
    -- ---- 1b. Points "o" : zones d'objectifs des quetes en cours (mobs a tuer, objets a ramasser)
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.questID then
                local qid = info.questID
                local typ = C_QuestLog.IsComplete(qid) and "?" or "o"
                local trouve = false
                if C_QuestLog.GetNextWaypointForMap then
                    local ok, wx, wy = pcall(C_QuestLog.GetNextWaypointForMap, qid, mapID)
                    if ok and wx and wy then trouve = true; ajouter(mapID, wx, wy, typ, info.title, "waypoint") end
                end
                if not trouve and surCarte[qid] then
                    ajouter(mapID, surCarte[qid].x, surCarte[qid].y, typ, info.title, "questsOnMap")
                end
            end
        end
    elseif GetNumQuestLogEntries then
        -- Ancienne API
        for i = 1, GetNumQuestLogEntries() do
            local t, _, _, isHeader, _, isComplete, _, qid = GetQuestLogTitle(i)
            if not isHeader and qid and surCarte[qid] then
                ajouter(mapID, surCarte[qid].x, surCarte[qid].y, isComplete == 1 and "?" or "o", t, "questsOnMap")
            end
        end
    end

    -- ---- 2. Points "!" : quetes disponibles connues du client
    if C_QuestOffer and C_QuestOffer.GetQuestOfferMapInfo then
        local ok, list = pcall(C_QuestOffer.GetQuestOfferMapInfo, mapID)
        if ok and list then
            for _, q in ipairs(list) do
                ajouter(mapID, q.x, q.y, "!", (q.questID and titreQuete(q.questID)) or q.title or "Quete disponible", "questOffer")
            end
        end
    end
    if C_QuestLine and C_QuestLine.GetAvailableQuestLines then
        if C_QuestLine.RequestQuestLinesForMap then pcall(C_QuestLine.RequestQuestLinesForMap, mapID) end
        local ok, list = pcall(C_QuestLine.GetAvailableQuestLines, mapID)
        if ok and list then
            for _, q in ipairs(list) do
                if not q.isHidden then
                    ajouter(mapID, q.x, q.y, "!", (q.questID and titreQuete(q.questID)) or q.questLineName or "Quete disponible", "questLine")
                end
            end
        end
    end
end

-- ================================================================ Affichage
local function positionJoueur()
    if not mapCourante then return end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapCourante, "player")
    if not ok or not pos then return end
    local wx, wy = mondeDepuisCarte(mapCourante, pos.x, pos.y)
    return wx, wy, pos.x, pos.y
end

local function rafraichir()
    local px, py, pmx, pmy = positionJoueur()
    local prioritaire = candidatCorps or candidatExterne
    if not px or (#candidats == 0 and not prioritaire) then
        arrow:Hide(); icon:SetText("")
        title:SetText((#candidats == 0 and not prioritaire) and "Aucun point de quete connu" or "Position inconnue")
        dist:SetText("")
        return
    end
    local best, bestD
    if prioritaire then
        best = prioritaire
        bestD = math.sqrt((best.wx - px) ^ 2 + (best.wy - py) ^ 2)
    else
        -- Le plus proche
        for _, c in ipairs(candidats) do
            if not QueteGPSDB.filtre or QueteGPSDB.filtre == c.type then
                local dx, dy = c.wx - px, c.wy - py
                local d = math.sqrt(dx * dx + dy * dy)
                if not bestD or d < bestD then best, bestD = c, d end
            end
        end
    end
    if not best then
        arrow:Hide(); icon:SetText("")
        title:SetText("Aucun point (filtre " .. tostring(QueteGPSDB.filtre) .. ")"); dist:SetText("")
        return
    end
    -- Direction : coordonnees de carte (x vers l'est, y vers le sud), corrigees du ratio de la carte.
    -- GetPlayerFacing : 0 = nord, augmente dans le sens anti-horaire (pi/2 = ouest).
    local rel = 0
    if best.mx and best.my then
        local facing = GetPlayerFacing() or 0
        local versEst = (best.mx - pmx) * largeurCarte
        local versSud = (best.my - pmy) * hauteurCarte
        local bearing = math.atan2(-versEst, -versSud)   -- ouest positif, nord positif
        rel = bearing - facing
        if QueteGPSDB.miroir then rel = -rel end
        arrow:SetRotation(rel)
        arrow:Show()
    else
        arrow:Hide()   -- autre carte : distance seulement
    end
    if best.type == "o" then
        icon:SetText("|cffff6060x|r")          -- objectif en cours (mobs / objets)
    elseif best.type == ">" then
        icon:SetText("|cff00ff88>|r")          -- etape de route (QueteRoute)
    elseif best.type == "+" then
        icon:SetText("|cffff3030+|r")          -- ton corps
    else
        icon:SetText("|cffffff00" .. best.type .. "|r")
    end
    title:SetText(best.nom)
    dist:SetText(("%d yards"):format(bestD))
    local diff = math.abs(((rel + math.pi) % (2 * math.pi)) - math.pi)
    if diff < 0.2 then arrow:SetVertexColor(0.2, 1, 0.2)
    elseif diff < 1.0 then arrow:SetVertexColor(1, 1, 0.2)
    else arrow:SetVertexColor(1, 0.4, 0.2) end
end

local acc, accCollect = 0, 0
frame:SetScript("OnUpdate", function(self, elapsed)
    acc = acc + elapsed; accCollect = accCollect + elapsed
    if accCollect > 3 then accCollect = 0; collecter() end
    if acc > 0.1 then acc = 0; rafraichir() end
end)

-- ================================================================ Evenements
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
pcall(ev.RegisterEvent, ev, "QUEST_ACCEPTED")
pcall(ev.RegisterEvent, ev, "QUEST_TURNED_IN")
pcall(ev.RegisterEvent, ev, "QUESTLINE_UPDATE")
ev:RegisterEvent("PLAYER_DEAD")
ev:RegisterEvent("PLAYER_ALIVE")
ev:RegisterEvent("PLAYER_UNGHOST")
pcall(ev.RegisterEvent, ev, "CORPSE_IN_RANGE")
pcall(ev.RegisterEvent, ev, "CORPSE_OUT_OF_RANGE")
ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        QueteGPSDB = QueteGPSDB or {}
        if QueteGPSDB.shown == nil then QueteGPSDB.shown = true end
        if QueteGPSDB.pos then
            frame:ClearAllPoints()
            frame:SetPoint(QueteGPSDB.pos[1], UIParent, QueteGPSDB.pos[2], QueteGPSDB.pos[3], QueteGPSDB.pos[4])
        end
        if QueteGPSDB.shown then frame:Show() else frame:Hide() end
        return
    end
    collecter()
end)

-- ================================================================ Commande /gps
SLASH_QUETEGPS1 = "/gps"
SlashCmdList["QUETEGPS"] = function(msg)
    msg = (msg or ""):lower()
    if msg == "reset" then
        QueteGPSDB.pos = nil
        frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    elseif msg == "?" or msg == "!" or msg == "o" or msg == "x" then
        if msg == "x" then msg = "o" end
        QueteGPSDB.filtre = (QueteGPSDB.filtre == msg) and nil or msg
        print(PREFIX .. "Filtre : " .. (QueteGPSDB.filtre or "tous") .. "  (? = rendre, ! = prendre, o = objectifs en cours)")
    elseif msg == "miroir" then
        QueteGPSDB.miroir = not QueteGPSDB.miroir
        print(PREFIX .. "Sens de rotation de la fleche : " .. (QueteGPSDB.miroir and "inverse" or "normal"))
    elseif msg == "debug" then
        collecter()
        print(PREFIX .. "Carte " .. tostring(mapCourante) .. ", " .. #candidats .. " point(s) :")
        for src, n in pairs(sourcesOK) do print("  source " .. src .. " : " .. n) end
        for _, c in ipairs(candidats) do print("  " .. c.type .. " " .. c.nom) end
        print("  API : GetQuestsOnMap=" .. tostring(C_QuestLog and C_QuestLog.GetQuestsOnMap ~= nil)
            .. " NextWaypoint=" .. tostring(C_QuestLog and C_QuestLog.GetNextWaypointForMap ~= nil)
            .. " QuestOffer=" .. tostring(C_QuestOffer and C_QuestOffer.GetQuestOfferMapInfo ~= nil)
            .. " QuestLine=" .. tostring(C_QuestLine and C_QuestLine.GetAvailableQuestLines ~= nil))
    else
        QueteGPSDB.shown = not QueteGPSDB.shown
        if QueteGPSDB.shown then frame:Show() else frame:Hide() end
        print(PREFIX .. (QueteGPSDB.shown and "affiche" or "masque")
            .. "  (/gps reset = replacer, /gps ? / ! / o = filtrer, /gps debug = diagnostic)")
    end
end
