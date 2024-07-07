local qrcodeSize = 168
local qrModulePath = THEME:GetPathB("", "_modules/QR Code/SL-QRCode.lua")
local uuid = CRYPTMAN:GenerateRandomUUID():gsub("-", ""):upper()
local ws = nil

local ResetGrooveStatsSettings = function(pn)
  SL[pn].ApiKey = ""
  SL[pn].GrooveStatsUsername = ""
  SL[pn].IsPadPlayer = false
end

ws = NETWORK:WebSocket{
  url="ws://127.0.0.1:3000",
  pingInterval=15,
  automaticReconnect=true,
  onMessage=function(msg)
    SM(msg)
    local msgType = ToEnumShortString(msg.type)
    if msgType == "Open" then
      local data = {
        event = "uuid",
        data = {
          uuid = uuid,
        }
      }

      -- Send the UUID to the server so it can track the machine.
      ws:Send(JsonEncode(data))
    elseif msgType == "Message" then
      local resp = JsonDecode(msg.data)

      if resp.event == "apiKey" then
        local data = resp.data
        if data.uuid == uuid then
          local apiKey = data.apiKey
          local username = data.username
          local side = data.side
          local pn = (side == 1) and "P1" or "P2"
          SL[pn].ApiKey = apiKey
          SL[pn].GrooveStatsUsername = username
          -- If they're QR code logging in, let's assume they're a pad player.
          SL[pn].IsPadPlayer = true
          MESSAGEMAN:Broadcast("SetCreditsText", {pn=pn, username=username})
          MESSAGEMAN:Broadcast("HideQr", {pn=pn, username=username})
        end
      end
    end
  end,
}

local InputHandler = function(event)
	if not event.PlayerNumber or not event.button then return false end

	if event.type == "InputEventType_FirstPress" then
		if event.GameButton == "Back" then
			SCREENMAN:GetTopScreen():Cancel()

		elseif event.GameButton == "Start" then
			SCREENMAN:GetTopScreen():StartTransitioningScreen("SM_GoToNextScreen")
		end
	end
end

local af = Def.ActorFrame{
  InitCommand=function(self) self:Center() end,
  OnCommand=function(self)
    SCREENMAN:GetTopScreen():AddInputCallback(InputHandler)
  end,
  CancelCommand=function(self)
    ResetGrooveStatsSettings("P1")
    ResetGrooveStatsSettings("P2")
    ws:Close()
    SM("Cancelled")
  end,
  OffCommand=function(self) ws:Close() SM("Offed") end,

  LoadFont("Common Normal")..{
    Text=THEME:GetString("ScreenEvaluation", "PressStartToContinue"),
    InitCommand=function(self)
      self:y(150)
    end,
  },
}

local boxWidth = 200
local boxHeight = 200
local border = 2

for player in ivalues(GAMESTATE:GetHumanPlayers()) do
  local pn = ToEnumShortString(player)

  local childAf = Def.ActorFrame{
    InitCommand=function(self) self:x(200 * (player == PLAYER_1 and -1 or 1) ) end,

    -- White box for the border
    Def.Quad {
      InitCommand=function(self) self:zoomto(boxWidth, boxHeight):diffuse(Color.White) end,
    },

    -- Smaller black box for the main body
    Def.Quad {
      InitCommand=function(self) self:zoomto(boxWidth - border, boxHeight - border):diffuse(Color.Black) end,
    },

    LoadFont("Common Normal")..{
      Text=SL[pn].ApiKey and "Profile already\nconnected!" or "",
      HideQrMessageCommand=function(self, params)
        if params.pn == pn then
          self:settext(params.username .. '\nLogged in!')
        end
      end,
    },

  }

  -- This side doesn't have an API key set, display a QR code to fetch one.
  if SL[pn].ApiKey == "" then
    local side = (player == PLAYER_1) and 1 or 2
    local url = ("HTTPS://GROOVESTATS.COM/QR/%s/%d"):format(uuid, side):upper()

    childAf[#childAf+1] = LoadActor( qrModulePath , {url, qrcodeSize} )..{
      Name="QRCode",
      InitCommand=function(self) self:xy(-84, -84) end,
      HideQrMessageCommand=function(self, params) 
        if params.pn == pn then
          self:visible(false)
        end
      end
    }
  end

  af[#af+1] = childAf
end

return af