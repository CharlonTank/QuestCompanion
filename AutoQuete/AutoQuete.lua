local addonName = ...
local PREFIX = "|cff00ccff[AutoQuete]|r "

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("GOSSIP_SHOW")
f:RegisterEvent("QUEST_GREETING")
f:RegisterEvent("QUEST_DETAIL")
f:RegisterEvent("QUEST_PROGRESS")
f:RegisterEvent("QUEST_COMPLETE")
f:RegisterEvent("QUEST_ACCEPT_CONFIRM")

local function actif()
    if not AutoQueteDB.enabled then return false end
    if IsShiftKeyDown() then return false end   -- Shift = pause temporaire
    return true
end

-- ---------------------------------------------------------------- Gossip (PNJ avec menu)
local function gossip()
    if C_GossipInfo and C_GossipInfo.GetActiveQuests then
        -- D'abord rendre les quetes terminees
        for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
            if q.isComplete then
                C_GossipInfo.SelectActiveQuest(q.questID)
                return
            end
        end
        -- Puis accepter les quetes disponibles
        for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
            if not (AutoQueteDB.skipTrivial and q.isTrivial) then
                C_GossipInfo.SelectAvailableQuest(q.questID)
                return
            end
        end
    elseif GetGossipActiveQuests then
        -- Ancienne API (7 valeurs par quete)
        local active = { GetGossipActiveQuests() }
        for i = 1, #active, 7 do
            if active[i + 3] then SelectGossipActiveQuest((i - 1) / 7 + 1) return end
        end
        local avail = { GetGossipAvailableQuests() }
        for i = 1, #avail, 7 do
            if not (AutoQueteDB.skipTrivial and avail[i + 2]) then
                SelectGossipAvailableQuest((i - 1) / 7 + 1) return
            end
        end
    end
end

-- ---------------------------------------------------------------- Greeting (PNJ sans menu)
local function greeting()
    for i = 1, GetNumActiveQuests() do
        local complete
        if GetActiveQuestID then
            local id = GetActiveQuestID(i)
            complete = id and C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(id)
        else
            local _, c = GetActiveTitle(i)
            complete = c
        end
        if complete then SelectActiveQuest(i) return end
    end
    for i = 1, GetNumAvailableQuests() do
        local trivial = IsAvailableQuestTrivial and IsAvailableQuestTrivial(i)
        if not (AutoQueteDB.skipTrivial and trivial) then
            SelectAvailableQuest(i) return
        end
    end
end

-- ---------------------------------------------------------------- Evenements
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        AutoQueteDB = AutoQueteDB or {}
        if AutoQueteDB.enabled == nil then AutoQueteDB.enabled = true end
        if AutoQueteDB.skipTrivial == nil then AutoQueteDB.skipTrivial = false end
        return
    end
    if not actif() then return end

    if event == "GOSSIP_SHOW" then
        gossip()
    elseif event == "QUEST_GREETING" then
        greeting()
    elseif event == "QUEST_DETAIL" then
        if QuestGetAutoAccept and QuestGetAutoAccept() then
            if AcknowledgeAutoAcceptQuest then AcknowledgeAutoAcceptQuest() end
        else
            AcceptQuest()
        end
    elseif event == "QUEST_ACCEPT_CONFIRM" then
        ConfirmAcceptQuest()
    elseif event == "QUEST_PROGRESS" then
        if IsQuestCompletable() then CompleteQuest() end
    elseif event == "QUEST_COMPLETE" then
        local n = GetNumQuestChoices()
        if n == 0 then
            GetQuestReward(0)
        elseif n == 1 then
            GetQuestReward(1)
        else
            print(PREFIX .. "Plusieurs recompenses au choix, a toi de choisir.")
        end
    end
end)

-- ---------------------------------------------------------------- Commande /aq
SLASH_AUTOQUETE1 = "/aq"
SlashCmdList["AUTOQUETE"] = function(msg)
    msg = (msg or ""):lower()
    if msg == "trivial" then
        AutoQueteDB.skipTrivial = not AutoQueteDB.skipTrivial
        print(PREFIX .. "Quetes grises : " .. (AutoQueteDB.skipTrivial and "ignorees" or "acceptees"))
    else
        AutoQueteDB.enabled = not AutoQueteDB.enabled
        print(PREFIX .. (AutoQueteDB.enabled and "|cff00ff00active|r" or "|cffff0000desactive|r")
            .. "  (/aq pour basculer, /aq trivial pour les quetes grises, Shift = pause)")
    end
end
