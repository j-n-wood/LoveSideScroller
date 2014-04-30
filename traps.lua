require 'enemy'

local trapQuads = 
		{
			{ x = 0, y = 0, w = 32, h = 64, },
			{ x = 32, y = 0, w = 32, h = 64, },
			{ x = 64, y = 0, w = 32, h = 64, },
			{ x = 96, y = 0, w = 32, h = 64, },	--grinder		
		}
imageLib.makeSpriteSheet(enemyImages,"traps","traps.png","alpha",true,trapQuads)

enemyLib.grinderControls = function(enemy)
	return true
end	

enemyLib.grinderStates =
	{		
		grind = { frameStart = 1, frameEnd = 4, sx = 1.0, loop = true, gravity = 0.0, controls = enemyLib.grinderControls,},
		gridUpAndDown = { frameStart = 1, frameEnd = 4, sx = -1.0, loop = true, gravity = 0.0, controls = enemyLib.grinderControls,},	
	}
	
enemyLib.makeGrinder = function( level, x, y, states )
	local entity = newEntity(x,y,'grinder')
	entity.life = 128	
	imageLib.addRenderableSprite(entity.renderables,enemyImages["traps"],1.0,1.0,1)
	entity.states = states
	entity.setState(entity,'grind')
	entity.controls = { }
	entity.onDeath = enemyLib.defaultDeath
	entity.update = nil
	
	--physics
	entity.b = love.physics.newBody(level.world, entity.x, entity.y, "kinematic")
	entity.s = love.physics.newRectangleShape(0, 0, 32, 64)
	entity.f = love.physics.newFixture(entity.b, entity.s)
	entity.f:setSensor(true)
	
	bodyResponse = {}
	bodyResponse.entity = entity
	bodyResponse.onContact = bodyContact
	entity.f:setUserData(bodyResponse)
	
	level:addObject('entities',entity)
	entity.onContact['shot'] = nil
		
	return entity
end

enemyLib.grinder_0 = function(level,x,y)	
	return enemyLib.makeGrinder(level,x,y,enemyLib.grinderStates)
end