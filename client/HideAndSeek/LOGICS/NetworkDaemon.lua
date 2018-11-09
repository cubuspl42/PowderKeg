package.path = ".\\Custom\\HideAndSeek\\lua\\?.lua;" .. package.path
package.cpath = ".\\Custom\\HideAndSeek\\lua\\?.dll;" .. package.cpath

local socket = require("socket")
local json = require("json")
local os = os

local coroutine = coroutine
local yield = coroutine.yield

local VK_NUMPAD0 = 0x60
local VK_NUMPAD1 = 0x61
local VK_NUMPAD2 = 0x62
local VK_NUMPAD3 = 0x63
local VK_NUMPAD4 = 0x64
local VK_NUMPAD5 = 0x65
local VK_NUMPAD6 = 0x66
local VK_NUMPAD7 = 0x67
local VK_NUMPAD8 = 0x68
local VK_NUMPAD9 = 0x69

local config = {
	nick = "Player" .. socket.gettime()
}

local imageSets = {
	"CLAW_RACER",
	"LEVEL_ARROWSIGN_RIGHT",
	"LEVEL_POWDERKEG",
	"LEVEL_SKULL",
	"LEVEL_LITTLEPUDDLE"
}
local imageSetIndex = 1

local imageOffsetX = 0
local imageOffsetY = 0
local imageOffsetMax = 64

local zValues = {
	1000,
	4000,
	5000
}
local zValueIndex = 1

-- local host = "195.62.13.198"
local host = "localhost"
local port = 9999

local log = io.open("log.txt", "w")
log:write("Log start\n")

local avatars = {}

TextOut = TextOut or function(str)
	print(str)
end

CreateObject = CreateObject or function()
	return {
		SetAnimation = function() end,
		SetImage = function() end,
	}
end

local function sign(x)
   if x<0 then
     return -1
   elseif x>0 then
     return 1
   else
     return 0
   end
end

local keyPressedLast = 0

local function KeyPressedStable(key)
	if (GetTime() - keyPressedLast) < 300 then
		return false
	end
	local isPressed = KeyPressed(key)
	if isPressed then
		keyPressedLast = GetTime()
	end
	return isPressed
end

local function receiveData(socket)
	local partial = ""
	while true do
		local result, err
		result, err, partial = socket:receive("*l", partial)

		-- print("result, err, partial", result, err, partial)
		-- if partial then
		-- 	print("partial", partial)
		-- end

		if result ~= nil then
			return result
		else
			yield()
		end	
	end
end

local function sendData(socket, data)
	socket:send(data)
end

local function receiveMessage(socket)
	local data = receiveData(socket)
	return json.decode(data)
end

local function sendMessage(socket, message)
	local data = json.encode(message) .. "\n"
	log:write("Sending message: ", data)
	return sendData(socket, data)
end

local function createAvatar(nick)
	log:write("Creating avatar: ", nick, "\n")
	return CreateObject {logic="DoNothing"}
end

local function handleServerUpdate(message)
	for nick, clientState in pairs(message.clients) do
		local avatar = avatars[nick] or createAvatar(nick)

		-- avatar:SetAnimation("")
		local oldImageSet = GetImgStr(avatar.Image)
		if oldImageSet ~= clientState.imageSet then
			avatar:SetImage(clientState.imageSet or "")
		end
		avatar.X = clientState.x
		avatar.Y = clientState.y
		avatar.Z = clientState.z

		avatars[nick] = avatar
	end
	-- TODO: Remove avatars
end

local function downloadCoroutine(socket)
	while true do
		local message = receiveMessage(socket)
		log:write("message [reencoded]: ", json.encode(message), "\n")
		handleServerUpdate(message)
	end
end

local function buildClientState()
	local claw = GetClaw()
	return {
		nick = config.nick,
		state = {
			x = claw.X + imageOffsetX,
			y = claw.Y + imageOffsetY,
			z = zValues[zValueIndex],
			imageSet = imageSets[imageSetIndex]
		}	
	}
end

local function uploadCoroutine(socket)
	while true do
		local message = buildClientState()
		sendMessage(socket, message)
		yield()
	end
end

local socket = socket.connect(host, port)

if socket == nil then
	MessageBox("Connection failed")
end

socket:settimeout(0)

local downloadCo = coroutine.create(function() downloadCoroutine(socket) end)
local uploadCo = coroutine.create(function() uploadCoroutine(socket) end)

function main(self)
	local claw = GetClaw()
	self.X, self.Y = claw.X, claw.Y

	if self.State == 0 then
		self.State = 1
		self.Flags.flags = OR(self.Flags.flags, 2)
	end

	local res, err = coroutine.resume(downloadCo)
	if err ~= nil then log:write("res, err", res, err, "\n") end
	local res, err = coroutine.resume(uploadCo)
	if err ~= nil then log:write("res, err", res, err, "\n") end

	if KeyPressedStable(VK_NUMPAD0) then
		imageSetIndex = imageSetIndex + 1
		if imageSetIndex > #imageSets then imageSetIndex = 1 end
	end

	if KeyPressedStable(VK_NUMPAD5) then
		zValueIndex = zValueIndex + 1
		if zValueIndex > #zValues then zValueIndex = 1 end
		TextOut("Z = " .. zValues[zValueIndex])
	end

	if KeyPressed(VK_NUMPAD4) then imageOffsetX = imageOffsetX - 1 end
	if KeyPressed(VK_NUMPAD6) then imageOffsetX = imageOffsetX + 1 end
	if KeyPressed(VK_NUMPAD8) then imageOffsetY = imageOffsetY - 1 end
	if KeyPressed(VK_NUMPAD2) then imageOffsetY = imageOffsetY + 1 end

	imageOffsetX = sign(imageOffsetX) * math.min(math.abs(imageOffsetX), imageOffsetMax)
	imageOffsetY = sign(imageOffsetY) * math.min(math.abs(imageOffsetY), imageOffsetMax)
end

function test()
	while true do
		local res, err = coroutine.resume(downloadCo)
		if err ~= nil then log:write("res, err", res, err) end
		local res, err = coroutine.resume(uploadCo)
		if err ~= nil then log:write("res, err", res, err) end
		os.execute("timeout 1")
	end
end