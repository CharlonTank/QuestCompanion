local addonName, ns = ...
local PREFIX = "|cff00ff88[QueteRoute]|r "

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

-- ================================================================ Enregistrement du parcours
-- Chaque evenement : { k = "A"/"O"/"T", q = questID, t = heure, lvl = niveau, map=, x=, y=, npc=, n = titre, i = index objectif }
local cle                    -- "Perso-Royaume"
local pnjDialogue = {}       -- questID -> nom du PNJ vu dans le dialogue de quete
local etatObjectifs = {}     -- questID -> { [i] = { fini=, fait= } }

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
                    -- On note la position au premier progres et a la fin de chaque objectif
                    if (o.finished and not e.fini) or (fait > 0 and e.fait == 0) then
                        enregistrer({ k = "O", q = qid, i = k, f = o.finished and 1 or 0 })
                    end
                    etat[k] = { fini = o.finished, fait = fait }
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

local suiteTxt = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
suiteTxt:SetPoint("TOPLEFT", etapeTxt, "BOTTOMLEFT", 0, -4)
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

local function decrireEtape(e)
    local titre = (e.q and e.q.titre) or titreQuete(e.qid)
    local pnj = e.point and e.point.pnj
    if e.type == "prendre" then
        return ("Prendre |cffffff00%s|r%s"):format(titre, pnj and (" chez " .. pnj) or "")
    elseif e.type == "rendre" then
        return ("Rendre |cffffff00%s|r%s"):format(titre, pnj and (" a " .. pnj) or "")
    else
        local reste = {}
        for _, o in ipairs(objectifs(e.qid)) do if not o.finished and o.text then reste[#reste + 1] = o.text end end
        return ("Faire |cffffff00%s|r : %s"):format(titre, table.concat(reste, ", "))
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
                if queteComplete(qid) then
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
                    local point
                    for k, o in ipairs(objectifs(qid)) do
                        if not o.finished and q.objectifs and q.objectifs[k] then point = q.objectifs[k] break end
                    end
                    e = { type = "faire", qid = qid, q = q, point = point or pointClient(qid) or (q.objectifs and q.objectifs[1]) }
                end
                e.dist = distanceDepuisJoueur(e.point)
                locales[#locales + 1] = e
            end
        end
    end
    table.sort(locales, function(a, b)
        if a.dist and b.dist then return a.dist < b.dist end
        if a.dist ~= nil then return true end
        if b.dist ~= nil then return false end
        return a.qid < b.qid
    end)
    for _, e in ipairs(locales) do etapes[#etapes + 1] = e end

    -- 2. La route communautaire : prochaines quetes a prendre, dans l'ordre constate chez les contributeurs
    for _, qid in ipairs(route.ordre) do
        local q = route.quetes[qid]
        if q and not vues[qid] and not QueteRouteDB.passes[qid] and not queteDejaFaite(qid) and (q.niveau or 0) <= niveau + 2 then
            local e = { type = "prendre", qid = qid, q = q, point = q.prendre }
            e.dist = distanceDepuisJoueur(e.point)
            etapes[#etapes + 1] = e
        end
    end
    while #etapes > 5 do table.remove(etapes) end
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
    calculerEtapes()
    local e = etapes[1]
    if not e then
        etapeTxt:SetText("Rien a faire : prends des quetes ! Ton parcours est enregistre (/route export pour le partager).")
        suiteTxt:SetText("")
        if QueteGPS and QueteGPS.Effacer then QueteGPS.Effacer() end
        frame:SetHeight(70)
        return
    end
    etapeTxt:SetText("1. " .. decrireEtape(e))
    local suite = {}
    local d = detailsEtape(e)
    if d ~= "" then suite[#suite + 1] = "|cffa0d0ff" .. d .. "|r" end
    for i = 2, #etapes do suite[#suite + 1] = i .. ". " .. decrireEtape(etapes[i]) end
    suiteTxt:SetText(table.concat(suite, "\n"))
    if QueteGPS and QueteGPS.Definir then
        if e.point and e.point.map then
            QueteGPS.Definir(e.point.map, e.point.x, e.point.y, decrireEtape(e):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""), ">")
        else
            QueteGPS.Effacer()
        end
    end
    frame:SetHeight(50 + (#suite) * 14 + 26)
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
local function propre(s) return (tostring(s or "")):gsub("[|;\n]", ",") end
local function exporter()
    local lignes = { "R1;" .. propre(cle) .. ";" .. (UnitFactionGroup("player") or "") }
    for _, ev in ipairs(journal()) do
        if ev.k == "A" then
            lignes[#lignes + 1] = table.concat({ "A", ev.q, ev.lvl or 0, ev.map or 0, ev.x or 0, ev.y or 0, propre(ev.npc), propre(ev.n) }, ";")
        elseif ev.k == "T" then
            lignes[#lignes + 1] = table.concat({ "T", ev.q, ev.lvl or 0, ev.map or 0, ev.x or 0, ev.y or 0, propre(ev.npc) }, ";")
        elseif ev.k == "O" then
            lignes[#lignes + 1] = table.concat({ "O", ev.q, ev.i or 0, ev.f or 0, ev.lvl or 0, ev.map or 0, ev.x or 0, ev.y or 0 }, ";")
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
pcall(ev.RegisterEvent, ev, "QUEST_REMOVED")

local attente = 0
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
    elseif event == "PLAYER_LOGOUT" then
        -- Export pret a l'emploi dans la sauvegarde : le compagnon (companion/QuestCompanion-Sync.ps1) le lit et l'envoie
        if cle then
            QueteRouteDB.exports = QueteRouteDB.exports or {}
            QueteRouteDB.exports[cle] = exporter()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        cle = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
        wipe(etatObjectifs)
        attente = 1
    elseif event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
        local qid = GetQuestID and GetQuestID()
        if qid and qid > 0 and UnitExists("npc") and not UnitIsPlayer("npc") then
            pnjDialogue[qid] = UnitName("npc")
        end
    elseif event == "QUEST_ACCEPTED" then
        local qid = (type(arg2) == "number" and arg2 > 0) and arg2 or arg1
        if qid and cle then
            enregistrer({ k = "A", q = qid, n = titreQuete(qid), npc = pnjDialogue[qid] })
            etatObjectifs[qid] = nil
            attente = 0.5
        end
    elseif event == "QUEST_TURNED_IN" then
        if arg1 and cle then
            enregistrer({ k = "T", q = arg1, npc = pnjDialogue[arg1] })
            etatObjectifs[arg1] = nil
            attente = 0.5
        end
    elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_REMOVED" or event == "PLAYER_LEVEL_UP" then
        attente = 0.5
    end
end)
frame:SetScript("OnUpdate", function(self, elapsed)
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
