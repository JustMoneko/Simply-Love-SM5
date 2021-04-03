if GAMESTATE:GetCurrentGame():GetName() ~= "dance" or not SL.GrooveStats.Leaderboard then return end

local NumEntries = 13

local SetEntryText = function(rank, name, score, actor)
    if actor == nil then return end

    actor:GetChild("Rank"):setText(rank)
    actor:GetChild("Name"):setText(name)
    actor:GetChild("Score"):setText(score)
end

local LeaderboardRequestProcessor = function(res, master)
    if master == nil then return end

    -- Iterate through each of the P1/P2 leaderboards
    for i=1, 2 do
        local leaderboard = master:GetChild("P"..tostring(i).."Leaderboard")

        local playerStr = "player"..tostring(i)
        local entryNum = 1
        -- First check to see if the leaderboard even exists.
        if data[playerStr] and data[playerStr]["gsLeaderboard"] then
            -- We want to make sure we handle the "gaps" in the ranks appropriately.
            local rankSequence = 0
            for gsEntry in ivalues(data[playerStr]["gsLeaderboard"]) do
                -- If we're "in sequence" we can just set the next entry text normally.
                if gsEntry["rank"] == rankSequence + 1 then
                    SetEntryText(
                        tostring(gsEntry["rank"].."."),
                        gsEntry["name"],
                        tostring(gsEntry["name"]/100).."%",
                        p1Leaderboard:GetChild("LeaderboardEntry"..tostring(entryNum))
                    )
                    entryNum = entryNum + 1
                    rankSequence = rankSequence + 1
                else
                    -- Otherwise we first add "..." entry to indicate a gap in the rank.
                    SetEntryText("", "...", "", p1Leaderboard:GetChild("LeaderboardEntry"..tostring(entryNum)))
                    entryNum = entryNum + 1
                    -- And then add the actual entry
                    SetEntryText(
                        tostring(gsEntry["rank"].."."),
                        gsEntry["name"],
                        tostring(gsEntry["name"]/100).."%",
                        p1Leaderboard:GetChild("LeaderboardEntry"..tostring(entryNum))
                    )
                    entryNum = entryNum + 1
                    rankSequence = gsEntry["rank"]
                end
            end
        end

        -- Empty out any remaining entries.
        -- This also handles the error case. If success is false, then the above if block will not run.
        -- and we will set the first entry to "Failed to Load".
        for i=entryNum, NumEntries do
            local entry = leaderboard:GetChild("LeaderboardEntry"..tostring(i))
            if not res["success"] and i == 1 then
                SetEntryText("", "Failed to Load", "", entry)
            else
                SetEntryText("", "", "", entry)
            end
        end
    end
end

local af = Def.ActorFrame{
    Name="LeaderboardMaster",
    InitCommand=function(self) self:visible(false) end,
    ShowLeaderboardCommand=function(self)
        self:visible(true)
        -- Only make the request when this actor gets actually displayed through the sort menu.
        self:queuecommand("SendLeaderboardRequest")
    end,
    HideLeaderboardCommand=function(self) self:visible(false) end,

    Def.Quad{ InitCommand=function(self) self:FullScreen():diffuse(0,0,0,0.875) end },
	LoadFont("Common Normal")..{
		Text=THEME:GetString("ScreenSelectMusic", "LeaderboardHelpText"),
		InitCommand=function(self) self:xy(_screen.cx, _screen.h-50):zoom(1.1) end
	},
    RequestResponseActor("Leaderboard", 10)..{
        SendLeaderboardRequestCommand=function(self)
            -- TODO(teejusb): Use proper chartHash and fetch API keys.
            MESSAGEMAN:Broadcast("Leaderboard", {
                data={
                    action="groovestats/player-leaderboards",
                    maxLeaderboardResults=10,
                    player1={
                        chartHash="",
                        apiKey="",
                    },
                    player2={
                        chartHash="",
                        apiKey="",
                    }
                },
                args=SCREENMAN:GetTopScreen():GetChild("Overlay"):GetChild("LeaderboardMaster"),
                callback=LeaderboardRequestProcessor
            })
        end
    }
}

local paneWidth = 230
local paneHeight = 360
local borderWidth = 2

-- TODO(teejusb): Handle the LeaderboardInputEventMessage to go through the different leaderboards.
for player in ivalues( PlayerNumber ) do
    af[#af+1] = Def.ActorFrame{
        Name=ToEnumShortString(player).."Leaderboard",
        InitCommand=function(self)
            self:visible(GAMESTATE:IsSideJoined(player))
            self:xy(_screen.cx + 160 * (player==PLAYER_1 and -1 or 1), _screen.cy - 15)
        end,
        PlayerJoinedMessageCommand=function(self)
            self:visible(GAMESTATE:IsSideJoined(player))
        end,
        LeaderboardInputEvent=function(self, event)

        end,

        Def.Quad {
            InitCommand=function(self)
                self:diffuse(Color.White):zoomto(paneWidth + borderWidth, paneHeight + borderWidth)
            end
        },

        Def.Quad {
            InitCommand=function(self)
                self:diffuse(Color.Black):zoomto(paneWidth, paneHeight)
            end
        },

        Def.Quad {
            InitCommand=function(self)
                self:diffuse(Color.White):zoomto(paneWidth + borderWidth, 24 + borderWidth):y(-paneHeight/2 + 12)
            end
        },

        Def.Quad {
            InitCommand=function(self)
                self:diffuse(Color.Blue):zoomto(paneWidth, 24):y(-paneHeight/2 + 12)
            end
        },

        -- Rank
        LoadFont("Wendy/_wendy small").. {
            Name="Header",
            Text="GrooveStats",
            InitCommand=function(self)
                self:zoom(0.5)
                self:y(-paneHeight/2 + 12)
            end
        },
    }
    
    local af2 = af[#af]
    -- We need 15 slots because we need space to put the "..." for non sequential rankings
    for i=1, NumEntries do
        af2[#af2+1] = Def.ActorFrame{
            Name="LeaderboardEntry"..tostring(i),
            InitCommand=function(self)
                self:y(24*(i-8) + 24)
            end,
            UpdateScore=function(self, params)
            end,

            LoadFont("Miso/_miso").. {
                Name="Rank",
                Text="",
                InitCommand=function(self)
                    self:horizalign(right)
                    self:maxwidth(30)
                    self:x(-paneWidth/2 + 30 + borderWidth)
                end
            },

            LoadFont("Miso/_miso").. {
                Name="Name",
                Text=(i==1 and "Loading" or ""),
                InitCommand=function(self)
                    self:horizalign(center)
                    self:maxwidth(130)
                    self:x(-paneWidth/2 + 100)
                end
            },

            LoadFont("Miso/_miso").. {
                Name="Score",
                Text="",
                InitCommand=function(self)
                    self:horizalign(right)
                    self:x(paneWidth/2-borderWidth)
                end
            },
        }
    end
end

return af