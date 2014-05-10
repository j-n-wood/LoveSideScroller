local objectTypes = {}
objectTypes['trapdoor'] = 
{ 
	actions = 
	{ ['toggle'] = function(object,sender)
			print('Toggle Trapdoor')
			local isClosed = object.physics.b:isActive()
			object.physics.b:setActive( not isClosed )
			object.gid = 87 + (isClosed and 1 or 0)
			if (isClosed) then
				TEsound.play(soundCache['door_open'])
			else
				TEsound.play(soundCache['door_close'])
			end
		end
	}, 
}

objectTypes['switch'] = 
{ 
	actions = 
	{ ['toggle'] = function(object,sender)
			print('Toggle Switch')
			if (object.down) then
				object.down = false
				object.gid = object.gid - 1
			else
				object.down = true
				object.gid = object.gid + 1
			end
		end
	}, 
}

objectTypes['door'] = 
{ 
	actions = 
	{ ['open'] = function(object,sender)
			print('Open door')			
			TEsound.play(soundCache['door_open'])
			object.open = true
			object.physics.b:setActive( false )
			local layer = app.state.level.map.tl['World']
			local row = layer.tileData[object.properties.y]
			row[object.properties.x] = 134
			row[object.properties.x + 1] = 135
			row = layer.tileData[object.properties.y + 1]
			row[object.properties.x] = 149
			row[object.properties.x + 1] = 150
			row = layer.tileData[object.properties.y + 2]
			row[object.properties.x] = 164
			row[object.properties.x + 1] = 165
		end
	}, 
}

objectTypes['trigger'] = 
{ 
	actions = 
	{ ['spawn'] = function(object,sender)						
			print('Spawn',object.type)

			--find target (an enemy spawn point)
			--[[
			if object.properties.spawnFunction then
				enemyLib[object.properties.spawnFunction](app.playerLevel,object.x,object.y)
				TEsound.play(soundCache.soundSets.spawn)
			end
			]]--
			app.playerLevel:makeEnemy(object)
			TEsound.play(soundCache.soundSets.spawn)

		end
	}, 
}

return objectTypes