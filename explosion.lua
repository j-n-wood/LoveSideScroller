effects = {}
effects.images = {}
effects.systems = {}
effects.types = {}

effects.load = function()
	effects.images["part1"] = love.graphics.newImage("effects/part1.png");
end	

effects.load()

function effects:spawn(etype, x, y)
	print(etype)
	local spawnfn = self.types[etype]
	if spawnfn then
		local effect = spawnfn(x,y)
		effect.alive = true
		return effect
	end
end

effects.add = function(effect)
	--push into existing slot if possible
	for idx, existing in pairs(effects.systems) do
		if (existing == nil) then
			effects.systems[idx] = effect
			return effect
		end
	end
	table.insert(effects.systems, effect)
end

effects.types['explosion'] = function(x,y)
	local effect = {}
	local p = love.graphics.newParticleSystem(effects.images["part1"], 1250)
	p:setEmissionRate(250)
	p:setSpeed(200, 300)
	p:setSizes(2, 1)
	p:setColors(220, 105, 20, 255, 194, 30, 18, 0)
	p:setPosition(400, 300)
	p:setLifetime(0.2)
	p:setParticleLife(0.3)
	p:setDirection(0)
	p:setSpread(360)
	p:setTangentialAcceleration(200)
	p:setRadialAcceleration(-1200)
	p:setPosition(0,0)
	p:start()
	effect.lifeTime = 3.0	--expire after this
	effect.particles = p
	effect.x = x
	effect.y = y
	effects.add(effect)
	return effect
end

effects.spawnSparks = function(x,y,r,g,b)
	local eff = {}
	local p = love.graphics.newParticleSystem(effects.images["part1"], 620)
	p:setEmissionRate(300)
	p:setSpeed(55, 75)
	p:setGravity(0)
	p:setSizes(0.6, 0.3)
	p:setColors(255, 255, 255, 255, r, g, b, 0)
	p:setPosition(400, 300)
	p:setLifetime(0.15)
	p:setParticleLife(1)
	p:setDirection(0)
	p:setSpread(360)
	p:setRadialAcceleration(-50)
	p:setTangentialAcceleration(120)
	p:setPosition(0,0)
	p:start()
	eff.lifeTime = 3.0	--expire after this
	eff.particles = p
	eff.x = x
	eff.y = y
	effects.add(eff)
	return eff
end

effects.types['blueSparks'] = function(x,y)
	local eff = effects.spawnSparks(x, y, 58, 128, 255)
	return eff
end

effects.types['redSparks'] = function(x,y)
	local eff = effects.spawnSparks(x, y, 255, 68, 62)
	return eff
end

effects.types['greenSparks'] = function(x,y)
	local eff = effects.spawnSparks(x, y, 70, 255, 82)
	return eff
end

effects.types['charger'] = function(x,y)
	local effect = {}
	local p = love.graphics.newParticleSystem(effects.images["part1"], 620)
	p:setEmissionRate(100)
	p:setSpeed(140, 140)
	p:setGravity(0)
	p:setSizes(0.5, 0.5)
	p:setColors(255, 255, 255, 255, 58, 128, 255, 0)
	p:setPosition(0, 0)
	p:setLifetime(-1)
	p:setParticleLife(0.7)
	p:setDirection(0)
	p:setSpread(360)
	p:setRadialAcceleration(-270)
	p:setTangentialAcceleration(120)
	p:start()
	effect.lifeTime = -1	--expire after this
	effect.particles = p
	effect.x = x
	effect.y = y
	effects.add(effect)	
	return effect
end

effects.update = function(dt)
	--update all effects
	--not all may be visible
	for idx, effect in pairs(effects.systems) do
		if effect.alive then
			effect.particles:update(dt)
			if (effect.lifeTime > -1) then
				effect.lifeTime = effect.lifeTime - dt
				if (effect.lifeTime < 0.0) then
					effects.systems[idx].alive = false
					effects.systems[idx] = nil
				end
			end
		end --alive
	end
end

effects.draw = function(elist)
	love.graphics.setColorMode("modulate")
	love.graphics.setBlendMode("additive")
	for idx, effect in pairs(elist) do
		if (effect) then
			if effect.alive then
				love.graphics.draw(effect.particles, effect.x, effect.y)
			end
		end
	end
	love.graphics.setBlendMode("alpha")
end
