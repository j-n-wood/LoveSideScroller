require 'enemy'

imageLib.makeTiledSprite(enemyImages,"boss_1","boss_1.png","alpha",1.0,1.0,8,3,'bottom',true)

local boss_1 = 
{
	consts = 
	{
		walkDecelerateScale = 3.4,
		walkForce = 520.0,
	}
}

local boss_1_update = function(enemy, dt)
	if (enemy.controls.turnCooldown > 0.0) then
		enemy.controls.turnCooldown = enemy.controls.turnCooldown - dt	
	end	
end

local boss_1_commonControls = function(enemy)
	--TODO - move this?
	--local dx, dy = enemy.b:getLinearVelocity()
	--enemy.b:setLinearVelocity(math.clamp(dx,-200,200),math.clamp(dy,-500,500))
	local dx, dy = enemy.b:getLinearVelocity()
	enemy.b:applyForce(-dx * boss_1.consts.walkDecelerateScale,0)
end

local boss_1_selectWalkAnim = function(enemy)
	if (enemy.controls.direction < 0.0) then
		enemy:setState('walkLeft')
	else
		enemy:setState('walkRight')
	end
end

local boss_1_StandControls = function(enemy)
	boss_1_commonControls(enemy)
	if (math.random() > 0.7) then
		enemy:setState('attack')
		return false
	end
	if (enemy.controls.turnCooldown <= 0.0) then
		enemy.controls.turnCooldown = math.random() * 2.0 + 1.0
		if (math.random() > 0.5) then
			enemy.controls.direction = - 1.0	
		else
			enemy.controls.direction = 1.0			
		end
		boss_1_selectWalkAnim(enemy)
	end
	return false
end

local boss_1_AttackControls = function(enemy)
	boss_1_commonControls(enemy)	
	return false
end

local boss_1_WalkControls = function(enemy)
	boss_1_commonControls(enemy)
	
	if (enemy.controls.turnCooldown <= 0.0) then
		--reverse for a short time
		--or attack
		if (math.random() > 0.5) then
			enemy:setState('attack')
		else
			enemy.controls.direction = - enemy.controls.direction
			enemy.controls.turnCooldown = math.random() * 2.0 + 1.0
			boss_1_selectWalkAnim(enemy)
		end
		return true
	end
	
	--4,9,1
	--TEsound.play(soundCache.soundSets.bossWalk)
	
	enemy.b:applyForce(enemy.controls.direction * enemy.walkForce, 0)	
	return false
end

local boss_1_walk = function( enemy )
	TEsound.play(soundCache.soundSets.bossWalk)
end

local boss_1_walkEvents = 
{ 
	[4] = boss_1_walk, 
	[9] = boss_1_walk,
}

local boss_1_attackEvents = 
{ 
	[15] = function( enemy )
		TEsound.play(soundCache.boss_shoot_1)
	end,
	[17] = function( enemy )
		app.playerLevel:spawnEnemyThrown( enemy, -520.0, 250.0, entityLib.consts.enemyShotCategory )
		app.playerLevel:spawnEnemyThrown( enemy, -540.0, 270.0, entityLib.consts.enemyShotCategory )
		app.playerLevel:spawnEnemyThrown( enemy, -560.0, 290.0, entityLib.consts.enemyShotCategory )
	end
}

local boss_1_States =
	{		
		stand = { frameStart = 1, frameEnd = 1, sx = 1.0, controls = boss_1_StandControls, },
		attack = { frameStart = 12, frameEnd = 18, sx = 1.0, controls = boss_1_AttackControls, nextState = 'stand', events = boss_1_attackEvents, },
		walkRight = { frameStart = 11, frameEnd = 2, sx = 1.0, loop = true, controls = boss_1_WalkControls, events = boss_1_walkEvents, },
		walkLeft = { frameStart = 2, frameEnd = 11, sx = 1.0, loop = true, controls = boss_1_WalkControls, events = boss_1_walkEvents, },		
	}

enemyLib.makeBoss_1 = function(level,x,y)
	local entity = newEntity(x,y,'enemy')
	entity.life = 100
	entity.walkForce = boss_1.consts.walkForce
	imageLib.addRenderableSprite(entity.renderables,enemyImages["boss_1"],1.0,1.0)
	entity.states = boss_1_States
	--entity.setState = setState
	entity.setState(entity,'walkLeft')
	entity.controls = { jumpCooldown = 0, sensedGround = 0, walkCooldown = 0, turnCooldown = 0, direction = -1.0, }
	entity.onDeath = enemyLib.defaultDeath
	entity.update = boss_1_update
	
	level:addWalkerToEntity(60,60,entity)
	entity.f:setMask(2)	--not items
	level:addObject('entities',entity)
			
	entity.onContact['shot'] = enemyLib.onContactShot
	return entity
end