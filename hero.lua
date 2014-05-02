require 'entity'
require 'imageLib'

heroLib = {}
heroImages = {}

heroLib.consts = 
{
	walkForce = 550.0,
	walkDecelerateScale = 5.0,
	jumpImpulse = 230.0,
	jumpCooldownTime = 1.0,
}

heroLib.load = function()
	if (not heroLib.loaded) then
		imageLib.makeTiledSprite(heroImages,"hero","hero_2.png","alpha",1.0,1.0,8,5.3333333,'bottom',true)
		
		local commonQuads = 
		{
			{ x = 0, y = 0, w = 32, h = 32, },
			{ x = 32, y = 0, w = 32, h = 32, },
			{ x = 0, y = 0, w = 96, h = 16, },
			{ x = 0, y = 48, w = 48, h = 48, },	--4 = health cup
			{ x = 48, y = 48, w = 48, h = 48, },
			{ x = 96, y = 48, w = 48, h = 48, },
			{ x = 144, y = 48, w = 48, h = 48, },
			{ x = 192, y = 48, w = 48, h = 48, },			
		}
		
		--insert 24 death sprites
		--frames 9 - 33
		for idy = 0,2,1 do			
			for idx = 0,8,1 do				
				local frame = { x = idx * 64, y = 96 + idy * 64, w = 64, h = 64, }	--death sprites				
				table.insert(commonQuads,frame)				
				print('Quadcount',#commonQuads,table.getn(commonQuads))
			end
		end
		
		--frames at 288 down, 32x32
		--34 - 44 
		--45 spark
		--46 fireball
		for idx = 0,12,1 do
			local frame = { x = idx * 32, y = 288, w = 32, h = 32, }
			table.insert(commonQuads,frame)
		end
		
		--47 - 53 - pickup smoke
		for idx = 0,7,1 do
			local frame = { x = idx * 32, y = 320, w = 32, h = 32, }
			table.insert(commonQuads,frame)
		end
		print('Quadcount',#commonQuads,table.getn(commonQuads))
		imageLib.makeSpriteSheet(heroImages,"common","common.png","alpha",true,commonQuads)
		heroLib.loaded = true
	end
end

heroLib.defaultControls = function(hero)
	--doing something uninterruptable
end

heroLib.activate = function(hero)
	--do something with environment	
	if (hero.controls.sensedObject) and (hero.controls.activateCooldown <= 0.0) and (hero.controls.sensedObject.properties.action) then
		hero.controls.activateCooldown = 0.2
		local obj = hero.controls.sensedObject
		if (obj.properties.action) and (objectTypes[obj.type]) and (objectTypes[obj.type].actions[obj.properties.action]) then
				objectTypes[obj.type].actions[obj.properties.action](obj)
		end
		if (obj.properties.targetEntity) then
			--print('search entity target',obj.properties.targetClass,obj.properties.target)
			local target = app.playerLevel:findEntity('entities',obj.properties.targetEntity)
			if (target) then
				print('found entity target',target.type,target.name)
				local action = target.actions[obj.properties.targetAction]
				if action then
					--print('found action')
					action(target, hero)
				end				
			end
			return
		end
		local target = app.playerLevel.level:findObject(obj.properties.targetClass or 'Switches',obj.properties.target)
		if (target) then
			print('found target',target.type,target.name)
			--TODO - use metatables to attach actions to objects
			--TODO - target could be an Entity, not an object in the map
			local actionSet = objectTypes[target.type] or target
			local action = actionSet.actions[obj.properties.targetAction]
			if action then
				--print('found action')
				action(target, hero)
			end
		end
			
	end
end

heroLib.inventory = function(hero)
	if (hero.controls.sensedItem) then
		hero.inventory[hero.controls.sensedItem.name] = hero.controls.sensedItem
		hero.controls.sensedItem.alive = false
		hero.controls.sensedItem = nil
	end
end

heroLib.standForwardControls = function(hero)
	if love.keyboard.isDown("d") then 
		hero.setState(hero,'turnRight')
	elseif love.keyboard.isDown("a") then
		hero.setState(hero,'turnLeft')
	end
	
	if (love.keyboard.isDown(" ")) then
		heroLib.activate(hero)
	end
end

heroLib.standBackwardControls = function(hero)
	if hero.controls.sensedLadder then
		if love.keyboard.isDown("w") then
			hero.setState(hero,'onLadder')
		end
	end

	if love.keyboard.isDown("d") then 
		hero.setState(hero,'turnBackRight')
	elseif love.keyboard.isDown("a") then
		hero.setState(hero,'turnBackLeft')
	end
	
	if (love.keyboard.isDown(" ")) then
		heroLib.activate(hero)
	end	
end

heroLib.jump = function(hero, newstate)
	--jump
	local direction = 0.0	--upwards. used for mantle jumps. mantling allows air control towards target direction
	local vertImpulse = heroLib.consts.jumpImpulse
	if love.keyboard.isDown("d") then
		if (hero.controls.sensedMantleRight == 0) then
			direction = 1.0
		else
			vertImpulse = vertImpulse * 1.35
		end
	elseif love.keyboard.isDown("a") then
		if (hero.controls.sensedMantleLeft == 0) then
			direction = -1.0
		else
			vertImpulse = vertImpulse * 1.35			
		end
	else
		return false --no straight up jump
	end
			
	if (hero.controls.jumpCooldown == 0) and ((hero.controls.sensedGround > 0) or (hero.controls.sensedLadder)) then
		if direction < 0.0 then
			--jump left
			hero.b:applyLinearImpulse(-heroLib.consts.jumpImpulse, -vertImpulse)
		elseif direction > 0.0 then
			--jump right
			hero.b:applyLinearImpulse(heroLib.consts.jumpImpulse, -vertImpulse)		
		else
			--jump up
			hero.b:applyLinearImpulse(0, -vertImpulse)
		end
		hero.controls.jumpCooldown = 1.5 --heroLib.consts.jumpCooldownTime
		hero.setState(hero,newstate)
		TEsound.play(soundCache['jump'])
		return true
	end
	return false
end

heroLib.onLadderControls = function(hero)
	if (hero.controls.sensedLadder) then
		if love.keyboard.isDown("w") then
			if love.keyboard.isDown("a") then
				heroLib.jump(hero,'jumpLeft')
			elseif love.keyboard.isDown("d") then
				heroLib.jump(hero,'jumpRight')
			else
				hero.b:applyForce(0, -320)
			end
			return
		elseif love.keyboard.isDown("s") then
			if (hero.controls.sensedGround > 0) then
				hero.setState(hero,'standBackward')
			end
			print("Down ladder!")
			hero.b:applyForce(0, 320)
		else
			--rapid drag
			local dx, dy = hero.b:getLinearVelocity()
			hero.b:applyForce(-dx * 10,-dy * 10)
			if (hero.controls.sensedGround > 0) then
				hero.setState(hero,'standBackward')
			end
		end
		
		if (love.keyboard.isDown(" ")) and ((hero.controls.throwCooldown == 0)) then
			hero.setState(hero,'onLadderThrowRight')
			hero.controls.throwCooldown = 0.3
			hero.controls.throw = true
			return
		end
	else
		hero.setState(hero,'standBackward')
	end
end

heroLib.decelerate = function(hero)
	local dx, dy = hero.b:getLinearVelocity()
	hero.b:applyForce(-dx * heroLib.consts.walkDecelerateScale,0)
end

heroLib.crouchControls = function(hero)
	if not love.keyboard.isDown("s") then
		if (hero.state.sx > 0.0) then
			hero.setState(hero,'riseRight')
		else
			hero.setState(hero,'riseLeft')
		end
	end
	
	if (love.keyboard.isDown(" ")) then
		heroLib.inventory(hero)
	end	
end

heroLib.faceRightControls = function(hero)
	if love.keyboard.isDown("d") then
		hero.b:applyForce(heroLib.consts.walkForce, 0)
		if (hero.state ~= hero.states.walkRight) then
			hero.setState(hero,'walkRight')
		end
	elseif love.keyboard.isDown("a") then
		hero.setState(hero,'turnLeft')
	elseif love.keyboard.isDown("s") then
		hero.setState(hero,'crouchRight')
	else
		hero.setState(hero,'standRight')
		heroLib.decelerate(hero)
	end
	
	if love.keyboard.isDown("w") then
		if (hero.controls.sensedLadder) then
			print("Up ladder!")
			hero.setState(hero,'onLadder')
		else
			if love.keyboard.isDown("d") then
				heroLib.jump(hero,'jumpRight')
			else
				hero.setState(hero,'turnRightBack')
			end
		end			
	end
	
	if (love.keyboard.isDown(" ")) and ((hero.controls.throwCooldown == 0)) then
		hero.setState(hero,'throwRight')
		hero.controls.throwCooldown = 0.3
		hero.controls.throw = true
		return
	end
end

heroLib.faceLeftControls = function(hero)
	if love.keyboard.isDown("a") then
		if (hero.state ~= hero.states.walkLeft) then
			hero.setState(hero,'walkLeft')
		end
		hero.b:applyForce(-heroLib.consts.walkForce, 0)
	elseif love.keyboard.isDown("d") then
		hero.setState(hero,'turnRight')
	elseif love.keyboard.isDown("s") then
		hero.setState(hero,'crouchLeft')		
	else	
		hero.setState(hero,'standLeft')
		heroLib.decelerate(hero)
	end
	
	if love.keyboard.isDown("w") then
		if (hero.controls.sensedLadder) then
			print("Up ladder!")
			hero.setState(hero,'onLadder')
		else
			if love.keyboard.isDown("a") then
				heroLib.jump(hero,'jumpLeft')
			else
				hero.setState(hero,'turnLeftBack')
			end			
		end			
	end	
	
	if (love.keyboard.isDown(" ")) and ((hero.controls.throwCooldown == 0)) then
		hero.setState(hero,'throwLeft')
		hero.controls.throwCooldown = 0.3
		hero.controls.throw = true
		return
	end	
end

heroLib.jumpRightControls = function(hero)
	if (hero.controls.jumpCooldown < 1.0) and (hero.controls.sensedGround > 0) then
		--set to standing state
		hero.setState(hero,'standRight')
	else
		if (hero.state ~= hero.states.fallRight) and (hero.state ~= hero.states.jumpThrowRight) then
			local dx, dy = hero.b:getLinearVelocity()
			if (dy > 50) then
				hero.setState(hero,'fallRight')
			end
		end
		
		if (love.keyboard.isDown(" ")) and ((hero.controls.throwCooldown == 0)) then
			hero.setState(hero,'jumpThrowRight')
			hero.controls.throwCooldown = 0.3
			hero.controls.throw = true
			return
		end
		
		if love.keyboard.isDown("d") and (hero.controls.sensedMantleRight > 0) then
			hero.b:applyLinearImpulse(heroLib.consts.jumpImpulse * 0.1, 0.0) -- -heroLib.consts.jumpImpulse * 0.05)
		end
		
		if love.keyboard.isDown("w") and(hero.controls.sensedLadder) and (hero.controls.jumpCooldown == 0) then
			hero.setState(hero,'onLadder')
		end
	end
end

heroLib.jumpLeftControls = function(hero)
	if (hero.controls.jumpCooldown < 1.0) and (hero.controls.sensedGround > 0) then
		--set to standing state
		hero.setState(hero,'standLeft')
	else
		if (hero.state ~= hero.states.fallLeft) and (hero.state ~= hero.states.jumpThrowLeft) then
			local dx, dy = hero.b:getLinearVelocity()
			if (dy > 50) then
				hero.setState(hero,'fallLeft')
			end
		end
		
		if (love.keyboard.isDown(" ")) and ((hero.controls.throwCooldown == 0)) then
			hero.setState(hero,'jumpThrowLeft')
			hero.controls.throwCooldown = 0.3
			hero.controls.throw = true
			return
		end
		
		if love.keyboard.isDown("a") and (hero.controls.sensedMantleLeft > 0) then
			hero.b:applyLinearImpulse(-heroLib.consts.jumpImpulse * 0.1, 0.0) -- -heroLib.consts.jumpImpulse * 0.05)
		end		

		if love.keyboard.isDown("w") and(hero.controls.sensedLadder) and (hero.controls.jumpCooldown == 0) then
			hero.setState(hero,'onLadder')
		end
	end
end

local heroStates =
	{
		standForward = { frameStart = 1, frameEnd = 1, sx = 1.0, controls = heroLib.standForwardControls, },
		standRight = { frameStart = 3, frameEnd = 3, sx = 1.0, controls = heroLib.faceRightControls,},
		standLeft = { frameStart = 3, frameEnd = 3, sx = -1.0, controls = heroLib.faceLeftControls,},
		turnRight = { frameStart = 2, frameEnd = 3, sx = 1.0, nextState = 'standRight', controls = heroLib.defaultControls, },
		turnLeft = { frameStart = 2, frameEnd = 3, sx = -1.0, nextState = 'standLeft', controls = heroLib.defaultControls, },
		walkRight = { frameStart = 9, frameEnd = 16, sx = 1.0, loop = true, controls = heroLib.faceRightControls, },
		walkLeft = { frameStart = 9, frameEnd = 16, sx = -1.0, loop = true, controls = heroLib.faceLeftControls, },
		jumpRight = { frameStart = 4, frameEnd = 5, sx = 1.0, controls = heroLib.jumpRightControls, },
		jumpLeft = { frameStart = 4, frameEnd = 5, sx = -1.0, controls = heroLib.jumpLeftControls, },
		fallRight = { frameStart = 6, frameEnd = 6, sx = 1.0, controls = heroLib.jumpRightControls, },
		fallLeft = { frameStart = 6, frameEnd = 6, sx = -1.0, controls = heroLib.jumpLeftControls, },
		throwRight = { frameStart = 17, frameEnd = 19, sx = 1.0, nextState = 'standRight', controls = heroLib.defaultControls, },
		throwLeft = { frameStart = 17, frameEnd = 19, sx = -1.0, nextState = 'standLeft', controls = heroLib.defaultControls, },
		jumpThrowRight = { frameStart = 20, frameEnd = 22, sx = 1.0, nextState = 'jumpRight', controls = heroLib.jumpRightControls, },
		jumpThrowLeft = { frameStart = 20, frameEnd = 22, sx = -1.0, nextState = 'jumpLeft', controls = heroLib.jumpLeftControls, },
		onLadder = { frameStart = 26, frameEnd = 28, sx = 1.0, loop = true, controls = heroLib.onLadderControls, gravity = 0.0, },
		onLadderThrowRight = { frameStart = 28, frameEnd = 30, sx = 1.0, nextState = 'onLadder', controls = heroLib.onLadderControls, gravity = 0.0,},
		onLadderThrowLeft = { frameStart = 28, frameEnd = 30, sx = -1.0, nextState = 'onLadder', controls = heroLib.onLadderControls, gravity = 0.0,},
		standBackward = { frameStart = 25, frameEnd = 25, sx = 1.0, controls = heroLib.standBackwardControls, },
		turnBackLeft = { frameStart = 32, frameEnd = 32, sx = -1.0, nextState = 'standLeft', controls = heroLib.defaultControls, },
		turnBackRight = { frameStart = 32, frameEnd = 32, sx = 1.0, nextState = 'standRight', controls = heroLib.defaultControls, },
		turnLeftBack = { frameStart = 32, frameEnd = 32, sx = -1.0, nextState = 'standBackward', controls = heroLib.defaultControls, },
		turnRightBack = { frameStart = 32, frameEnd = 32, sx = 1.0, nextState = 'standBackward', controls = heroLib.defaultControls, },
		crouchRight = { frameStart = 33, frameEnd = 34, sx = 1.0, controls = heroLib.crouchControls, },
		crouchLeft = { frameStart = 33, frameEnd = 34, sx = -1.0, controls = heroLib.crouchControls, },
		riseRight = { frameStart = 34, frameEnd = 33, sx = 1.0, nextState = 'standRight', controls = heroLib.defaultControls, },
		riseLeft = { frameStart = 34, frameEnd = 33, sx = -1.0, nextState = 'standLeft', controls = heroLib.defaultControls, },
	}
	
heroLib.addWalkerBody = function(r,entity)
	bodyResponse = {}
	bodyResponse.entity = entity
	bodyResponse.onContact = bodyContact
	
	entity.s = love.physics.newCircleShape(0, -r, r)
	--[[
	entity.s = love.physics.newPolygonShape( -0.85 * r, - 1.5 * r, 
											  0.85 * r, - 1.5 * r,
											  0.4 * r, -0.2 * r,
											  0, 0, 
											 -0.4 * r, -0.2 * r)
											 ]]--
	entity.f = love.physics.newFixture(entity.b, entity.s, 0.75)
	entity.f:setRestitution(0.1)
	entity.f:setFriction(0.1)
	entity.f:setUserData(bodyResponse)
	entity.f:setCategory(9)
	entity.f:setMask(2)	--not items, shots
	entity.f:setMask(8)
	
	entity.s = love.physics.newCircleShape(0, -90 + r, r )
	entity.f = love.physics.newFixture(entity.b, entity.s, 0.75)
	entity.f:setRestitution(0.1)
	entity.f:setFriction(0.1)	
	entity.f:setUserData(bodyResponse)
	entity.f:setCategory(9)
	entity.f:setMask(2)	--not items
	entity.f:setMask(8) --not player shots
	
	--print('density',entity.f:getDensity())
		
	return bodyResponse
end
	
heroLib.addWalkerToEntity = function(world, w, h, entity)
	entity.b = love.physics.newBody(world, entity.x, entity.y, "dynamic")
	heroLib.addWalkerBody(w/2,entity)
	entity.b:setFixedRotation(true)	
end

heroLib.onContactEnemy = function(thisEntity, otherEntity, begin)
	local dam = math.min(otherEntity.life,thisEntity.life)
	if (dam > 0) then
		thisEntity.takeDamage(thisEntity,otherEntity.life)
		otherEntity.takeDamage(otherEntity,otherEntity.life)
		TEsound.play({soundCache['hurt_1'],soundCache['hurt_2']})
	end
end

heroLib.onContactGrinder = function(thisEntity, otherEntity, begin)	
	if (begin) then
		print('hero touched grinder')	
		thisEntity.controls.sensedGrinder = thisEntity.controls.sensedGrinder + 1
	else
		thisEntity.controls.sensedGrinder = thisEntity.controls.sensedGrinder - 1
	end
end
	
heroLib.makeHero = function(level,x,y)
	heroLib.load()
	
	local entity = newEntity(x,y,'hero')
	entity.life = 100
	entity.inventory = {}
	
	imageLib.addRenderableSprite(entity.renderables,heroImages["hero"],1.0,1.0)	
	entity.states = heroStates
	--entity.state = heroStates.standForward
	entity.setState(entity,'standForward')
	entity.controls = { jumpCooldown = 0, onGround = false, sensedGround = 0, throwCooldown = 0.0, sensedLadder = false, activateCooldown = 0.0, sensedItem = nil, sensedGrinder = 0, }	
	
	heroLib.addWalkerToEntity(level.world,54,128,entity)	
	level:addGroundSensor(54,128,entity)
	level:addMantleSensors(54,128,entity)
	entity.controls.sensedMantleLeft = 0
	entity.controls.sensedMantleRight = 0
	entity.weapons = 
	{ 
		main = { type = 'knife', count = 3, }, 
	}
	
	entity.onContact['enemy'] = heroLib.onContactEnemy
	entity.onContact['grinder'] = heroLib.onContactGrinder
	
	level:addObject('entities',entity)
	return entity
end

return heroLib;