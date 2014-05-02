local soundCache = {}
soundCache.soundSets = {}

local loadSound = function( name, cache )
	local filename = 'sound/' .. name .. '.wav'
	cache[name] = love.sound.newSoundData( filename )
	return cache[name]
end

local loadSounds = function( names, cache )
	for idx, name in ipairs(names) do
		loadSound(name,cache)
	end
end

local loadSoundSet = function( setName, names, cache )
	local set = {}
	for idx, name in ipairs(names) do
		table.insert(set,loadSound(name,cache))
	end
	cache.soundSets[setName] = set
end

loadSound('weapon_throw',soundCache)
loadSound('jump',soundCache)
loadSounds( {'hurt_1','hurt_2',},soundCache)
loadSounds( {'door_open','door_close',},soundCache)
loadSounds( {'explosion_ground_1','explosion_ground_2',},soundCache)
loadSoundSet( 'itemBounce', {'item_bounce_1','item_bounce_2','item_bounce_3','item_bounce_4',},soundCache)
loadSoundSet( 'spawn', {'spawn_high','spawn_low','spawn_mid','spawn_mid2',},soundCache)
loadSoundSet( 'bossWalk', {'boss_walk_1','boss_walk_2',},soundCache)
loadSound('boss_shoot_1',soundCache)

return soundCache