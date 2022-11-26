ESX,QBCORE = nil,nil
if Config.framework == 'ESX' then
	ESX = exports['es_extended']:getSharedObject()
elseif Config.framework == 'QBCORE' then
	QBCore = exports['qb-core']:GetCoreObject()
end

function GetPlayerFromId(src)
	self = {}
	self.src = src
	if Config.framework == 'ESX' then
		return ESX.GetPlayerFromId(self.src)
	elseif Config.framework == 'QBCORE' then
		xPlayer = QBCore.Functions.GetPlayer(self.src)
		if not xPlayer then return end
		return xPlayer
	end
end

GetCharacters = function(source,data)
	local characters = {}
	if Config.framework == 'ESX' then
		local id = Config.Prefix..'%:'..ESX.GetIdentifier(source)
		local data = MySQL.query.await('SELECT * FROM users WHERE identifier LIKE ?', {'%'..id..'%'})
		for k,v in pairs(data) do
			local job, grade = v.job or 'unemployed', tostring(v.job_grade)
			if ESX.Jobs[job] then
				if job ~= 'unemployed' then grade = ESX.Jobs[job].grades[grade] and ESX.Jobs[job].grades[grade].label or ESX.Jobs[job].grades[tonumber(grade)] and ESX.Jobs[job].grades[tonumber(grade)].albel else grade = '' end
				job = ESX.Jobs[job].label
			end
			local accounts = json.decode(v.accounts)
			local id = tonumber(string.sub(v.identifier, #Config.Prefix+1, string.find(v.identifier, ':')-1))
			local firstname = v.firstname or 'No name'
			local lastname = v.lastname or 'No Lastname'
			if not characters[id] then
				characters[id] = {
					slot = id,
					name = firstname..' '..lastname,
					job = job or 'Unemployed',
					grade = grade or 'No grade',
					dateofbirth = v.dateofbirth or '',
					bank = accounts.bank,
					money = accounts.money,
					skin = v.skin and json.decode(v.skin) or {},
					sex = v.sex,
					position = v.position and json.decode(v.position) or vec3(280.03,-584.29,43.29),
				}
			end
		end
		return characters
	else
		local license = QBCore.Functions.GetIdentifier(source, 'license')
		local plyChars = {}
		local result = MySQL.query.await('SELECT * FROM players WHERE license = ?', {license})
		for i = 1, (#result), 1 do
			local skin = MySQL.query.await('SELECT * FROM playerskins WHERE citizenid = ? AND active = ?', { result[i].citizenid, 1 })
			local info = json.decode(result[i].charinfo)
			local money = json.decode(result[i].money)
			local job = json.decode(result[i].job)
			characters[result[i].cid] = {
				slot = result[i].cid,
				name = info.firstname..' '..info.lastname,
				job = job.label or 'Unemployed',
				grade = job.grade.name or 'gago',
				dateofbirth = info.birthdate or '',
				bank = money.bank,
				money = money.cash,
				citizenid = result[i].citizenid,
				skin = skin and skin[1] and json.decode(skin[1].skin) or {},
				sex = info.gender == 0 and 'm' or 'f',
				position = result[i].position and json.decode(result[i].position) or vec3(280.03,-584.29,43.29),
			}
		end
		return characters
	end
end

DeleteCharacter = function(source,slot)
	if Config.framework == 'ESX' then
		local identifier = Config.Prefix..'%:'..ESX.GetIdentifier(source)
		local data = MySQL.query.await('SELECT * FROM users WHERE identifier LIKE ?', {'%'..identifier..'%'})
		for k,v in pairs(data) do
			local id = tonumber(string.sub(v.identifier, #Config.Prefix+1, string.find(v.identifier, ':')-1))
			if id == slot then
				MySQL.query.await('DELETE FROM `users` WHERE `identifier` = ?', {v.identifier})
				break
			end
		end
	else
		local license = QBCore.Functions.GetIdentifier(source, 'license')
		local result = MySQL.query.await('SELECT * FROM players WHERE license = ?', {license})
		for i = 1, (#result), 1 do
			if result[i].citizenid == slot then
				QBCore.Player.DeleteCharacter(source, result[i].citizenid)
    			TriggerClientEvent('QBCore:Notify', source, 'Character Deleted' , "success")
				break
			end
		end
	end
	return true
end

LoadPlayer = function(source)
	while not GetPlayerFromId(source) do Wait(0) print('Loading Data for '..GetPlayerName(source)..'') end
	return true
end

Login = function(source,data,new,qbslot)
	if Config.framework == 'ESX' then
		TriggerEvent('esx:onPlayerJoined', source, Config.Prefix..data, new or nil)
	else
		if new then
			new.cid = data
    		new.charinfo = {
				firstname = new.firstname,
				lastname = new.lastname,
				data = new.birthdate,
				gender = new.sex == 'm' and 0 or 1,
				nationality = 'Alien'
			}
		end
		local login = QBCore.Player.Login(source, not new and data or false, new or nil)
		Wait(1000)
		print('^2[qb-core]^7 '..GetPlayerName(source)..' (Citizen ID: '..data..') has succesfully loaded!')
        QBCore.Commands.Refresh(source)
		-- this codes below should be in playerloaded event in server. but here we need this to trigger qb-spawn and to support apartment
		loadHouseData(source)
		TriggerClientEvent('apartments:client:setupSpawnUI', source, {citizenid = data})
		TriggerEvent("qb-log:server:CreateLog", "joinleave", "Loaded", "green", "**".. GetPlayerName(source) .. "** ("..(QBCore.Functions.GetIdentifier(source, 'discord') or 'undefined') .." |  ||"  ..(QBCore.Functions.GetIdentifier(source, 'ip') or 'undefined') ..  "|| | " ..(QBCore.Functions.GetIdentifier(source, 'license') or 'undefined') .." | " ..data.." | "..source..") loaded..")
	end
	return true
end

SaveSkin = function(source,skin) -- only used on fivemappearance character creator
	if Config.framework == 'ESX' then
		local xPlayer = GetPlayerFromId(source)
		MySQL.query.await('UPDATE users SET skin = ? WHERE identifier = ?', {json.encode(skin), xPlayer.identifier})
	else
		local Player = QBCore.Functions.GetPlayer(source)
		if skin.model ~= nil and skin ~= nil then
			-- TODO: Update primary key to be citizenid so this can be an insert on duplicate update query
			MySQL.query('DELETE FROM playerskins WHERE citizenid = ?', { Player.PlayerData.citizenid }, function()
				MySQL.insert('INSERT INTO playerskins (citizenid, model, skin, active) VALUES (?, ?, ?, ?)', {
					Player.PlayerData.citizenid,
					skin.model,
					skin,
					1
				})
			end)
		end
	end
	return true
end

function loadHouseData(src)
    local HouseGarages = {}
    local Houses = {}
    local result = MySQL.query.await('SELECT * FROM houselocations', {})
    if result[1] ~= nil then
        for _, v in pairs(result) do
            local owned = false
            if tonumber(v.owned) == 1 then
                owned = true
            end
            local garage = v.garage ~= nil and json.decode(v.garage) or {}
            Houses[v.name] = {
                coords = json.decode(v.coords),
                owned = owned,
                price = v.price,
                locked = true,
                adress = v.label,
                tier = v.tier,
                garage = garage,
                decorations = {},
            }
            HouseGarages[v.name] = {
                label = v.label,
                takeVehicle = garage,
            }
        end
    end
    TriggerClientEvent("qb-garages:client:houseGarageConfig", src, HouseGarages)
    TriggerClientEvent("qb-houses:client:setHouseConfig", src, Houses)
end