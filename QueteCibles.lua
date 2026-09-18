local addonName, ns = ...
local PREFIX = "|cffff8800[QueteCibles]|r "
local PREFIXE_MSG = "QCibles"
local LARGEUR, HAUTEUR_BTN, MAX_BTN = 200, 22, 14

-- ================================================================ Cadre principal
local frame = CreateFrame("Frame", "QueteCiblesFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
frame:SetSize(LARGEUR, 40)
frame:SetPoint("RIGHT", UIParent, "RIGHT", -20, 100)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    QueteCiblesDB.pos = { p, rp, x, y }
end)
frame:SetClampedToScreen(true)
if frame.SetBackdrop then
    frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
        insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    frame:SetBackdropColor(0, 0, 0, 0.5)
end

local titre = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titre:SetPoint("TOP", frame, "TOP", 0, -5)
titre:SetText("Cibles")

local vide = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
vide:SetPoint("TOP", titre, "BOTTOM", 0, -6)
vide:SetText("Aucune cible")

-- ================================================================ Boutons (securises : clic = /targetexact)
local boutons = {}
for i = 1, MAX_BTN do
    local b = CreateFrame("Button", "QueteCiblesBouton" .. i, frame, "SecureActionButtonTemplate")
    b:SetSize(LARGEUR - 12, HAUTEUR_BTN)
    b:SetPoint("TOP", frame, "TOP", 0, -22 - (i - 1) * (HAUTEUR_BTN + 2))
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:SetAttribute("type", "macro")

    b.fond = b:CreateTexture(nil, "BACKGROUND")
    b.fond:SetAllPoints()
    b.fond:SetColorTexture(0.15, 0.15, 0.15, 0.8)

    b.point = b:CreateTexture(nil, "ARTWORK")
    b.point:SetSize(10, 10)
    b.point:SetPoint("LEFT", b, "LEFT", 5, 0)
    b.point:SetColorTexture(0.5, 0.5, 0.5, 1)

    b.nom = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.nom:SetPoint("LEFT", b.point, "RIGHT", 5, 0)
    b.nom:SetPoint("RIGHT", b, "RIGHT", -40, 0)
    b.nom:SetJustifyH("LEFT")
    b.nom:SetWordWrap(false)

    b.compte = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.compte:SetPoint("RIGHT", b, "RIGHT", -5, 0)
    b.compte:SetJustifyH("RIGHT")

    b:SetScript("OnEnter", function(self)
        self.fond:SetColorTexture(0.3, 0.3, 0.3, 0.9)
        if self.cible then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(self.cible.nom)
            GameTooltip:AddLine(self.cible.quete or "", 1, 1, 1)
            if self.cible.detail then GameTooltip:AddLine(self.cible.detail, 0.8, 0.8, 0.8) end
            GameTooltip:AddLine("Clic : cibler", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self.fond:SetColorTexture(0.15, 0.15, 0.15, 0.8)
        GameTooltip:Hide()
    end)
    b:Hide()
    boutons[i] = b
end

-- ================================================================ Analyse des objectifs
local VERBES = { " slain", " killed", " tues", " tue", " tuees", " tuee", " vaincus", " vaincu" }

-- Retourne nom, fait, total, estKill
-- Formats acceptes : "Nom slain: 3/10" (Classic) et "3/10 Nom slain" (client moderne)
local function nomDepuisObjectif(texte)
    if not texte then return end
    local nom, fait, total = texte:match("^(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
    if not nom then
        fait, total, nom = texte:match("^(%d+)%s*/%s*(%d+)%s+(.-)%s*$")
    end
    if not nom then return end
    local estKill = false
    local l = nom:lower()
    for _, v in ipairs(VERBES) do
        if l:sub(-#v) == v then nom = nom:sub(1, -#v - 1); estKill = true break end
    end
    return strtrim(nom), tonumber(fait), tonumber(total), estKill
end

-- Liste des quetes en cours : { {id=, titre=, objectifs={ {texte=, fini=, fait=, total=} } } }
local function quetesEnCours()
    local res = {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.questID and not C_QuestLog.IsComplete(info.questID) then
                local q = { id = info.questID, titre = info.title, objectifs = {} }
                local objs = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(info.questID)
                for _, o in ipairs(objs or {}) do
                    q.objectifs[#q.objectifs + 1] = { texte = o.text, type = o.type, fini = o.finished,
                        fait = o.numFulfilled, total = o.numRequired }
                end
                res[#res + 1] = q
            end
        end
    elseif GetNumQuestLogEntries then
        for i = 1, GetNumQuestLogEntries() do
            local t, _, _, isHeader, _, isComplete, _, qid = GetQuestLogTitle(i)
            if not isHeader and isComplete ~= 1 then
                local q = { id = qid or t, titre = t, objectifs = {} }
                for j = 1, GetNumQuestLeaderBoards(i) do
                    local texte, typ, fini = GetQuestLogLeaderBoard(j, i)
                    q.objectifs[#q.objectifs + 1] = { texte = texte, type = typ, fini = fini }
                end
                res[#res + 1] = q
            end
        end
    end
    return res
end

-- ================================================================ Apprentissage via le tooltip des mobs
-- Le jeu affiche dans le tooltip d'un mob le titre des quetes pour lesquelles il compte
-- (kill OU objet a ramasser). On memorise : questID -> { nomDuMob = true }.
local scan = CreateFrame("GameTooltip", "QueteCiblesScanTooltip", UIParent, "GameTooltipTemplate")
scan:SetOwner(UIParent, "ANCHOR_NONE")

local function lignesTooltip(unit)
    local t = {}
    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
        if ok and data and data.lines then
            for _, l in ipairs(data.lines) do
                if not l.leftText and TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, l) end
                if l.leftText then t[#t + 1] = l.leftText end
            end
            return t
        end
    end
    scan:ClearLines()
    scan:SetUnit(unit)
    for i = 1, scan:NumLines() do
        local fs = _G["QueteCiblesScanTooltipTextLeft" .. i]
        local txt = fs and fs:GetText()
        if txt then t[#t + 1] = txt end
    end
    return t
end

local titresQuetes = {}   -- titre -> questID (reconstruit a chaque collecte)
local reconstruire        -- declare plus bas
local partager            -- declare plus bas

-- Enregistre un lien quete -> mob. Retourne true si c'est nouveau.
local function memoriser(qid, nom)
    qid = tonumber(qid) or qid
    if not qid or not nom or nom == "" then return false end
    QueteCiblesDB.appris[qid] = QueteCiblesDB.appris[qid] or {}
    if QueteCiblesDB.appris[qid][nom] then return false end
    QueteCiblesDB.appris[qid][nom] = true
    return true
end

local function apprendre(unit)
    if not UnitExists(unit) or UnitIsPlayer(unit) or not UnitCanAttack("player", unit) then return end
    local nom = UnitName(unit)
    if not nom then return end
    local nouveau = false
    for _, ligne in ipairs(lignesTooltip(unit)) do
        local qid = titresQuetes[strtrim(ligne)]
        if qid and memoriser(qid, nom) then
            nouveau = true
            partager(qid, nom)
        end
    end
    if nouveau then reconstruire() end
end

-- ================================================================ Partage entre joueurs (messages d'addon)
-- Chaque lien appris est envoye au groupe et a la guilde ; les autres joueurs qui ont l'addon le recoivent.
-- Format des messages : "L<TAB>questID<TAB>mob1;mob2"   ou   "S" (demande de synchro complete)
local function envoyer(texte, canal, cible)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        pcall(C_ChatInfo.SendAddonMessage, PREFIXE_MSG, texte, canal, cible)
    elseif SendAddonMessage then
        pcall(SendAddonMessage, PREFIXE_MSG, texte, canal, cible)
    end
end

local function canaux()
    local c = {}
    if IsInRaid() then c[#c + 1] = "RAID"
    elseif LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then c[#c + 1] = "INSTANCE_CHAT"
    elseif IsInGroup() then c[#c + 1] = "PARTY" end
    if IsInGuild() then c[#c + 1] = "GUILD" end
    return c
end

partager = function(qid, nom)
    if QueteCiblesDB.partage == false then return end
    local msg = "L\t" .. tostring(qid) .. "\t" .. nom
    for _, canal in ipairs(canaux()) do envoyer(msg, canal) end
end

-- Envoie toute la base, par paquets, avec un petit delai entre chaque message
local function envoyerTout(canal, cible)
    local paquets = {}
    for qid, mobs in pairs(QueteCiblesDB.appris) do
        local liste = {}
        for nom in pairs(mobs) do liste[#liste + 1] = nom end
        local msg = "L\t" .. tostring(qid) .. "\t" .. table.concat(liste, ";")
        if #msg <= 250 then paquets[#paquets + 1] = msg end
    end
    local i = 0
    local function suivant()
        i = i + 1
        if paquets[i] then
            envoyer(paquets[i], canal, cible)
            if C_Timer then C_Timer.After(0.2, suivant) end
        end
    end
    suivant()
end

local function recevoir(texte, expediteur)
    local moi = UnitName("player")
    if expediteur == moi or (expediteur and expediteur:match("^([^%-]+)") == moi) then return end
    local code, qid, mobs = strsplit("\t", texte)
    if code == "S" then
        -- Un joueur demande la base : on lui repond en chuchotement (invisible, message d'addon)
        if expediteur then envoyerTout("WHISPER", expediteur) end
    elseif code == "L" and qid and mobs then
        local nouveau = false
        for nom in mobs:gmatch("[^;]+") do
            if memoriser(qid, strtrim(nom)) then nouveau = true end
        end
        if nouveau then reconstruire() end
    end
end

local function demanderSynchro()
    if QueteCiblesDB.partage == false then return end
    for _, canal in ipairs(canaux()) do envoyer("S", canal) end
end

-- ================================================================ Export / import texte
-- Format : questID:mob1;mob2|questID:mob...
local function exporter()
    local parts = {}
    for qid, mobs in pairs(QueteCiblesDB.appris) do
        local liste = {}
        for nom in pairs(mobs) do liste[#liste + 1] = nom end
        table.sort(liste)
        parts[#parts + 1] = tostring(qid) .. ":" .. table.concat(liste, ";")
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

local function importer(texte)
    local n = 0
    for bloc in (texte or ""):gmatch("[^|]+") do
        local qid, mobs = bloc:match("^%s*(%d+)%s*:%s*(.-)%s*$")
        if qid and mobs then
            for nom in mobs:gmatch("[^;]+") do
                if memoriser(qid, strtrim(nom)) then n = n + 1 end
            end
        end
    end
    return n
end

local fenetre
local function ouvrirFenetre(mode)
    if not fenetre then
        fenetre = CreateFrame("Frame", "QueteCiblesExport", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        fenetre:SetSize(520, 300)
        fenetre:SetPoint("CENTER")
        fenetre:SetFrameStrata("DIALOG")
        fenetre:SetMovable(true); fenetre:EnableMouse(true)
        fenetre:RegisterForDrag("LeftButton")
        fenetre:SetScript("OnDragStart", fenetre.StartMoving)
        fenetre:SetScript("OnDragStop", fenetre.StopMovingOrSizing)
        if fenetre.SetBackdrop then
            fenetre:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 } })
        end
        fenetre.titre = fenetre:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        fenetre.titre:SetPoint("TOP", 0, -16)

        local scroll = CreateFrame("ScrollFrame", "QueteCiblesExportScroll", fenetre, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 20, -45)
        scroll:SetPoint("BOTTOMRIGHT", -40, 50)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(440)
        edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function() fenetre:Hide() end)
        scroll:SetScrollChild(edit)
        fenetre.edit = edit

        local ok = CreateFrame("Button", nil, fenetre, "UIPanelButtonTemplate")
        ok:SetSize(120, 24); ok:SetPoint("BOTTOMLEFT", 20, 16)
        ok:SetScript("OnClick", function()
            local n = importer(fenetre.edit:GetText())
            print(PREFIX .. n .. " lien(s) importe(s)")
            reconstruire()
            fenetre:Hide()
        end)
        fenetre.ok = ok

        local fermer = CreateFrame("Button", nil, fenetre, "UIPanelButtonTemplate")
        fermer:SetSize(100, 24); fermer:SetPoint("BOTTOMRIGHT", -20, 16)
        fermer:SetText("Fermer")
        fermer:SetScript("OnClick", function() fenetre:Hide() end)
    end
    if mode == "export" then
        fenetre.titre:SetText("QueteCibles - Export (Ctrl+A puis Ctrl+C)")
        fenetre.edit:SetText(exporter())
        fenetre.ok:Hide()
        fenetre:Show()
        fenetre.edit:SetFocus(); fenetre.edit:HighlightText()
    else
        fenetre.titre:SetText("QueteCibles - Import (colle le texte puis Importer)")
        fenetre.edit:SetText("")
        fenetre.ok:SetText("Importer"); fenetre.ok:Show()
        fenetre:Show()
        fenetre.edit:SetFocus()
    end
end

-- ================================================================ Collecte des cibles
local cibles = {}          -- { nom=, quete=, detail=, fait=, total=, fini=, manuel= }
local majEnAttente = false

local function collecter()
    wipe(cibles); wipe(titresQuetes)
    local vus = {}
    local function ajouter(c)
        if vus[c.nom] then return end
        vus[c.nom] = true
        cibles[#cibles + 1] = c
    end

    -- Cibles manuelles d'abord
    for _, n in ipairs(QueteCiblesDB.manuel or {}) do
        ajouter({ nom = n, quete = "Ajoute manuellement", manuel = true })
    end

    for _, q in ipairs(quetesEnCours()) do
        titresQuetes[q.titre] = q.id
        local restant = nil          -- premier objectif non termine (pour le compteur des mobs appris)
        -- 1. Objectifs de type "tuer X"
        for _, o in ipairs(q.objectifs) do
            local nom, fait, total, estKill = nomDepuisObjectif(o.texte)
            if nom and (o.type == "monster" or estKill) then
                if not o.fini or QueteCiblesDB.montrerFinis then
                    ajouter({ nom = nom, quete = q.titre, fini = o.fini, fait = o.fait or fait, total = o.total or total })
                end
            end
            if not o.fini and not restant and nom then
                restant = { texte = nom, fait = o.fait or fait, total = o.total or total }
            end
        end
        -- 2. Mobs appris via tooltip (ex : ceux qui lachent l'objet de quete)
        local appris = QueteCiblesDB.appris[q.id]
        if appris and restant then
            for nom in pairs(appris) do
                ajouter({ nom = nom, quete = q.titre, detail = "Lache : " .. restant.texte,
                    fait = restant.fait, total = restant.total })
            end
        end
    end
end

-- ================================================================ Visibilite (nameplates + cible actuelle)
local function estVisible(nom)
    if UnitExists("target") and UnitName("target") == nom then return true end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, np in ipairs(C_NamePlate.GetNamePlates()) do
            local u = np.namePlateUnitToken
            if u and UnitName(u) == nom and not UnitIsDead(u) then return true end
        end
    end
    return false
end

local function rafraichirCouleurs()
    for i = 1, MAX_BTN do
        local b = boutons[i]
        if b:IsShown() and b.cible then
            if estVisible(b.cible.nom) then
                b.point:SetColorTexture(0.2, 1, 0.2, 1)
            else
                b.point:SetColorTexture(0.5, 0.5, 0.5, 1)
            end
        end
    end
end

-- ================================================================ Reconstruction (hors combat uniquement)
reconstruire = function()
    if InCombatLockdown() then majEnAttente = true return end
    majEnAttente = false
    collecter()
    local n = math.min(#cibles, MAX_BTN)
    for i = 1, MAX_BTN do
        local b, c = boutons[i], cibles[i]
        if i <= n then
            b.cible = c
            b:SetAttribute("macrotext", "/targetexact " .. c.nom)
            local compte = c.total and (c.fait .. "/" .. c.total) or ""
            if c.fini then
                b.nom:SetText("|cff808080" .. c.nom .. "|r")
                b.compte:SetText("|cff00ff00" .. (compte ~= "" and compte or "ok") .. "|r")
            elseif c.detail then
                b.nom:SetText("|cffa0d0ff" .. c.nom .. "|r")   -- bleu clair = lache un objet de quete
                b.compte:SetText(compte)
            else
                b.nom:SetText(c.nom)
                b.compte:SetText(compte)
            end
            b:Show()
        else
            b.cible = nil
            b:Hide()
        end
    end
    if n == 0 then vide:Show() else vide:Hide() end
    frame:SetHeight(28 + math.max(n, 1) * (HAUTEUR_BTN + 2))
    rafraichirCouleurs()
end

-- ================================================================ Evenements
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
pcall(ev.RegisterEvent, ev, "NAME_PLATE_UNIT_ADDED")
pcall(ev.RegisterEvent, ev, "NAME_PLATE_UNIT_REMOVED")
pcall(ev.RegisterEvent, ev, "UNIT_QUEST_LOG_CHANGED")

local attente = 0
local derniereSynchro = 0
ev:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        QueteCiblesDB = QueteCiblesDB or {}
        QueteCiblesDB.manuel = QueteCiblesDB.manuel or {}
        QueteCiblesDB.appris = QueteCiblesDB.appris or {}
        if QueteCiblesDB.shown == nil then QueteCiblesDB.shown = true end
        -- Fusion de la base livree avec l'addon (Data.lua)
        for qid, mobs in pairs(ns.seed or {}) do
            for _, nom in ipairs(mobs) do memoriser(qid, nom) end
        end
        if QueteCiblesDB.pos then
            frame:ClearAllPoints()
            frame:SetPoint(QueteCiblesDB.pos[1], UIParent, QueteCiblesDB.pos[2], QueteCiblesDB.pos[3], QueteCiblesDB.pos[4])
        end
        if QueteCiblesDB.shown then frame:Show() else frame:Hide() end
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(PREFIXE_MSG)
        elseif RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix(PREFIXE_MSG)
        end
    elseif event == "CHAT_MSG_ADDON" then
        if arg1 == PREFIXE_MSG then recevoir(arg2, arg4) end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        -- Demande la base aux autres, au plus une fois par minute
        if GetTime() - derniereSynchro > 60 then
            derniereSynchro = GetTime()
            if C_Timer then C_Timer.After(3, demanderSynchro) else demanderSynchro() end
        end
        attente = 0.3
    elseif event == "PLAYER_TARGET_CHANGED" then
        apprendre("target")
        rafraichirCouleurs()
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        apprendre("mouseover")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if arg1 then apprendre(arg1) end
        rafraichirCouleurs()
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        rafraichirCouleurs()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if majEnAttente then reconstruire() end
    else
        -- QUEST_LOG_UPDATE arrive en rafale : on regroupe
        attente = 0.3
    end
end)
frame:SetScript("OnUpdate", function(self, elapsed)
    if attente > 0 then
        attente = attente - elapsed
        if attente <= 0 then reconstruire() end
    end
end)

-- ================================================================ Commandes /cibles et /tgt
local function commande(msg)
    msg = strtrim(msg or "")
    local action, reste = msg:match("^(%S+)%s*(.-)$")
    action = (action or ""):lower()
    if action == "add" and reste ~= "" then
        table.insert(QueteCiblesDB.manuel, reste)
        print(PREFIX .. "Cible ajoutee : " .. reste)
        reconstruire()
    elseif action == "del" and reste ~= "" then
        for i, n in ipairs(QueteCiblesDB.manuel) do
            if n:lower() == reste:lower() then table.remove(QueteCiblesDB.manuel, i) break end
        end
        reconstruire()
    elseif action == "clear" then
        wipe(QueteCiblesDB.manuel)
        print(PREFIX .. "Cibles manuelles effacees")
        reconstruire()
    elseif action == "oubli" then
        wipe(QueteCiblesDB.appris)
        print(PREFIX .. "Mobs appris via tooltip oublies")
        reconstruire()
    elseif action == "export" then
        ouvrirFenetre("export")
    elseif action == "import" then
        ouvrirFenetre("import")
    elseif action == "sync" then
        derniereSynchro = GetTime()
        demanderSynchro()
        for _, canal in ipairs(canaux()) do envoyerTout(canal) end
        print(PREFIX .. "Synchro demandee et base envoyee au groupe / a la guilde")
    elseif action == "partage" then
        QueteCiblesDB.partage = (QueteCiblesDB.partage == false) and true or false
        print(PREFIX .. "Partage automatique : " .. (QueteCiblesDB.partage and "active" or "desactive"))
    elseif action == "stats" then
        local nq, nm = 0, 0
        for _, mobs in pairs(QueteCiblesDB.appris) do nq = nq + 1; for _ in pairs(mobs) do nm = nm + 1 end end
        print(PREFIX .. nq .. " quete(s), " .. nm .. " lien(s) mob->quete en base")
    elseif action == "reset" then
        QueteCiblesDB.pos = nil
        frame:ClearAllPoints(); frame:SetPoint("RIGHT", UIParent, "RIGHT", -20, 100)
    elseif action == "finis" then
        QueteCiblesDB.montrerFinis = not QueteCiblesDB.montrerFinis
        print(PREFIX .. "Objectifs termines : " .. (QueteCiblesDB.montrerFinis and "affiches en gris" or "masques"))
        reconstruire()
    else
        QueteCiblesDB.shown = not QueteCiblesDB.shown
        if QueteCiblesDB.shown then frame:Show() else frame:Hide() end
        print(PREFIX .. (QueteCiblesDB.shown and "affiche" or "masque")
            .. "  (/cibles add|del|clear, finis, oubli, export, import, sync, partage, stats, reset)")
    end
end
SLASH_QUETECIBLES1 = "/cibles"
SLASH_QUETECIBLES2 = "/tgt"
SlashCmdList["QUETECIBLES"] = commande
