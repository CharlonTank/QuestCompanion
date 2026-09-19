local addonName, ns = ...
local PREFIX = "|cffff8800[QueteCibles]|r "
local PREFIXE_MSG = "QCibles"
local LARGEUR, HAUTEUR_BTN, MAX_BTN = 210, 22, 16

-- Roles memorises pour un nom, par quete :
--   true    = mob (compte pour un objectif, kill ou objet a ramasser)
--   "pnj"   = PNJ avec qui interagir pendant la quete
--   "donne" = PNJ qui donne la quete
--   "rend"  = PNJ a qui rendre la quete
-- Encodage texte (export, messages, Data.lua) : "Nom" / "@Nom" / "!Nom" / "?Nom"
local CODE_ROLE = { ["@"] = "pnj", ["!"] = "donne", ["?"] = "rend" }
local ROLE_CODE = { pnj = "@", donne = "!", rend = "?" }

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

-- Bouton "le plus proche" : sa macro essaie chaque nom de la liste, du plus proche au plus loin, et s'arrete
-- au premier qui existe. Liee a une touche via le menu Raccourcis (section QueteCibles) ou /click QueteCiblesToutBouton
local toutBouton = CreateFrame("Button", "QueteCiblesToutBouton", frame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
toutBouton:SetSize(LARGEUR - 12, 20)
toutBouton:SetPoint("TOP", frame, "TOP", 0, -22)
toutBouton:SetText("Cibler le plus proche")
toutBouton:RegisterForClicks("AnyDown", "AnyUp")
toutBouton:SetAttribute("type", "macro")
toutBouton:SetAttribute("macrotext", "/cleartarget")
toutBouton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Cibler le plus proche")
    GameTooltip:AddLine("Cible la cible de quete la plus proche parmi celles visibles autour de toi.", 1, 1, 1, true)
    GameTooltip:AddLine("Raccourci : menu Raccourcis > AddOns > QueteCibles, ou une macro /click QueteCiblesToutBouton", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end)
toutBouton:SetScript("OnLeave", function() GameTooltip:Hide() end)
BINDING_HEADER_QUETECIBLES = "QueteCibles"
_G["BINDING_NAME_CLICK QueteCiblesToutBouton:LeftButton"] = "Cibler la cible de quete la plus proche"
local DECALAGE_LISTE = 24   -- hauteur du bouton au-dessus de la liste

local vide = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
vide:SetPoint("TOP", toutBouton, "BOTTOM", 0, -6)
vide:SetText("Aucune cible")

-- ================================================================ Boutons (securises : clic = /targetexact)
local boutons = {}
for i = 1, MAX_BTN do
    local b = CreateFrame("Button", "QueteCiblesBouton" .. i, frame, "SecureActionButtonTemplate")
    b:SetSize(LARGEUR - 12, HAUTEUR_BTN)
    b:SetPoint("TOP", frame, "TOP", 0, -22 - DECALAGE_LISTE - (i - 1) * (HAUTEUR_BTN + 2))
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
local VERBES = { " slain", " killed", " exterminated", " destroyed", " defeated", " eliminated", " hunted", " culled",
    " tues", " tue", " tuees", " tuee", " vaincus", " vaincu", " extermines", " extermine", " detruits", " detruit" }

-- Retourne nom, fait, total, estKill
-- Formats acceptes : "Nom slain: 3/10" (Classic) et "3/10 Nom slain" (client moderne)
local function nomDepuisObjectif(texte, typeObjectif)
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
    -- Objectif "monstre" dont le dernier mot est un participe passe inconnu ("Exterminated", "Vanquished"...) :
    -- on le retire aussi, un nom de creature ne se termine pas par un verbe
    if not estKill and typeObjectif == "monster" then
        local avant, dernier = nom:match("^(.+%S)%s+(%a+ed)$")
        if avant and dernier and dernier:sub(1, 1):match("%u") then nom = avant; estKill = true end
    end
    return strtrim(nom), tonumber(fait), tonumber(total), estKill
end

-- Un nom de creature est en Title Case ("Hippogryph Youth", "\"Badwind\" Bennic").
-- Une description d'objectif contient des mots en minuscules ("Learn about the cultists' plans").
local PETITS_MOTS = { of = true, the = true, a = true, an = true, ["and"] = true, de = true, du = true, des = true,
    la = true, le = true, les = true, ["l'"] = true, ["d'"] = true }
local function ressembleNomCreature(s)
    if not s:find("%a") then return false end      -- "20" n'est pas un nom
    for mot in s:gmatch("%S+") do
        local lettre = mot:match("^[\"'%(%[]*(%a)")
        if lettre and lettre:match("%l") and not PETITS_MOTS[mot:lower()] then return false end
    end
    return true
end

-- Nom d'un PNJ dans une phrase ("Deliver the Signet to Talaanis Shadowsong in Valanaar", "Return to Marshal Dughan",
-- "Find and speak with Elegael Thornpaw in the northeastern part of...")
local MOTIFS_RENDU = { "[Rr]eturn to (.-)[%.,]", "[Rr]eturn to (.-) in ", "[Rr]eturn to (.-) at ", "[Rr]eport to (.-)[%.,]",
    "[Rr]eport to (.-) in ", "[Ss]peak with (.-)[%.,]", "[Ss]peak with (.-) in ", "[Ss]peak with (.-) at ",
    "[Ss]peak to (.-)[%.,]", "[Ss]peak to (.-) in ", "[Tt]alk to (.-)[%.,]", "[Tt]alk to (.-) in ",
    " to (.-) in ", " to (.-) at ", " to (.-)[%.,]", "[Rr]etourne[rz]? (?:voir|aupres de) (.-)[%.,]", "[Aa]pporte[rz]? .- [aà] (.-)[%.,]" }
local function pnjDepuisTexte(texte)
    if not texte or texte == "" then return end
    texte = texte .. "."
    for _, motif in ipairs(MOTIFS_RENDU) do
        local nom = texte:match(motif)
        if nom then
            nom = strtrim(nom)
            if nom ~= "" and #nom <= 40 and not nom:find("^the ") and ressembleNomCreature(nom) then return nom end
        end
    end
end

-- Objectifs du type "Speak with X" / "Talk to X" / "Find X" / "Listen to X's Story"
local MOTIFS_PNJ = { "^[Ss]peak with (.+)$", "^[Ss]peak to (.+)$", "^[Tt]alk to (.+)$", "^[Ll]isten to (.+)$",
    "^[Ff]ind (.+)$", "^[Ll]ocate (.+)$", "^[Mm]eet with (.+)$", "^[Mm]eet (.+)$", "^[Rr]escue (.+)$",
    "^[Pp]arle[rz] [aà] (.+)$", "^[Pp]arle[rz] avec (.+)$", "^[Tt]rouve[rz] (.+)$", "^[Ee]scort (.+) to", "^[Ee]scorte[rz] (.+) jusqu" }
local function pnjDepuisObjectif(texte)
    if not texte then return end
    texte = texte:gsub("^%d+%s*/%s*%d+%s+", ""):gsub(":%s*%d+%s*/%s*%d+%s*$", "")
    texte = texte:gsub("%s*%(%a+%)%s*$", "")          -- "(Optional)", "(Optionnel)"
    for _, m in ipairs(MOTIFS_PNJ) do
        local nom = texte:match(m)
        if nom then
            nom = strtrim(nom)
            -- "Alvarion Windfield's Story" -> "Alvarion Windfield", mais "Mankrik's Wife" reste entier
            nom = nom:gsub("'s [Ss]tory$", ""):gsub("'s [Tt]ale$", ""):gsub("'s [Rr]eport$", "")
            nom = nom:gsub("%s+in .*$", ""):gsub("%s+at .*$", "")
            -- Seulement si c'est bien un nom propre ("Find Aamelia Windfield" oui, "Find the lost supplies" non)
            if nom ~= "" and ressembleNomCreature(nom) then return nom end
            break
        end
    end
    -- Sinon, un nom dans la phrase ("Find and speak with Elegael Thornpaw in...")
    return pnjDepuisTexte(texte)
end

-- Liste des quetes du journal : { {id=, titre=, complete=, objectifs={ {texte=, type=, fini=, fait=, total=} } } }
local function quetesJournal()
    local res = {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.questID then
                local q = { id = info.questID, titre = info.title, complete = C_QuestLog.IsComplete(info.questID), objectifs = {},
                    niveau = info.difficultyLevel or info.level }
                if GetQuestLogQuestText then
                    local ok, _, texte = pcall(GetQuestLogQuestText, i)
                    if ok and type(texte) == "string" then q.texte = texte end
                end
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
            local t, lvl, _, isHeader, _, isComplete, _, qid = GetQuestLogTitle(i)
            if not isHeader then
                local q = { id = qid or t, titre = t, complete = (isComplete == 1), objectifs = {}, niveau = lvl }
                if SelectQuestLogEntry and GetQuestLogQuestText then
                    SelectQuestLogEntry(i)
                    local _, texte = GetQuestLogQuestText()
                    q.texte = texte
                end
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

-- ================================================================ Base apprise
local reconstruire        -- declare plus bas
local partager            -- declare plus bas

-- Decode "?Nom" -> "Nom", "rend"
local function decoder(nomCode)
    local role = CODE_ROLE[nomCode:sub(1, 1)]
    if role then return strtrim(nomCode:sub(2)), role end
    return strtrim(nomCode), true
end
local function encoder(nom, role)
    return (ROLE_CODE[role] or "") .. nom
end

-- Enregistre un lien quete -> nom (encode ou non). Retourne true si nouveau.
local function memoriser(qid, nomCode, role)
    qid = tonumber(qid) or qid
    if not qid or type(nomCode) ~= "string" or nomCode == "" then return false end
    local nom
    if role then nom = strtrim(nomCode) else nom, role = decoder(nomCode) end
    if nom == "" then return false end
    QueteCiblesDB.appris[qid] = QueteCiblesDB.appris[qid] or {}
    local actuel = QueteCiblesDB.appris[qid][nom]
    if actuel == role then return false end
    -- "rend" remplace "donne" ; "mob" (attaquable, objectif tuer/objet) remplace "pnj" ; sinon on garde la premiere
    if actuel and not (role == "rend" and actuel == "donne") and not (role == true and actuel == "pnj") then return false end
    QueteCiblesDB.appris[qid][nom] = role
    return true
end

-- ---- Apprentissage via le tooltip des creatures
-- Le jeu affiche dans le tooltip d'une creature le titre des quetes pour lesquelles elle compte.
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

local function apprendre(unit)
    if not UnitExists(unit) or UnitIsPlayer(unit) then return end
    local nom = UnitName(unit)
    if not nom then return end
    -- Non attaquable = PNJ. Attaquable (hostile OU neutre, ex. une bete jaune) = mob si la quete a un objectif
    -- "tuer" ou "objet a ramasser" en cours, sinon PNJ d'interaction neutre (ex. un cultiste a qui parler)
    local attaquable = UnitCanAttack("player", unit)
    local nouveau = false
    for _, ligne in ipairs(lignesTooltip(unit)) do
        local qid = titresQuetes[strtrim(ligne)]
        local role = "pnj"
        if qid and attaquable then
            local objs = (C_QuestLog and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(qid)) or {}
            for _, o in ipairs(objs) do
                if not o.finished then
                    local n, _, _, kill = nomDepuisObjectif(o.text, o.type)
                    if o.type == "item" or kill or (o.type == "monster" and n and ressembleNomCreature(n)) then role = true break end
                end
            end
        end
        if qid and memoriser(qid, nom, role) then
            nouveau = true
            partager(qid, encoder(nom, role))
        end
    end
    if nouveau then reconstruire() end
end

-- ---- Apprentissage des PNJ donneurs / receveurs de quete (au moment du dialogue)
local dernierPNJ = { nom = nil, t = 0 }   -- dernier PNJ avec qui on a interagi (gossip, quete)

-- Nom de ce avec quoi on interagit : PNJ, ou objet (armoire, coffre...) via le titre de la fenetre de dialogue
local function nomInteraction()
    if UnitExists("npc") and not UnitIsPlayer("npc") then return UnitName("npc") end
    local f = GossipFrame
    if f then
        -- Selon le client, GetTitleText renvoie la chaine ou l'objet FontString
        local t = (f.GetTitleText and f:GetTitleText())
            or (f.TitleContainer and f.TitleContainer.TitleText)
            or GossipFrameNpcNameText
        if type(t) == "table" and t.GetText then t = t:GetText() end
        if type(t) == "string" and t ~= "" then return t end
    end
end

local function noterInteraction()
    local nom = nomInteraction()
    if nom then dernierPNJ.nom, dernierPNJ.t = nom, GetTime() end
end

local function apprendrePNJ(role)
    noterInteraction()
    local qid = GetQuestID and GetQuestID()
    if not qid or qid == 0 then return end
    if not UnitExists("npc") or UnitIsPlayer("npc") then return end
    local nom = UnitName("npc")
    if nom and memoriser(qid, nom, role) then
        partager(qid, encoder(nom, role))
        reconstruire()
    end
end

-- Meilleur PNJ connu pour rendre une quete : appris ("rend"), sinon lu dans le texte, sinon celui qui l'a donnee
function QueteCibles_PNJRendu(qid, texte)
    local receveur, donneur
    for nom, role in pairs((QueteCiblesDB and QueteCiblesDB.appris and QueteCiblesDB.appris[qid]) or {}) do
        if role == "rend" then receveur = nom elseif role == "donne" then donneur = nom end
    end
    if receveur then return receveur, "appris" end
    local lu = pnjDepuisTexte(texte)
    if lu then return lu, "texte" end
    if donneur then return donneur, "donneur" end
end

-- ================================================================ Partage entre joueurs (messages d'addon)
-- Format des messages : "L<TAB>questID<TAB>nom1;nom2" (noms encodes)  ou  "S" (demande de synchro)
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

partager = function(qid, nomCode)
    if QueteCiblesDB.partage == false then return end
    local msg = "L\t" .. tostring(qid) .. "\t" .. nomCode
    for _, canal in ipairs(canaux()) do envoyer(msg, canal) end
end

local function listeEncodee(qid)
    local liste = {}
    for nom, role in pairs(QueteCiblesDB.appris[qid] or {}) do liste[#liste + 1] = encoder(nom, role) end
    table.sort(liste)
    return liste
end

local function envoyerTout(canal, cible)
    local paquets = {}
    for qid in pairs(QueteCiblesDB.appris) do
        local msg = "L\t" .. tostring(qid) .. "\t" .. table.concat(listeEncodee(qid), ";")
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
    local code, qid, noms = strsplit("\t", texte)
    if code == "S" then
        if expediteur then envoyerTout("WHISPER", expediteur) end
    elseif code == "L" and qid and noms then
        local nouveau = false
        for nomCode in noms:gmatch("[^;]+") do
            if memoriser(qid, nomCode) then nouveau = true end
        end
        if nouveau then reconstruire() end
    end
end

local function demanderSynchro()
    if QueteCiblesDB.partage == false then return end
    for _, canal in ipairs(canaux()) do envoyer("S", canal) end
end

-- ================================================================ Export / import texte
-- Format : questID:nom1;nom2|questID:nom...   (noms encodes : @pnj, !donneur, ?receveur)
local function exporter()
    local parts = {}
    for qid in pairs(QueteCiblesDB.appris) do
        local liste = listeEncodee(qid)
        if #liste > 0 then parts[#parts + 1] = tostring(qid) .. ":" .. table.concat(liste, ";") end
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

local function importer(texte)
    local n = 0
    for bloc in (texte or ""):gmatch("[^|]+") do
        local qid, noms = bloc:match("^%s*(%d+)%s*:%s*(.-)%s*$")
        if qid and noms then
            for nomCode in noms:gmatch("[^;]+") do
                if memoriser(qid, nomCode) then n = n + 1 end
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
local cibles = {}          -- { nom=, quete=, detail=, fait=, total=, fini=, genre="mob"/"pnj"/"inconnu", manuel= }
local majEnAttente = false
local etatsObjectifs = {}  -- questID -> { [k] = fini } pour detecter les objectifs qui viennent de se terminer

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

    local pnjs = {}   -- ajoutes a la fin, apres les mobs
    local niveauJoueur = UnitLevel("player")
    for _, q in ipairs(quetesJournal()) do
        titresQuetes[q.titre] = q.id
        local debutC, debutP = #cibles, #pnjs   -- pour rattacher les cibles de cette quete a son questID
        local appris = QueteCiblesDB.appris[q.id] or {}
        -- Quete orange ou rouge (3 niveaux au-dessus ou plus) : pas de cibles proposees (/cibles difficiles pour les voir)
        local tropDure = not q.complete and not QueteCiblesDB.difficiles and q.niveau and (q.niveau - niveauJoueur) >= 3

        if tropDure then
            -- rien
        elseif q.complete then
            -- Quete terminee : le PNJ a qui la rendre (appris, sinon lu dans le texte, sinon celui qui l'a donnee)
            local nom, source = QueteCibles_PNJRendu(q.id, q.texte)
            if nom then
                local detail = (source == "appris" and "Rendre la quete")
                    or (source == "texte" and ("Rendre la quete : " .. (q.texte or "")))
                    or "Rendre la quete (PNJ qui l'a donnee, a verifier)"
                pnjs[#pnjs + 1] = { nom = nom, quete = q.titre, genre = "pnj", detail = detail, compte = "?" }
            end
        else
            local restant = nil       -- premier objectif "objet a ramasser" non termine (pour les mobs appris)
            local nomsKill = {}       -- mobs deja objectifs "tuer" de cette quete, finis ou non
            local descriptions = {}   -- objectifs d'interaction ("Learn about the cultists' plans")
            local etats = etatsObjectifs[q.id] or {}
            for k, o in ipairs(q.objectifs) do
                -- Objectif qui vient de se terminer juste apres un dialogue : ce PNJ est lie a la quete
                if o.fini and etats[k] == false and dernierPNJ.nom and GetTime() - dernierPNJ.t < 20 then
                    if memoriser(q.id, dernierPNJ.nom, "pnj") then partager(q.id, encoder(dernierPNJ.nom, "pnj")) end
                end
                etats[k] = o.fini and true or false

                local nom, fait, total, estKill = nomDepuisObjectif(o.texte, o.type)
                local pnj = pnjDepuisObjectif(o.texte)
                if pnj then
                    -- 1. "parler a X" : le nom du PNJ est dans le texte
                    if not o.fini then pnjs[#pnjs + 1] = { nom = pnj, quete = q.titre, genre = "pnj", detail = o.texte } end
                elseif nom and (estKill or (o.type == "monster" and ressembleNomCreature(nom))) then
                    -- 2. "tuer X" : vrai nom de creature
                    nomsKill[nom] = true
                    if not o.fini or QueteCiblesDB.montrerFinis then
                        ajouter({ nom = nom, quete = q.titre, fini = o.fini, fait = o.fait or fait, total = o.total or total, genre = "mob" })
                    end
                    -- Le vrai nom du mob peut differer ("Enchanted Skyhopper" dans l'objectif, "Skyhopper" en jeu) :
                    -- les mobs appris via tooltip se rattachent a cet objectif tant qu'il n'est pas fini
                    if not o.fini and not restant then restant = { texte = nom, fait = o.fait or fait, total = o.total or total, kill = true } end
                elseif nom then
                    -- 3. Description d'objectif (objet a ramasser, interaction...) : pas un nom de cible
                    if not o.fini then
                        descriptions[#descriptions + 1] = { texte = nom, fait = o.fait or fait, total = o.total or total, type = o.type }
                        if not restant and o.type == "item" then restant = descriptions[#descriptions] end
                    end
                end
            end
            etatsObjectifs[q.id] = etats

            -- 4. Appris : mobs qui comptent pour la quete (objets a ramasser) et PNJ d'interaction
            local pnjConnu = false
            for nom, role in pairs(appris) do
                if role == true and restant and not nomsKill[nom] then
                    ajouter({ nom = nom, quete = q.titre, detail = (restant.kill and "Compte pour : " or "Lache : ") .. restant.texte,
                        fait = restant.fait, total = restant.total, genre = "mob" })
                elseif role == "pnj" then
                    -- Un PNJ/objet appris ne concerne que les objectifs d'interaction, jamais un objet a ramasser
                    local d
                    for _, desc in ipairs(descriptions) do if desc.type ~= "item" then d = desc break end end
                    if d then
                        pnjConnu = true
                        pnjs[#pnjs + 1] = { nom = nom, quete = q.titre, genre = "pnj", affichage = nom .. " : " .. d.texte,
                            detail = d.texte, fait = d.fait, total = d.total }
                    end
                end
            end
            -- 5. Objectif d'interaction sans PNJ/objet connu : ligne grise, non cliquable, pour que tu saches quoi faire
            for _, d in ipairs(descriptions) do
                if d.type ~= "item" and not pnjConnu then
                    pnjs[#pnjs + 1] = { nom = d.texte, quete = q.titre, genre = "inconnu", fait = d.fait, total = d.total,
                        detail = "PNJ ou objet inconnu : interagis avec, l'addon l'apprendra pour tout le monde" }
                end
            end
        end
        for k = debutC + 1, #cibles do cibles[k].qid = cibles[k].qid or q.id end
        for k = debutP + 1, #pnjs do pnjs[k].qid = pnjs[k].qid or q.id end
    end
    for _, p in ipairs(pnjs) do ajouter(p) end
end


-- Quetes dont au moins une cible est visible autour de toi (barres de nom ou cible actuelle) : { [questID] = true }
-- Utilise par QueteRoute / QueteGPS pour savoir que tu es dans une zone ou il y a quelque chose a faire
function QueteCibles_QuetesAvecCiblesVisibles()
    local res = {}
    local parNom = {}
    for _, c in ipairs(cibles) do if c.qid and c.genre ~= "inconnu" and not c.fini then parNom[c.nom] = c.qid end end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, np in ipairs(C_NamePlate.GetNamePlates()) do
            local u = np.namePlateUnitToken
            local n = u and UnitName(u)
            if n and parNom[n] and not UnitIsDead(u) then res[parNom[n]] = true end
        end
    end
    local t = UnitExists("target") and UnitName("target")
    if t and parNom[t] and not UnitIsDead("target") then res[parNom[t]] = true end
    return res
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

-- ---- Marqueurs de raid sur la tete des cibles visibles (crane pour la 1re ligne, croix pour la 2e, etc.)
local ICONES = { 8, 7, 6, 5, 4, 3, 2, 1 }
local function peutMarquer()
    if QueteCiblesDB.marque == false then return false end
    if not IsInGroup() then return true end
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

-- Sur ce client, SetRaidTarget est reserve a l'interface Blizzard. Deux mecanismes a la place :
--  1. une icone dessinee par l'addon au-dessus de la barre de nom de chaque mob de la liste (automatique) ;
--  2. le vrai marqueur de raid pose par la macro du bouton (/tm) au clic, ce qui est autorise.
local function macroPour(c, i)
    if c.genre == "inconnu" then return "" end
    -- /cleartarget d'abord : si le nom n'est pas trouve, on n'a plus de cible et /tm ne marque rien
    local m = "/cleartarget\n/targetexact " .. c.nom
    if peutMarquer() and ICONES[i] then m = m .. "\n/tm [exists,nodead] " .. ICONES[i] end
    return m
end

-- ---- Icones au-dessus des barres de nom
local iconesPlates = {}   -- nameplate frame -> texture

local function iconePourNom()
    local t = {}
    for i = 1, MAX_BTN do
        local b = boutons[i]
        if b:IsShown() and b.cible and b.cible.genre ~= "inconnu" and ICONES[i] then t[b.cible.nom] = ICONES[i] end
    end
    return t
end

local function texcoordIcone(tex, index)
    if SetRaidTargetIconTexture then SetRaidTargetIconTexture(tex, index) return end
    local col, row = (index - 1) % 4, math.floor((index - 1) / 4)
    tex:SetTexCoord(col * 0.25, col * 0.25 + 0.25, row * 0.25, row * 0.25 + 0.25)
end

local function majIconePlate(unit, parNom)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end
    local tex = iconesPlates[plate]
    if not tex then
        local holder = CreateFrame("Frame", nil, plate)
        holder:SetSize(28, 28)
        holder:SetPoint("BOTTOM", plate, "TOP", 0, -4)
        holder:SetFrameStrata("HIGH")
        tex = holder:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        iconesPlates[plate] = tex
    end
    local index = QueteCiblesDB.marque ~= false and not UnitIsDead(unit) and parNom[UnitName(unit) or ""]
    if index then
        texcoordIcone(tex, index)
        tex:Show()
    else
        tex:Hide()
    end
end

local function majToutesIcones()
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    local parNom = iconePourNom()
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        if plate.namePlateUnitToken then majIconePlate(plate.namePlateUnitToken, parNom) end
    end
end

-- Estimation de proximite d'une unite de barre de nom (plus petit = plus proche) :
-- portee d'interaction quand elle est disponible, sinon taille apparente de la barre de nom
local function proximite(unit, plate)
    if CheckInteractDistance then
        local ok3, r3 = pcall(CheckInteractDistance, unit, 3)   -- ~10 yards
        if ok3 and r3 then return 1 end
        local ok1, r1 = pcall(CheckInteractDistance, unit, 1) -- ~28 yards
        if ok1 and r1 then return 2 end
    end
    local taille = plate and plate:GetEffectiveScale() or 1
    return 3 + (1 - math.min(taille, 1))   -- barre plus petite = plus loin
end

-- Reconstruit la macro du bouton "le plus proche" (hors combat uniquement : attribut securise)
local function majBoutonTout()
    if InCombatLockdown() then return end
    local noms, index = {}, {}
    for i = 1, MAX_BTN do
        local b = boutons[i]
        if b:IsShown() and b.cible and b.cible.genre ~= "inconnu" and not b.cible.fini then
            noms[#noms + 1] = b.cible.nom; index[b.cible.nom] = i
        end
    end
    if #noms == 0 then toutBouton:SetAttribute("macrotext", "/cleartarget"); return end
    -- Score par nom : la meilleure proximite parmi les unites visibles portant ce nom ; invisibles apres
    local score = {}
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, np in ipairs(C_NamePlate.GetNamePlates()) do
            local u = np.namePlateUnitToken
            local n = u and UnitName(u)
            if n and index[n] and not UnitIsDead(u) then
                local p = proximite(u, np)
                if not score[n] or p < score[n] then score[n] = p end
            end
        end
    end
    table.sort(noms, function(a, b)
        local sa, sb = score[a] or 99, score[b] or 99
        if sa ~= sb then return sa < sb end
        return index[a] < index[b]
    end)
    local lignes = { "/cleartarget" }
    for k, n in ipairs(noms) do
        lignes[#lignes + 1] = (k == 1) and ("/targetexact " .. n) or ("/targetexact [@target,noexists] " .. n)
        if #table.concat(lignes, "\n") > 900 then break end
    end
    toutBouton:SetAttribute("macrotext", table.concat(lignes, "\n"))
end

local function rafraichirCouleurs()
    majBoutonTout()
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
    majToutesIcones()
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
            b:SetAttribute("macrotext", macroPour(c, i))
            local compte = c.compte or (c.total and (c.fait .. "/" .. c.total)) or ""
            if c.genre == "inconnu" then
                b.nom:SetText("|cff909090" .. c.nom .. "|r")    -- gris = objectif sans PNJ connu
                b.compte:SetText("|cff909090" .. compte .. "|r")
            elseif c.fini then
                b.nom:SetText("|cff808080" .. c.nom .. "|r")
                b.compte:SetText("|cff00ff00" .. (compte ~= "" and compte or "ok") .. "|r")
            elseif c.genre == "pnj" then
                b.nom:SetText("|cff60ff60" .. (c.affichage or c.nom) .. "|r")    -- vert = PNJ / objet avec qui interagir
                b.compte:SetText("|cffffff00" .. compte .. "|r")
            elseif c.detail then
                b.nom:SetText("|cffa0d0ff" .. c.nom .. "|r")    -- bleu clair = lache un objet de quete
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
    frame:SetHeight(28 + DECALAGE_LISTE + math.max(n, 1) * (HAUTEUR_BTN + 2))
    rafraichirCouleurs()
end

-- ================================================================ Evenements
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("QUEST_DETAIL")
ev:RegisterEvent("QUEST_PROGRESS")
ev:RegisterEvent("QUEST_COMPLETE")
ev:RegisterEvent("GOSSIP_SHOW")
ev:RegisterEvent("QUEST_GREETING")
pcall(ev.RegisterEvent, ev, "NAME_PLATE_UNIT_ADDED")
pcall(ev.RegisterEvent, ev, "NAME_PLATE_UNIT_REMOVED")
pcall(ev.RegisterEvent, ev, "UNIT_QUEST_LOG_CHANGED")
pcall(ev.RegisterEvent, ev, "UNIT_HEALTH")

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
        for qid, noms in pairs(ns.seed or {}) do
            for _, nomCode in ipairs(noms) do memoriser(qid, nomCode) end
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
    elseif event == "PLAYER_LOGOUT" then
        -- Export pret a l'emploi dans la sauvegarde : le compagnon (companion/QuestCompanion-Sync.ps1) le lit et l'envoie
        QueteCiblesDB.export = exporter()
    elseif event == "CHAT_MSG_ADDON" then
        if arg1 == PREFIXE_MSG then recevoir(arg2, arg4) end
    elseif event == "GOSSIP_SHOW" or event == "QUEST_GREETING" then
        noterInteraction()
        apprendre("npc")
    elseif event == "QUEST_DETAIL" then
        apprendrePNJ("donne")
    elseif event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
        apprendrePNJ("rend")
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
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
        if arg1 then apprendre(arg1); majIconePlate(arg1, iconePourNom()) end
        rafraichirCouleurs()
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if arg1 and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
            local plate = C_NamePlate.GetNamePlateForUnit(arg1)
            if plate and iconesPlates[plate] then iconesPlates[plate]:Hide() end
        end
        rafraichirCouleurs()
    elseif event == "UNIT_HEALTH" then
        if arg1 and arg1:match("^nameplate") and UnitIsDead(arg1) then majIconePlate(arg1, iconePourNom()) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if majEnAttente then reconstruire() else rafraichirCouleurs() end
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
        print(PREFIX .. "Base apprise effacee")
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
        local nq, nm, np = 0, 0, 0
        for _, noms in pairs(QueteCiblesDB.appris) do
            nq = nq + 1
            for _, role in pairs(noms) do if role == true then nm = nm + 1 else np = np + 1 end end
        end
        print(PREFIX .. nq .. " quete(s), " .. nm .. " mob(s), " .. np .. " PNJ en base")
    elseif action == "reset" then
        QueteCiblesDB.pos = nil
        frame:ClearAllPoints(); frame:SetPoint("RIGHT", UIParent, "RIGHT", -20, 100)
    elseif action == "marque" then
        QueteCiblesDB.marque = (QueteCiblesDB.marque == false) and true or false
        print(PREFIX .. "Icones au-dessus des mobs : " .. (QueteCiblesDB.marque and "actives" or "coupees"))
        reconstruire()
    elseif action == "difficiles" then
        QueteCiblesDB.difficiles = not QueteCiblesDB.difficiles
        print(PREFIX .. "Cibles des quetes orange/rouges : " .. (QueteCiblesDB.difficiles and "affichees" or "masquees"))
        reconstruire()
    elseif action == "finis" then
        QueteCiblesDB.montrerFinis = not QueteCiblesDB.montrerFinis
        print(PREFIX .. "Objectifs termines : " .. (QueteCiblesDB.montrerFinis and "affiches en gris" or "masques"))
        reconstruire()
    else
        QueteCiblesDB.shown = not QueteCiblesDB.shown
        if QueteCiblesDB.shown then frame:Show() else frame:Hide() end
        print(PREFIX .. (QueteCiblesDB.shown and "affiche" or "masque")
            .. "  (/cibles add|del|clear, finis, marque, oubli, export, import, sync, partage, stats, reset)")
    end
end
SLASH_QUETECIBLES1 = "/cibles"
SLASH_QUETECIBLES2 = "/tgt"
SlashCmdList["QUETECIBLES"] = commande
