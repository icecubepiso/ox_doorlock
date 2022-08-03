lib.locale()
TriggerServerEvent('ox_doorlock:getDoors')

local function createDoor(door)
	local double = door.doors

	if double then
		for i = 1, 2 do
			AddDoorToSystem(double[i].hash, double[i].model, double[i].coords.x, double[i].coords.y, double[i].coords.z, false, false, false)
			DoorSystemSetDoorState(double[i].hash, 4, false, false)
			DoorSystemSetDoorState(double[i].hash, door.state, false, false)

			if door.doorRate then
				DoorSystemSetAutomaticRate(double[i].hash, door.doorRate, false, false)
			end
		end
	else
		AddDoorToSystem(door.hash, door.model, door.coords.x, door.coords.y, door.coords.z, false, false, false)
		DoorSystemSetDoorState(door.hash, 4, false, false)
		DoorSystemSetDoorState(door.hash, door.state, false, false)

		if door.doorRate then
			DoorSystemSetAutomaticRate(door.hash, door.doorRate, false, false)
		end
	end
end

local nearbyDoors = {}
local Entity = Entity

RegisterNetEvent('ox_doorlock:setDoors', function(data, sounds)
	doors = data

	SendNUIMessage({
		action = 'setSoundFiles',
		data = sounds
	})

	for _, door in pairs(data) do
		createDoor(door)
	end

	while true do
		table.wipe(nearbyDoors)
		local coords = GetEntityCoords(cache.ped)

		for _, door in pairs(doors) do
			local double = door.doors
			door.distance = #(coords - door.coords)

			if double then
				if door.distance < 80 then
					if not double[1].entity and IsModelValid(double[1].model) and IsModelValid(double[2].model) then
						for i = 1, 2 do
							local entity = GetClosestObjectOfType(double[i].coords.x, double[i].coords.y, double[i].coords.z, 1.0, double[i].model, false, false, false)

							if entity ~= 0 then
								double[i].entity = entity
								Entity(entity).state.doorId = door.id
							end
						end
					end

					if door.distance < 20 then
						nearbyDoors[#nearbyDoors + 1] = door
					end
				elseif double[1].entity then
					for i = 1, 2 do
						double[i].entity = nil
					end
				end
			elseif door.distance < 80 then
				if not door.entity and IsModelValid(door.model) then
					local entity = GetClosestObjectOfType(door.coords.x, door.coords.y, door.coords.z, 1.0, door.model, false, false, false)

					if entity ~= 0 then
						local min, max = GetModelDimensions(door.model)
						local points = {
							GetOffsetFromEntityInWorldCoords(entity, min.x, min.y, min.z).xy,
							GetOffsetFromEntityInWorldCoords(entity, min.x, min.y, max.z).xy,
							GetOffsetFromEntityInWorldCoords(entity, min.x, max.y, max.z).xy,
							GetOffsetFromEntityInWorldCoords(entity, min.x, max.y, min.z).xy,
							GetOffsetFromEntityInWorldCoords(entity, max.x, min.y, min.z).xy,
							GetOffsetFromEntityInWorldCoords(entity, max.x, min.y, max.z).xy,
							GetOffsetFromEntityInWorldCoords(entity, max.x, max.y, max.z).xy,
							GetOffsetFromEntityInWorldCoords(entity, max.x, max.y, min.z).xy
						}

						local centroid = vec(0, 0)

						for i = 1, 8 do
							centroid += points[i]
						end

						centroid /= 8
						door.coords = vec3(centroid.x, centroid.y, door.coords.z)
						door.entity = entity
						Entity(entity).state.doorId = door.id
					end
				end

				if door.distance < 20 then
					nearbyDoors[#nearbyDoors + 1] = door
				end
			elseif door.entity then
				door.entity = nil
			end
		end

		Wait(500)
	end
end)

RegisterNetEvent('ox_doorlock:setState', function(id, state, source, data)
	if not doors then return end

	if data then
		doors[id] = data
		createDoor(data)
	end

	if Config.Notify and source == cache.serverId then
		if state == 0 then
			lib.notify({
				type = 'success',
				icon = 'unlock',
				description = locale('unlocked_door')
			})
		else
			lib.notify({
				type = 'success',
				icon = 'lock',
				description = locale('locked_door')
			})
		end
	end

	local door = data or doors[id]
	local double = door.doors
	door.state = state

	if double then
		-- Disabled a consistent methood of accelerating a locked door is found.
		-- Some users reported doors getting stuck in the incorrect state.
		-- while not door.auto and door.state == 1 and double[1].entity do
		-- 	local doorOneHeading = double[1].heading
		-- 	local doorOneCurrentHeading = math.floor(GetEntityHeading(double[1].entity) + 0.5)

		-- 	if doorOneHeading == doorOneCurrentHeading then
		-- 		DoorSystemSetDoorState(double[1].hash, door.state, false, false)
		-- 	end

		-- 	local doorTwoHeading = double[2].heading
		-- 	local doorTwoCurrentHeading = math.floor(GetEntityHeading(double[2].entity) + 0.5)

		-- 	if doorTwoHeading == doorTwoCurrentHeading then
		-- 		DoorSystemSetDoorState(double[2].hash, door.state, false, false)
		-- 	end

		-- 	if doorOneHeading == doorOneCurrentHeading and doorTwoHeading == doorTwoCurrentHeading then break end
		-- 	Wait(0)
		-- end

		for i = 1, 2 do
			DoorSystemSetDoorState(double[i].hash, door.state, false, false)
		end
	else
		-- Disabled a consistent methood of accelerating a locked door is found.
		-- Some users reported doors getting stuck in the incorrect state.
		-- while not door.auto and door.state == 1 and door.entity do
		-- 	local heading = math.floor(GetEntityHeading(door.entity) + 0.5)
		-- 	if heading == door.heading then break end
		-- 	Wait(0)
		-- end

		DoorSystemSetDoorState(door.hash, door.state, false, false)
	end

	if door.state == state and door.distance and door.distance < 20 then
		local volume = (0.01 * GetProfileSetting(300)) / (door.distance / 2)
		if volume > 1 then volume = 1 end
		local sound = state == 0 and door.unlockSound or door.lockSound or 'door-bolt-4'

		SendNUIMessage({
			action = 'playSound',
			data = {
				sound = sound,
				volume = volume
			}
		})
	end
end)

RegisterNetEvent('ox_doorlock:editDoorlock', function(id, data)
	if source == '' then return end

	local door = doors[id]
	local double = door.doors
	local doorState = data and data.state or 0
	local doorRate = data and data.doorRate or (door.doorRate and 0.0)

	-- hacky method to resolve a bug with "closest door" by forcing a distance recalculation
	if data and door.distance < 20 then door.distance = 80 end

	if double then
		for i = 1, 2 do
			if doorRate then
				DoorSystemSetAutomaticRate(double[i].hash, doorRate, false, false)
			end

			DoorSystemSetDoorState(double[i].hash, doorState, false, false)

			if not data then
				RemoveDoorFromSystem(double[i].hash)

				if double[i].entity then
					Entity(double[i].entity).state.doorId = nil
				end
			end
		end
	else
		if doorRate then
			DoorSystemSetAutomaticRate(door.hash, doorRate, false, false)
		end

		DoorSystemSetDoorState(door.hash, doorState, false, false)

		if not data then
			RemoveDoorFromSystem(door.hash)

			if door.entity then
				Entity(door.entity).state.doorId = nil
			end
		end
	end

	doors[id] = data
end)

CreateThread(function()
	local lastTriggered = 0
	local lockDoor = locale('lock_door')
	local unlockDoor = locale('unlock_door')
	local closestDoor
	local showUI
	local drawSprite = Config.DrawSprite

	if drawSprite then
		local sprite1 = drawSprite[0]?[1]
		local sprite2 = drawSprite[1]?[1]

		if sprite1 then
			RequestStreamedTextureDict(sprite1, true)
		end

		if sprite2 then
			RequestStreamedTextureDict(sprite2, true)
		end
	end

	local SetDrawOrigin = SetDrawOrigin
	local ClearDrawOrigin = ClearDrawOrigin
	local DrawSprite = drawSprite and DrawSprite

	while true do
		local num = #nearbyDoors

		if num > 0 then
			local ratio = drawSprite and GetAspectRatio(true)
			for i = 1, num do
				local door = nearbyDoors[i]

				if door.distance < door.maxDistance then
					if door.distance < (closestDoor?.distance or 10) then
						closestDoor = door
					end

					if drawSprite and not door.hideUi then
						local sprite = drawSprite[door.state]

						if sprite then
							SetDrawOrigin(door.coords.x, door.coords.y, door.coords.z)
							DrawSprite(sprite[1], sprite[2], sprite[3], sprite[4], sprite[5], sprite[6] * ratio, sprite[7], sprite[8], sprite[9], sprite[10], sprite[11])
							ClearDrawOrigin()
						end
					end
				end
			end
		else closestDoor = nil end

		if closestDoor and closestDoor.distance < closestDoor.maxDistance then
			if Config.DrawTextUI then
				if closestDoor.state == 0 and showUI ~= 0 and not closestDoor.hideUi then
					lib.showTextUI(lockDoor)
					showUI = 0
				elseif closestDoor.state == 1 and showUI ~= 1 and not closestDoor.hideUi then
					lib.showTextUI(unlockDoor)
					showUI = 1
				end
			end

			if IsDisabledControlJustReleased(0, 38) then
				if closestDoor.passcode then
					local input = lib.inputDialog(locale('door_lock'), {
						{ type = "input", label = locale("passcode"), password = true, icon = 'lock' },
					})

					if input then
						TriggerServerEvent('ox_doorlock:setState', closestDoor.id, closestDoor.state == 1 and 0 or 1, false, input[1])
					end
				else
					local gameTimer = GetGameTimer()

					if gameTimer - lastTriggered > 500 then
						lastTriggered = gameTimer
						TriggerServerEvent('ox_doorlock:setState', closestDoor.id, closestDoor.state == 1 and 0 or 1)
					end
				end
			end
		elseif showUI then
			lib.hideTextUI()
			showUI = nil
		end

		Wait(num > 0 and 0 or 500)
	end
end)
