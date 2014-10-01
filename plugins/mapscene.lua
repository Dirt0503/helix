PLUGIN.name = "Map Scenes"
PLUGIN.author = "Chessnut"
PLUGIN.desc = "Adds areas of the map that are visible during character selection."
PLUGIN.scenes = PLUGIN.scenes or {}

if (CLIENT) then
	function PLUGIN:CalcView(client, origin, angles, fov)
		local scenes = self.scenes

		if (IsValid(nut.gui.char) and table.Count(scenes) > 0) then
			local key = self.index
			local value = scenes[self.index]

			if (!self.index or !value) then
				value, key = table.Random(scenes)
				self.index = key
			end

			local view = {}

			if (type(key) == "Vector") then
				local curTime = CurTime()

				if (!self.startTime) then
					self.startTime = curTime
					self.finishTime = curTime + 30
				end

				local fraction = math.min(math.TimeFraction(self.startTime, self.finishTime, CurTime()), 1)

				if (value) then
					view.origin = LerpVector(fraction, key, value[1])
					view.angles = LerpAngle(fraction, value[2], value[3])
				end

				if (fraction >= 1) then
					self.startTime = curTime
					self.finishTime = curTime + 30
					
					local keys = {}

					for k, v in pairs(scenes) do
						if (type(k) == "Vector") then
							keys[#keys + 1] = k
						end
					end

					self.index = table.Random(keys)
				end
			elseif (value) then
				view.origin = value[1]
				view.angles = value[2]
			end

			return view
		end
	end

	local PLUGIN = PLUGIN

	netstream.Hook("mapScn", function(data, origin)
		if (type(origin) == "Vector") then
			PLUGIN.scenes[origin] = data
		else
			PLUGIN.scenes[#PLUGIN.scenes + 1] = data
		end
	end)

	netstream.Hook("mapScnDel", function(key)
		PLUGIN.scenes[key] = nil
	end)

	netstream.Hook("mapScnInit", function(scenes)
		PLUGIN.scenes = scenes
	end)
else
	function PLUGIN:SaveData()
		self:setData(self.scenes)
	end

	function PLUGIN:LoadData()
		self.scenes = self:getData() or {}
	end

	function PLUGIN:PlayerInitialSpawn(client)
		netstream.Start(client, "mapScnInit", self.scenes)
	end

	function PLUGIN:addScene(position, angles, position2, angles2)
		local data

		if (position2) then
			data = {position2, angles, angles2}
			self.scenes[position] = data
		else
			data = {position, angles}
			self.scenes[#self.scenes + 1] = data
		end

		netstream.Start(nil, "mapScn", data, position2 and position or nil)
		self:SaveData()
	end
end

local PLUGIN = PLUGIN

nut.command.add("mapsceneadd", {
	adminOnly = true,
	syntax = "[bool isPair]",
	onRun = function(client, arguments)
		local position, angles = client:EyePos(), client:EyeAngles()

		-- This scene is in a pair for moving scenes.
		if (util.tobool(arguments[1]) and !client.nutScnPair) then
			client.nutScnPair = {position, angles}

			return L("mapRepeat", client)
		else
			if (client.nutScnPair) then
				PLUGIN:addScene(client.nutScnPair[1], client.nutScnPair[2], position, angles)
				client.nutScnPair = nil
			else
				PLUGIN:addScene(position, angles)
			end

			return L("mapAdd", client)
		end
	end
})

nut.command.add("mapsceneremove", {
	adminOnly = true,
	syntax = "[number radius]",
	onRun = function(client, arguments)
		local radius = tonumber(arguments[1]) or 280
		local position = client:GetPos()
		local i = 0

		for k, v in pairs(PLUGIN.scenes) do
			local delete = false

			if (type(k) == "Vector") then
				if (k:Distance(position) <= radius or v[1]:Distance(position) <= radius) then
					delete = true
				end
			elseif (v[1]:Distance(position) <= radius) then
				delete = true
			end

			if (delete) then
				netstream.Start(nil, "mapScnDel", k)
				PLUGIN.scenes[k] = nil

				i = i + 1
			end
		end

		if (i > 0) then
			PLUGIN:SaveData()
		end

		return L("mapDel", client, i)
	end
})