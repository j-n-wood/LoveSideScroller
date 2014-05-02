entityLib = {}

entityLib.setState = function(entity, stateName)
	local newState = entity.states[stateName]
	if newState then
		entity.state = newState
		entity.renderables[1].frame = newState.frameStart
		entity.renderables[1].sx = newState.sx
		if (entity.b) then
			entity.b:setGravityScale(newState.gravity or 1.0)			
		end
	end
end	
	
entityLib.updateEntity = function(entity, dt)
	if entity.state then
		if (not entity.state.delta) then
			--+0.1 to ensure some delta, for single-frame states
			entity.state.delta = math.sign(entity.state.frameEnd - entity.state.frameStart + 0.1) * 10.0 --10 fps
		end
		local prevFrame = math.floor(entity.renderables[1].frame)
		entity.renderables[1].frame = entity.renderables[1].frame + dt * entity.state.delta
		local currFrame = math.floor(entity.renderables[1].frame)
		if (math.abs(currFrame - prevFrame) > 0.01) then
			--changed frame
			if (entity.state.events and entity.state.events[currFrame]) then
				entity.state.events[currFrame](entity)
			end
		end
		
		local sequenceComplete = false
		if (entity.state.delta > 0.0) then
			if ((entity.renderables[1].frame - entity.state.frameEnd) >= 1.0) then
				sequenceComplete = true
			end
		else
			if (entity.renderables[1].frame < entity.state.frameEnd) then
				sequenceComplete = true
			end
		end
		
		if (sequenceComplete) then
			if (entity.state.loop) then
				entity.renderables[1].frame = entity.state.frameStart
			else
				if (entity.state.nextState) then
					entity.setState(entity,entity.state.nextState)
				else
					entity.renderables[1].frame = entity.state.frameEnd
				end
			end
		end
	end
end	

entityLib.takeDamage = function(entity, dam)
	print('Entity',entity.type,'hit for dam',dam)
	if (entity.life) and (entity.alive) then
		print('Entity',entity.type,'takes dam',dam)
		entity.life = entity.life - dam
		if (entity.life <= 0) then
			entityLib.destroy(entity, entity)
		end
	end
end

entityLib.update = function(entity, dt)
end

entityLib.destroy = function(entity, sender)
	entity.alive = false
	if (entity.onDeath) then
		entity:onDeath()
	end
end

newEntity = function(inx, iny, intype)
	local result = { actions = {}, alive = true, expired = false, type = intype, x = inx, y = iny, theta = 0, dtheta = 0.0, renderables = {}, dx = 0.0, dy = 0.0, onContact = {}, }
	result.actions.destroy = entityLib.destroy
	setmetatable(result, {__index = entityLib})
	return result
end

return entityLib
