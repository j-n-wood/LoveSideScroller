require 'entity'
require 'imageLib'
require 'extraMath'
require 'explosion'

enemyLib = {}
enemyImages = {}
enemyLib.weapons = {}

function onShotContactOpposition( shot, other, begin )	
	shot.alive = false	
end

function onShotContactWorld( shot, other, begin )	
	shot.alive = false	
end

--shot spawn fns
enemyLib.weapons.bolt = function( enemy, dx, dy, vx, vy )
	local biff = newEntity(enemy.x + dx,enemy.y + dy,'enemyShot')	
	biff.onContact['hero'] = onShotContactOpposition
	biff.onContact['world'] = onShotContactWorld
	imageLib.addRenderableSprite(biff.renderables,heroImages["common"],1.0,1.0,48)
	app.playerLevel:addSphereToEntity(8,biff)
	app.playerLevel:addObject('shots',biff)
	biff.b:setLinearVelocity(vx,vy)
	biff.b:setAngularVelocity(10)
	biff.b:setGravityScale(0.0)	--these float
	biff.f:setDensity(0.1)
	biff.f:setCategory(entityLib.consts.enemyShotCategory)
	biff.f:setMask(entityLib.consts.enemyShotCategory)
	biff.f:setMask(entityLib.consts.enemyCategory)
	biff.f:setRestitution(0.2)
	local shotResponse = {}
	shotResponse.entity = biff
	shotResponse.onContact = bodyContact
	biff.f:setUserData( shotResponse )
	biff.onExpire = shotExpire
	biff.life = 5 --damage
	biff.lifeTime = 3.0	
	
	return biff
end

enemyLib.weapons.bouncingFireball = function( enemy, dx, dy, vx, vy )
	local biff = newEntity(enemy.x + dx,enemy.y + dy,'enemyShot')
	biff.onContact['hero'] = onShotContactOpposition
	imageLib.addRenderableSprite(biff.renderables,heroImages["common"],1.0,1.0,48)
	app.playerLevel:addSphereToEntity(8,biff)
	app.playerLevel:addObject('shots',biff)
	biff.b:setLinearVelocity(vx,vy)
	biff.b:setAngularVelocity(10)
	biff.f:setDensity(0.1)
	biff.f:setCategory(entityLib.consts.enemyShotCategory)
	biff.f:setMask(entityLib.consts.enemyShotCategory)
	biff.f:setMask(entityLib.consts.enemyCategory)
	biff.f:setRestitution(1.0)
	biff.f:setUserData( {entity = biff,} )
	biff.onExpire = shotExpire
	biff.life = 7 --damage
	biff.lifeTime = 3.0
	
	return biff
end

imageLib.makeTiledSprite(enemyImages,"enemy_0","enemy_0.png","alpha",1.0,1.0,8,8,'bottom',true)

enemyLib.defaultDeath = function(enemy)
	--print('explode ',enemy.x,enemy.y)
	enemy.level:spawnEffect('explosion',enemy.x + 32,enemy.y - 32)
	TEsound.play({soundCache['explosion_ground_1'],soundCache['explosion_ground_2']})
	enemy.b:destroy()
end

enemyLib.enemy0Update = function(enemy, dt)
	if (enemy.controls.turnCooldown > 0.0) then
		enemy.controls.turnCooldown = enemy.controls.turnCooldown - dt
	end
	
	if (enemy.shotType) then
		if (enemy.controls.shootCooldown > 0.0) then
			enemy.controls.shootCooldown = enemy.controls.shootCooldown - dt
		end
		
		if (enemy.controls.shootCooldown <= 0.0) then
			--spawn shot
			print('SHOOT')
			local weaponFunc = enemyLib.weapons[enemy.shotType]
			if (weaponFunc) then
				weaponFunc(enemy,0,-48,enemy.state.sx * 320,0.0)
			end
			enemy.controls.shootCooldown = 3.2
		end
	end
end

enemyLib.enemy0DefaultControls = function(enemy)

	--TODO - move this?
	local dx, dy = enemy.b:getLinearVelocity()
	enemy.b:setLinearVelocity(math.clamp(dx,-200,200),math.clamp(dy,-500,500))
	
	if (enemy.controls.walkCooldown > 0.0) then
		--walkCooldown
	end
	
	--doing something uninterruptable	
	if (enemy.state.falling) then		
		if (enemy.controls.sensedGround > 0) then
			--print("landed")
			if (enemy.state.sx == 1.0) then
				enemy.setState(enemy,'standRight')
			else
				enemy.setState(enemy,'standLeft')
			end	
			return true
		end
	else
		--check for falling		
		if (dy > 50) then
			--print("falling")
			if (enemy.state.sx == 1.0) then
				enemy.setState(enemy,'fallRight')
			else
				enemy.setState(enemy,'fallLeft')
			end
			return true
		end
	end
	return false
end

enemyLib.enemy0StandControls = function(enemy)
	if (enemyLib.enemy0DefaultControls(enemy)) then
		return true
	end
	
	--start walking
	--print("walking")
	if (enemy.state.sx == 1.0) then
		enemy.setState(enemy,'walkRight')
	else
		enemy.setState(enemy,'walkLeft')
	end
	
	return true
end

enemyLib.enemy0WalkControls = function(enemy)
	if (enemyLib.enemy0DefaultControls(enemy)) then
		return true
	end
	
	--crappy blocking test
	--if not making progress in positive direction, turn around
	local dx, dy = enemy.b:getLinearVelocity()
	if ((dx * enemy.state.sx) <= 0.0) and (enemy.controls.turnCooldown <= 0.0) then
		--print("turning")
		enemy.controls.turnCooldown = enemyLib.enemy0TurnCooldown
		if (enemy.state.sx == -1.0) then
			enemy.setState(enemy,'walkRight')
		else
			enemy.setState(enemy,'walkLeft')
		end
		return true
	end	
	
	--start walking
	enemy.b:applyForce(enemy.state.sx * enemy.walkForce, 0)
	return true
end

enemyLib.onContactShot = function(thisEntity, otherEntity, begin)
	--print('entity ',otherEntity.type, ' hit ', thisEntity.type)
	if (begin) then
		thisEntity.takeDamage(thisEntity,2)	
	end
end

enemyLib.enemy_0_States =
	{		
		standRight = { frameStart = 1, frameEnd = 1, sx = 1.0, controls = enemyLib.enemy0StandControls,},
		standLeft = { frameStart = 1, frameEnd = 1, sx = -1.0, controls = enemyLib.enemy0StandControls,},	
		walkRight = { frameStart = 1, frameEnd = 8, sx = 1.0, loop = true, controls = enemyLib.enemy0WalkControls, },
		walkLeft = { frameStart = 1, frameEnd = 8, sx = -1.0, loop = true, controls = enemyLib.enemy0WalkControls, },
		jumpRight = { frameStart = 9, frameEnd = 9, sx = 1.0, controls = enemyLib.enemy0DefaultControls, },
		jumpLeft = { frameStart = 9, frameEnd = 9, sx = -1.0, controls = enemyLib.enemy0DefaultControls, },
		fallRight = { frameStart = 9, frameEnd = 9, sx = 1.0, controls = enemyLib.enemy0DefaultControls, falling = true, },
		fallLeft = { frameStart = 9, frameEnd = 9, sx = -1.0, controls = enemyLib.enemy0DefaultControls, falling = true, },		
	}

enemyLib.enemy_1_States =
	{		
		standRight = { frameStart = 17, frameEnd = 17, sx = 1.0, controls = enemyLib.enemy0StandControls,},
		standLeft = { frameStart = 17, frameEnd = 17, sx = -1.0, controls = enemyLib.enemy0StandControls,},	
		walkRight = { frameStart = 17, frameEnd = 24, sx = 1.0, loop = true, controls = enemyLib.enemy0WalkControls, },
		walkLeft = { frameStart = 17, frameEnd = 24, sx = -1.0, loop = true, controls = enemyLib.enemy0WalkControls, },
		jumpRight = { frameStart = 16, frameEnd = 16, sx = 1.0, controls = enemyLib.enemy0DefaultControls, },
		jumpLeft = { frameStart = 16, frameEnd = 16, sx = -1.0, controls = enemyLib.enemy0DefaultControls, },
		fallRight = { frameStart = 16, frameEnd = 16, sx = 1.0, controls = enemyLib.enemy0DefaultControls, falling = true, },
		fallLeft = { frameStart = 16, frameEnd = 16, sx = -1.0, controls = enemyLib.enemy0DefaultControls, falling = true, },		
	}
	
enemyLib.enemy_2_States =
	{		
		standRight = { frameStart = 25, frameEnd = 25, sx = 1.0, controls = enemyLib.enemy0StandControls,},
		standLeft = { frameStart = 25, frameEnd = 25, sx = -1.0, controls = enemyLib.enemy0StandControls,},	
		walkRight = { frameStart = 25, frameEnd = 32, sx = 1.0, loop = true, controls = enemyLib.enemy0WalkControls, },
		walkLeft = { frameStart = 25, frameEnd = 32, sx = -1.0, loop = true, controls = enemyLib.enemy0WalkControls, },
		jumpRight = { frameStart = 33, frameEnd = 33, sx = 1.0, controls = enemyLib.enemy0DefaultControls, },
		jumpLeft = { frameStart = 33, frameEnd = 33, sx = -1.0, controls = enemyLib.enemy0DefaultControls, },
		fallRight = { frameStart = 33, frameEnd = 33, sx = 1.0, controls = enemyLib.enemy0DefaultControls, falling = true, },
		fallLeft = { frameStart = 33, frameEnd = 33, sx = -1.0, controls = enemyLib.enemy0DefaultControls, falling = true, },		
	}
	
enemyLib.flapperControls = function(enemy)
	
	--crappy blocking test
	--if not making progress in positive direction, turn around
	local dx, dy = enemy.b:getLinearVelocity()
	
	enemy.b:setLinearVelocity(math.clamp(dx,-200,200),math.clamp(dy,-500,500))

	if ((dx * enemy.state.sx) <= 0.0) and (enemy.controls.turnCooldown <= 0.0) then
		--print("turning")
		enemy.controls.turnCooldown = enemyLib.enemy0TurnCooldown
		if (enemy.state.sx == -1.0) then
			enemy.setState(enemy,'flapRight')
		else
			enemy.setState(enemy,'flapLeft')
		end
		return true
	end	

	--start walking
	enemy.b:applyForce(enemy.state.sx * enemy.walkForce, 0.0)
	return true
end	
	
enemyLib.enemy_3_States =
	{		
		flapRight = { frameStart = 10, frameEnd = 12, sx = 1.0, loop = true, gravity = 0.0, controls = enemyLib.flapperControls,},
		flapLeft = { frameStart = 10, frameEnd = 12, sx = -1.0, loop = true, gravity = 0.0, controls = enemyLib.flapperControls,},	
	}	
	
enemyLib.enemy0TurnCooldown = 0.7

enemyLib.makeWalkerEnemy = function(level,x,y,states)
	local entity = newEntity(x,y,'enemy')
	entity.life = 5
	entity.walkForce = 400
	entity.shotType = nil	--explicit
	imageLib.addRenderableSprite(entity.renderables,enemyImages["enemy_0"],1.0,1.0)
	entity.states = states
	--entity.setState = setState
	entity.setState(entity,'walkRight')
	entity.controls = { jumpCooldown = 0, sensedGround = 0, walkCooldown = 0, turnCooldown = 0, shootCooldown = 0, }
	entity.onDeath = enemyLib.defaultDeath
	entity.update = enemyLib.enemy0Update
	level:addWalkerToEntity(60,60,entity)
	entity.f:setMask(2)	--not items
	entity.f:setCategory(entityLib.consts.enemyCategory)
	level:addObject('entities',entity)
	entity.onContact['shot'] = enemyLib.onContactShot
	return entity
end

enemyLib.makeFlapperEnemy = function(level,x,y,states)
	local entity = newEntity(x,y,'enemy')
	entity.life = 5
	entity.walkForce = 400
	imageLib.addRenderableSprite(entity.renderables,enemyImages["enemy_0"],1.0,1.0)
	entity.states = states
	--entity.setState = setState
	entity.setState(entity,'flapRight')
	entity.controls = { turnCooldown = 0, }
	entity.onDeath = enemyLib.defaultDeath
	entity.update = enemyLib.enemy0Update
	level:addFlyerToEntity(64,64,entity)
	entity.f:setCategory(entityLib.consts.enemyCategory)
	level:addObject('entities',entity)
	entity.onContact['shot'] = enemyLib.onContactShot
	return entity
end
	
enemyLib.makeEnemy_0 = function(level,x,y)	
	return enemyLib.makeWalkerEnemy(level,x,y,enemyLib.enemy_0_States)
end

enemyLib.makeEnemy_1 = function(level,x,y)
	return enemyLib.makeWalkerEnemy(level,x,y,enemyLib.enemy_1_States)
end

enemyLib.makeEnemy_2 = function(level,x,y)
	return enemyLib.makeWalkerEnemy(level,x,y,enemyLib.enemy_2_States)
end

enemyLib.makeEnemy_3 = function(level,x,y)
	return enemyLib.makeFlapperEnemy(level,x,y,enemyLib.enemy_3_States)
end

return enemyLib
