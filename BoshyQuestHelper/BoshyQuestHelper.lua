local BQH_Version = "1.0.0";
local BQH_Name = "Boshy Quest Helper";
local BQH_ORANGE = "|cffFF8000";
local BQH_WHITE = "|cffFFFFFF";
local AQT_BLUE = "|c000099ff";
local BQH_END_COLOR = "|r";
local BQH_Title = BQH_ORANGE .. BQH_Name .. ":" .. BQH_END_COLOR .. " ";

local EVENTS = {};
local MAX_LEVEL = 85;

-- Event ADDON_LOADED
EVENTS.ADDON_LOADED = "ADDON_LOADED";
EVENTS.QUEST_DETAIL = "QUEST_DETAIL";
EVENTS.QUEST_GREETING = "QUEST_GREETING";
EVENTS.QUEST_ACCEPTED = "QUEST_ACCEPTED";
EVENTS.QUEST_COMPLETE = "QUEST_COMPLETE";
EVENTS.QUEST_PROGRESS = "QUEST_PROGRESS";
EVENTS.GOSSIP_SHOW = "GOSSIP_SHOW";
EVENTS.TRAINER_SHOW = "TRAINER_SHOW";
EVENTS.QUEST_FINISHED = "QUEST_FINISHED";

local lastActiveQuest = 1;
local lastAvailableQuest = 1;
local lastNPC = nil;

local options = {
    debug = {message = "Debug messages"},
    security = {message = "Security key"},
    compare = {message = "Character frame"},
    auto_complete = {message = "Auto Quest Complete", status = {"always ON", "only ON while ALT key is down"}},
    announce = {message = "Announce to party channel"},
    share = {message = "Auto share new quests"},
    auto_sell_gray = {message = "Auto-sell gray items"},
    auto_accept_resurrect = {message = "Auto-accept resurrections"},
}

function BQH_OnLoad(self)
    for _,v in pairs(EVENTS) do
        self:RegisterEvent(strupper(v));
    end
    
    BQH_RegisterSlashCommands();
    BQH_LocalMessage(BQH_BLUE .. BQH_Name .. " v" .. BQH_Version .. " by Angus Bailey." .. BQH_END_COLOR);
    BQH_LocalMessage("Type /bqh or /boshyquesthelper for options.");
end

function BQH_RegisterSlashCommands()
    SlashCmdList["BQH4832_"] = BQH_ProcessSlashCommand;
    SLASH_BQH4832_1 = "/boshyquesthelper";
    SLASH_BQH4832_2 = "/bqh";
end

function BQH_ProcessSlashCommand(option)
    option = strlower(option);
    
    if option == "security" or option == "debug" or option == "compare" or option == "auto_complete" or option == "announce" or option == "share" then
        BQH_Toggle(option);
    elseif option == "status" then
        BQH_ShowStatus("security");
        BQH_ShowStatus("auto_complete");
        BQH_ShowStatus("announce");
        BQH_ShowStatus("share");
    else
        BQH_ShowHelp();
    end
end

function BQH_Toggle(option)
    BQH_Options[option] = not BQH_Options[option];
    BQH_ShowStatus(option);
end

function BQH_ShowStatus(option)
    local message = BQH_Title;
    message = message .. options[option].message .. " is ";
    message = message .. (BQH_Options[option] and ((options[option].status and options[option].status[1]) or "enabled") or ((options[option].status and options[option].status[2]) or "disabled")) .. ".";
        
    BQH_LocalMessage(message);
    BQH_HUDMsg(message);
end

function BQH_ShowHelp()
    BQH_LocalMessage(BQH_ORANGE .. BQH_Name .." v" .. BQH_Version .. BQH_END_COLOR);
    BQH_LocalMessage(BQH_WHITE .. "Usage:");
    BQH_LocalMessage(BQH_WHITE .. "    /bqh security -" .. BQH_END_COLOR .. " Enables / Disables the use of the security key CTRL. Default: OFF");
    BQH_LocalMessage(BQH_WHITE .. "    /bqh debug -" .. BQH_END_COLOR .. " Enables / Disables debug messages. Default: OFF");
    BQH_LocalMessage(BQH_WHITE .. "    /bqh compare -" .. BQH_END_COLOR .. " Enables / Disables the character frame comparison. Default: OFF");
    BQH_LocalMessage(BQH_WHITE .. "    /bqh auto_complete -" .. BQH_END_COLOR .. " Enables / Disables auto completing quests with more than one reward choice when the addon QuestReward is present. If disabled you can use the ALT key to temporarily enable this feature. Default: OFF");
    BQH_LocalMessage(BQH_WHITE .. "    /bqh announce -" .. BQH_END_COLOR .. " Enables / Disables party announces when automatically accepting quests. Default: ON");
    BQH_LocalMessage(BQH_WHITE .. "    /bqh share -" .. BQH_END_COLOR .. " Enables / Disables sharing quests automatically with party members. Default: ON");
    BQH_LocalMessage(BQH_WHITE .. "    /bqh auto_sell_gray -" .. BQH_END_COLOR .. " Enables / Disables automatically selling gray quality items to vendors. Default: ON");
    BQH_LocalMessage(BQH_WHITE .. "    /bqh auto_accept_resurrect -" .. BQH_END_COLOR .. " Enables / Disables automatically accepting resurrections from the spirit healer. Default: ON");
    BQH_LocalMessage(BQH_WHITE .. "    /bqh status -" .. BQH_END_COLOR .. " Shows your current settings.");
end

function BQH_OnEvent(self, event, ...)
    if event == EVENTS.ADDON_LOADED and ... == "BoshyQuestHelper" then
        if not BQH_Options then
            BQH_Options = {
                security = false, 
                debug = false, 
                compare = false, 
                auto_complete = false,
                announce = true,
                share = true,
                auto_sell_gray = true,
                auto_accept_resurrect = true,
            };
        end
    elseif (not BQH_Options.security and not IsControlKeyDown()) or (BQH_Options.security and IsControlKeyDown()) then
        if event == EVENTS.QUEST_GREETING or event == EVENTS.GOSSIP_SHOW then
            BQH_HandleNPCInteraction(event);
        elseif event == EVENTS.QUEST_DETAIL then
            BQH_HandleQuestDetail();
        elseif event == EVENTS.QUEST_ACCEPTED then
            BQH_HandleQuestAccepted(...);
        elseif event == EVENTS.QUEST_PROGRESS then
            BQH_HandleQuestProgress();
        elseif event == EVENTS.QUEST_COMPLETE then			
            BQH_HandleQuestComplete();
        elseif event == EVENTS.TRAINER_SHOW then
            BQH_HandleTrainerShow();
        elseif event == EVENTS.QUEST_FINISHED then
            BQH_HandleQuestFinished();
        end
    end
end

function BQH_HandleQuestDetail()	
    if GetRewardXP() > 0 or UnitLevel("player") == MAX_LEVEL then
        if not QuestGetAutoAccept() then
            AcceptQuest();
        end

        CloseQuest();
    end
end

function BQH_SellGrayItems()
    if BQH_Options.auto_sell_gray then
        for bag = 0, 4 do
            for slot = 1, GetContainerNumSlots(bag) do
                local itemLink = GetContainerItemLink(bag, slot)
                if itemLink then
                    local _, _, quality, _, _, _, _, _, _, _, itemPrice = GetItemInfo(itemLink)
                    if quality == 0 and itemPrice > 0 then
                        UseContainerItem(bag, slot)
                    end
                end
            end
        end
    end
end

function BQH_AcceptResurrect()
    if BQH_Options.auto_accept_resurrect then
        if GetCorpseRecoveryDelay() > 0 and UnitIsDead("player") then
            local numOptions = GetNumGossipOptions()
            for i = 1, numOptions do
                local option = select(1, GetGossipOptions(i))
                if option == "Return me to life." then
                    SelectGossipOption(i)
                    break
                end
            end

            -- Check for the "Accept" static popup
            if StaticPopup_Visible("CONFIRM_RESURRECT_NO_SICKNESS") then
                StaticPopup_OnClick(StaticPopup_Visible("CONFIRM_RESURRECT_NO_SICKNESS"), 1)
            end
        end
    end
end

function BQH_HandleNPCInteraction(event)
    if GetNumGossipOptions() == 0 then
        local numAvailableQuests = 0;
        local numActiveQuests = 0;
        
        if event == EVENTS.QUEST_GREETING then
            numAvailableQuests = GetNumAvailableQuests();
            numActiveQuests = GetNumActiveQuests();
        elseif event == EVENTS.GOSSIP_SHOW then
            numAvailableQuests = GetNumGossipAvailableQuests();
            numActiveQuests = GetNumGossipActiveQuests();
        end
        
        if numAvailableQuests > 0 or numActiveQuests > 0 then
            local guid = UnitGUID("target");
            
            if lastNPC ~= guid then
                lastActiveQuest = 1;
                lastAvailableQuest = 1;
                lastNPC = guid;
            end
            
            if lastAvailableQuest > numAvailableQuests then
                lastAvailableQuest = 1;
            end
            
            for i = lastAvailableQuest, numAvailableQuests do
                lastAvailableQuest = i;
                
                if event == EVENTS.QUEST_GREETING then
                    SelectAvailableQuest(i);
                elseif event == EVENTS.GOSSIP_SHOW then
                    SelectGossipAvailableQuest(i);
                end
            end
            
            if lastActiveQuest > numActiveQuests then
                lastActiveQuest = 1;
            end
            
            for i = lastActiveQuest, numActiveQuests do
                lastActiveQuest = i;
                
                if event == EVENTS.QUEST_GREETING then
                    SelectActiveQuest(i);
                elseif event == EVENTS.GOSSIP_SHOW then
                    SelectGossipActiveQuest(i);
                end
            end
        end
    end
    
    if event == EVENTS.GOSSIP_SHOW then
        if UnitName("target") == "Spirit Healer" then
            BQH_AcceptResurrect()
        elseif UnitName("target") == "Merchant" or UnitName("target") == "Vendor" then
            BQH_SellGrayItems()
        end
    end
end

function BQH_HandleQuestProgress()
    if IsQuestCompletable() then
        CompleteQuest();
    end
    
    CloseQuest();
end

function BQH_HandleQuestAccepted(questIndex)
    if GetNumGroupMembers() >= 1 then
        if BQH_Options.announce then
            SendChatMessage("[" .. BQH_Name .. "] Quest accepted: " .. GetQuestLink(questIndex), "PARTY");
        end
        
        SelectQuestLogEntry(questIndex);

        if BQH_Options.share then
            if GetQuestLogPushable() then
                QuestLogPushQuest();
            end
        end
    end
end

function BQH_HandleQuestComplete()	
    if GetNumQuestChoices() == 0 then
        GetQuestReward(nil);
    else
        if IsAddOnLoaded("QuestReward") and (BQH_Options.auto_complete or (not BQH_Options.auto_complete and IsAltKeyDown())) then
            GetQuestReward(QuestInfoFrame.itemChoice);
        else
            if BQH_Options.compare and not CharacterFrame:IsVisible() then
                CharacterFrame:SetPoint("TOPLEFT", QuestFrame, "TOPRIGHT", 20, -20);
                CharacterFrame:Show();
            end
        end
    end
end

function BQH_HandleQuestFinished()	
    if BQH_Options.compare and CharacterFrame:IsVisible() then
        CharacterFrame:Hide();
    end
end

function BQH_HandleTrainerShow()
    if not IsTradeskillTrainer() then
        SetTrainerServiceTypeFilter("available", 1, 1);
        
        if GetNumTrainerServices() > 0 then
            if strlower(GetTrainerServiceSkillLine(1)) ~= "riding" then
                for i = 1, GetNumTrainerServices() do
                    BuyTrainerService(i);
                end

                CloseTrainer();
            end
        end
    end
end

function BQH_HUDMsg(message)
   UIErrorsFrame:AddMessage(message, 1.0, 1.0, 1.0, 1.0, UIERRORS_HOLD_TIME);
end

function BQH_LocalMessage(message)
    DEFAULT_CHAT_FRAME:AddMessage(tostring(message));
end

function BQH_Debug(message)
    if BQH_Options.debug then
        BQH_LocalMessage("[" .. BQH_BLUE .. BQH_Name .. "]" .. BQH_END_COLOR .. " Debug: " .. message);
    end
end