require 'imageLib'
require 'extraMath'
require 'explosion'
require 'tileLib'
require 'teSound'
require 'class'
require 'hero'
require 'enemy'
require 'traps'

--TODO
--reset state
--remove left/right control state variants
--more object type factory stuff
--make solid sensors (ground, mantle) only pick up climbables
--consts for object categories
--move actions to object / entities so can call generically
--make enemies reference map objects?
--flight/ walk paths
--shooting enemies

app = { }
game = {}
effectImages = {}

soundCache = require 'sounds'
objectTypes = require('objectTypes')

--test - move to app or game
local function debugWorldDraw(world)
	love.graphics.setBlendMode("alpha")
	
   local bodies = world:getBodyList()
   
   for b=#bodies,1,-1 do
      local body = bodies[b]
      local bx,by = body:getPosition()
      local bodyAngle = body:getAngle()
      love.graphics.push()
      love.graphics.translate(bx,by)
      love.graphics.rotate(bodyAngle)
      
      math.randomseed(1) --for color generation
      
      local fixtures = body:getFixtureList()
      for i=1,#fixtures do
         local fixture = fixtures[i]
         local shape = fixture:getShape()
         local shapeType = shape:getType()
         local isSensor = fixture:isSensor()
         
         if (isSensor) then
            love.graphics.setColor(0,0,255,96)
         else
            love.graphics.setColor(math.random(32,200),math.random(32,200),math.random(32,200),96)
         end
         
         love.graphics.setLineWidth(1)
         if (shapeType == "circle") then
            local x,y = fixture:getMassData() --0.9.0 missing circleshape:getPoint()
            --local x,y = shape:getPoint() --0.9.1
            local radius = shape:getRadius()
            love.graphics.circle("fill",x,y,radius,15)
            love.graphics.setColor(0,0,0,96)
            love.graphics.circle("line",x,y,radius,15)
            local eyeRadius = radius/4
            love.graphics.setColor(0,0,0,96)
            love.graphics.circle("fill",x+radius-eyeRadius,y,eyeRadius,10)
         elseif (shapeType == "polygon") then
            local points = {shape:getPoints()}
            love.graphics.polygon("fill",points)
            love.graphics.setColor(0,0,0,96)
            love.graphics.polygon("line",points)
         elseif (shapeType == "edge") then
            love.graphics.setColor(0,0,0,96)
            love.graphics.line(shape:getPoints())
         elseif (shapeType == "chain") then
            love.graphics.setColor(0,0,0,96)
            love.graphics.line(shape:getPoints())
         end
      end
      love.graphics.pop()
   end
   --[[
   local joints = world:getJointList()
   for index,joint in pairs(joints) do
      love.graphics.setColor(0,255,0,255)
      local x1,y1,x2,y2 = joint:getAnchors()
      if (x1 and x2) then
         love.graphics.setLineWidth(3)
         love.graphics.line(x1,y1,x2,y2)
      else
         love.graphics.setPointSize(3)
         if (x1) then
            love.graphics.point(x1,y1)
         end
         if (x2) then
            love.graphics.point(x2,y2)
         end
      end
   end
   
   local contacts = world:getContactList()
   for i=1,#contacts do
      love.graphics.setColor(255,0,0,255)
      love.graphics.setPointSize(3)
      local x1,y1,x2,y2 = contacts[i]:getPositions()
      if (x1) then
         love.graphics.point(x1,y1)
      end
      if (x2) then
         love.graphics.point(x2,y2)
      end
   end
   ]]--
end

function app:init()
	self.pause = false
	self.mouse = {} --cache
	self.levels = {}
	self.screenWidth = love.graphics.getWidth()
	self.screenHeight = love.graphics.getHeight()
	self.halfWidth = self.screenWidth / 2
	self.halfHeight = self.screenHeight / 2
	
	self.gui = {}
	self.gui.healthCup = 
	{ 
		healthQuad = love.graphics.newQuad( 0, 48, 48, 48, 512, 512 ),
		healthQuadMinus = love.graphics.newQuad( 192, 48, 48, 48, 512, 512 ),
		healthFrame = 0,
	}
	
	imageLib.makeSprite(effectImages,"smiley","effects/smiley.png","additive",0.25,0.25)
	imageLib.makeSprite(effectImages,"cyl","greyCyl1.png","alpha",0.25,0.25)
	
	app.player = {}
end

function app:loadLevel(inFileName)
	local level = {}
	setmetatable(level, {__index = game})
	level:init()
	level:load(inFileName)
	self.levels[inFileName] = level	
	return level
end

-- Adds a static box.
function game:addbox(x, y)
	local t = {}
	t.b = self.ground
	t.s = love.physics.newRectangleShape(x, y, 64, 32)
	t.f = love.physics.newFixture(t.b, t.s)
	table.insert(self.boxes, t)
	return t;
end

function pointInBounds(x,y,bounds)
	if (x < bounds.left) then return false end
	if (x > bounds.right) then return false end
	if (y < bounds.top) then return false end
	if (y > bounds.bottom) then return false end
	return true;
end

--can draw tiles via
--tile = map.tiles[ self.tileData[h][w] ]
--image = tile.tileset.image
--quad = tile.quad
--or tile:draw(drawX+halfW, drawY-halfH, 0, flipX, flipY, halfW, halfH)

function game:addSphereToEntity(radius, entity)
	entity.b = love.physics.newBody(self.world, entity.x, entity.y, "dynamic")
	entity.s = love.physics.newCircleShape(radius)
	entity.f = love.physics.newFixture(entity.b, entity.s)
	--test
	entity.f:setRestitution(0.6)	
end

function groundContact(begin, thisFixture, otherFixture, contact)
	local thisResponse = thisFixture:getUserData()
	local otherResponse = otherFixture:getUserData()
	--is this a walker?
	local thisEntity = thisResponse.entity
	--is other solid?
	local solid = (otherResponse == nil)
	if otherResponse and otherResponse.entity and (otherResponse.entity.type ~= 'hero') then
		solid = true
	end
	if (solid) then
		if (begin) then
			thisEntity.controls.sensedGround = thisEntity.controls.sensedGround + 1
		else
			thisEntity.controls.sensedGround = thisEntity.controls.sensedGround - 1
		end
		--print('contact ', begin)
	end
end

function mantleContact(begin, thisFixture, otherFixture, contact)
	local thisResponse = thisFixture:getUserData()
	local otherResponse = otherFixture:getUserData()
	--is this a walker?
	local thisEntity = thisResponse.entity
	--is other solid?
	local solid = (otherResponse == nil)
	if otherResponse and otherResponse.entity and (otherResponse.entity.type ~= 'hero') then
		solid = true
	end
	if (solid) then		
		if (begin) then
			thisEntity.controls[thisResponse.target] = thisEntity.controls[thisResponse.target] + 1
		else
			thisEntity.controls[thisResponse.target] = thisEntity.controls[thisResponse.target] - 1
		end
		print('Mantle',thisResponse.target,thisEntity.controls[thisResponse.target])
	end
end

function entityToEntityContact(thisEntity,otherEntity,begin)
	local contactFunc = thisEntity.onContact[otherEntity.type]
	if (contactFunc) then
		contactFunc(thisEntity,otherEntity,begin)
	end
end

function bodyContact(begin, thisFixture, otherFixture, contact)
	local thisResponse = thisFixture:getUserData()
	local otherResponse = otherFixture:getUserData()
	
	--looks like we get one contact per pair
	--need to fire in both directions
	
	if (thisResponse.entity) and (thisResponse.entity.alive) then
	
		--make up some impulse from velocity
		if (otherFixture) then
			if (otherResponse) and (otherResponse.entity) and (otherResponse.entity.alive) then
				entityToEntityContact(thisResponse.entity,otherResponse.entity,begin)
				entityToEntityContact(otherResponse.entity,thisResponse.entity,begin)
				return
			end
			
			--kinetic collision damage
			local dx, dy = otherFixture:getBody():getLinearVelocity()		
			local len = math.sqrt(dx * dx + dy * dy)
			if (len > 50.0) then
				print ('BodyContact: ',len,'entity',thisResponse.entity.type)
				--dot it with relative direction
				local nx,ny = contact:getNormal()
				local ndx = dx / len
				local ndy = dy / len
				local dp = ndx * nx / 64.0 + ndy * ny / 64.0
				if (dp > 0.0001) then
					print('DP: ',dp, nx, ny)
					local mass = otherFixture:getBody():getMass()
					local ke = mass * len * len * 0.5
					print('KE: ', ke, mass)
					--dam = ke / 10000?
					thisResponse.entity.takeDamage(thisResponse.entity,0.00005 * ke)
					if (otherResponse) and (otherResponse.entity) then
						print('Other type:',otherResponse.entity.type)
						if (otherResponse.entity.alive) then
							otherResponse.entity.takeDamage(otherResponse.entity,0.00005 * ke)
						end
					else
						print('Other does not have response')
					end
				end
			end
		end
	end
end

function itemContact(begin, thisFixture, otherFixture, contact)
	local thisResponse = thisFixture:getUserData()
	local otherResponse = otherFixture:getUserData()
	
	if (not thisResponse.object.alive) then
		return
	end
	
	--looks like we get one contact per pair
	--need to fire in both directions
	
	--see if touched hero
	if (otherResponse) then
		if (otherResponse.entity) and (otherResponse.entity.alive) and (otherResponse.entity.type == 'hero') then
			print("Hero touched item")			
			if (string.len(thisResponse.object.name) > 0) then
				--otherResponse.entity.inventory[thisResponse.object.name] = thisResponse.object
				if (begin) then
					app.player.hero.controls.sensedItem = thisResponse.object
				else
					app.player.hero.controls.sensedItem = nil
				end
				print("Hero touched",thisResponse.object.name)
			else
				thisResponse.object.alive = false
			end
		end
	else
		--touched some static thing		
		local dx, dy = thisFixture:getBody():getLinearVelocity()
		if ((dy*dy) > 160.0) then
			print("Item touched world")
			TEsound.play(soundCache.soundSets.itemBounce)
		end
	end
end

function game:addGroundSensor(w,h,entity)
	entity.sensorShape = love.physics.newRectangleShape(0.0*w, -2, 0.5*w, 4)
	entity.sensorFixture = love.physics.newFixture(entity.b, entity.sensorShape)
	entity.sensorFixture:setSensor(true)
	sensorResponse = {}
	sensorResponse.entity = entity
	sensorResponse.onContact = groundContact
	entity.sensorFixture:setUserData(sensorResponse)
	return sensorResponse
end

function game:addMantleSensors(w,h,entity)
	entity.sensorShape = love.physics.newRectangleShape(-32.0, -24, 16, 12)
	entity.sensorFixture = love.physics.newFixture(entity.b, entity.sensorShape)
	entity.sensorFixture:setSensor(true)
	sensorResponse = {}
	sensorResponse.entity = entity
	sensorResponse.onContact = mantleContact
	sensorResponse.target = 'sensedMantleLeft'
	entity.sensorFixture:setUserData(sensorResponse)
	
	entity.sensorShape = love.physics.newRectangleShape(32.0, -24, 16.0, 12)
	entity.sensorFixture = love.physics.newFixture(entity.b, entity.sensorShape)
	entity.sensorFixture:setSensor(true)
	sensorResponse = {}
	sensorResponse.entity = entity
	sensorResponse.onContact = mantleContact
	sensorResponse.target = 'sensedMantleRight'
	entity.sensorFixture:setUserData(sensorResponse)	
	return sensorResponse
end

function game:addWalkerBody(r,entity)
	entity.s = love.physics.newCircleShape(0, -r, r)
	entity.f = love.physics.newFixture(entity.b, entity.s)
	entity.f:setRestitution(0.1)
	entity.f:setFriction(0.7)
	entity.f:setDensity(0.7)
	
	bodyResponse = {}
	bodyResponse.entity = entity
	bodyResponse.onContact = bodyContact
	entity.f:setUserData(bodyResponse)
	return bodyResponse
end

function game:addWalkerToEntity(w, h, entity)
	entity.b = love.physics.newBody(self.world, entity.x, entity.y, "dynamic")
	self:addWalkerBody(w/2,entity)
	entity.b:setFixedRotation(true)
	
	self:addGroundSensor(w,h,entity)
end

function game:addFlyerToEntity(w, h, entity)
	entity.b = love.physics.newBody(self.world, entity.x, entity.y, "dynamic")
	self:addWalkerBody(w/2,entity)
	entity.b:setFixedRotation(true)
	entity.b:setGravityScale(0.0)
end

function game:addBlock(inx, iny, spriteName)
	--test blocks
	local block = newEntity(inx,iny,'block')
	imageLib.addRenderableSprite(block.renderables,effectImages[spriteName],0.25,0.25)
	self:addObject("entities",block)
	block.b = love.physics.newBody(self.world, block.x, block.y, "dynamic")
	block.s = love.physics.newRectangleShape(0, 0, 32, 64)
	block.f = love.physics.newFixture(block.b, block.s)	
	block.f:setRestitution(0.0)
	block.f:setDensity(6.2)
	block.b:resetMassData()
	return block
end

function beginContact(a, b, coll)
   -- x,y = coll:getNormal()
   -- text = text.."\n"..a:getUserData().." colliding with "..b:getUserData().." with a vector normal of: "..x..", "..y
	local aentity = a:getUserData()
	local bentity = b:getUserData()
	
	if (aentity and aentity.onContact) then
		aentity.onContact(true,a,b,coll)
	end
	
	if (bentity and bentity.onContact) then
		bentity.onContact(true,b,a,coll)
	end	
end

function endContact(a, b, coll)
	local aentity = a:getUserData()
	local bentity = b:getUserData()
	
	if (aentity and aentity.onContact) then
		aentity.onContact(false,a,b,coll)
	end
	
	if (bentity and bentity.onContact) then
		bentity.onContact(false,b,a,coll)
	end	
end

function preSolve(a, b, coll)
end

function postSolve(a, b, coll)
end

function game:findEntity(class,name)
	local objectClass = self.objects[class]
	if objectClass then
		for idx, obj in pairs(objectClass) do
			if (obj.name and (obj.name == name)) then
				return obj
			end
		end
	end
	return nil
end

function game:init(inFileName)
	self.camera = { x = 0, y = 0 }
	self.objects = { entities = {}, shots = {}, pickups = {}, effects = {},  }		
	self.effects = {}
	self.boxes = {}
	self.items = {}	--handles to map items
	
	-- Create the world.
	love.physics.setMeter(64)
	self.world = love.physics.newWorld(0, 9.81*64, true)
	self.world:setCallbacks(beginContact, endContact, preSolve, postSolve)

	-- Create ground body.
	self.ground = love.physics.newBody(self.world, 0, 0, "static")			
	
	--self:addBlock(256,256,"cyl")
	--self:addBlock(256,320,"cyl")
	self:addBlock(256,384,"cyl")
	
	self:addBlock(420,56,"cyl")
	self:addBlock(500,20,"cyl")
	self:addBlock(380,84,"cyl")
	
	app.player.hero = heroLib.makeHero(self,1864,64)
	
end

function game:draw()
	tileLib.tx = app.halfWidth - app.player.hero.x
	tileLib.ty = app.halfHeight - app.player.hero.y
	self.level:draw()
	
	love.graphics.push()
	love.graphics.translate(app.halfWidth-app.player.hero.x, app.halfHeight-app.player.hero.y)

	for otype, list in pairs(self.objects) do		
		self.drawObjects(list)
	end	

	effects.draw(self.effects)
	
	-- Draw all the boxes.
	for i, v in ipairs(self.boxes) do
		love.graphics.polygon("line", v.s:getPoints())
	end
	
	--draw ladder indicators
	for idx, l in pairs(self.level.ladders) do
		love.graphics.polygon("line", {l.bounds.left, l.bounds.top, l.bounds.right, l.bounds.top, l.bounds.right, l.bounds.bottom, l.bounds.left, l.bounds.bottom} )
	end
	
	--debugWorldDraw(self.world)
	
	love.graphics.pop()
	
	--health cup
	--quads are arranged 1-4 + empty
	--adjust minus quad
	app.gui.healthCup.healthQuadMinus:setViewport(192,48,48,12+24*0.01*(100-app.player.hero.life))
	app.gui.healthCup.healthQuad:setViewport(math.floor(app.gui.healthCup.healthFrame) * 48,48,48,48)	
	love.graphics.drawq(heroImages["common"].image,app.gui.healthCup.healthQuad,0,0,0.0)
	love.graphics.drawq(heroImages["common"].image,app.gui.healthCup.healthQuadMinus,0,0,0.0) --over top so don't need to adjust health quad
		
	--[[
	local x = math.floor( 1+(app.player.hero.x / 32) )
	local y = math.floor(  1+(app.player.hero.y / 32) )
	local solid = app.player.hero.controls.sensedGround --self.level:solid(x,y)
	local sw = 'false'
	if (solid > 0) then sw = 'true' end	
	local msg = "x:" .. x .. " y:" .. y .. ' s:' .. sw
	love.graphics.print(msg, 10, 10)
	]]--
end

function game:mousepressed(x, y, button)

end

function app:changeLevel(levelName, x, y)
	app.playerLevel = app.levels[levelName]
	app.player.hero.x = x
	app.player.hero.y = y
end

function game:keypressed(key, unicode)

end

function shotExpire( shot )
	shot.expired = true
	shot.alive = false
	shot.f:destroy()
	shot.b:destroy()
	--print('end shot')
end

function onShotContactEnemy( shot, enemy )	
	shot.alive = false	
end

function game:spawnThrown( hero, vx, vy )
	local biff = newEntity(hero.x,hero.y - 40,'shot')
	biff.onContact['enemy'] = onShotContactEnemy
	imageLib.addRenderableSprite(biff.renderables,heroImages["common"],1.0,1.0,2)
	self:addSphereToEntity(8,biff)
	self:addObject('shots',biff)
	biff.b:setLinearVelocity(vx,vy)
	biff.b:setAngularVelocity(10)
	biff.f:setDensity(0.1)
	biff.f:setCategory(8)
	biff.f:setMask(8) -- shots + player
	biff.f:setMask(9)
	biff.f:setUserData( {entity = biff,} )
	biff.onExpire = shotExpire
	biff.lifeTime = 3.0
end

weaponTypes = 
{
	common = function( game, hero, vx, vy )
			local biff = newEntity(hero.x,hero.y - 40,'shot')
			biff.onContact['enemy'] = onShotContactEnemy
			game:addObject('shots',biff)
			biff.b = love.physics.newBody(game.world, biff.x, biff.y, "dynamic")
			biff.b:setLinearVelocity(vx,vy)
			biff.b:setAngularVelocity(10)			
			biff.onExpire = shotExpire
			biff.lifeTime = 3.0	
			return biff
		end,
	setFixtureProps = function( biff )
			biff.f:setCategory(8)
			biff.f:setMask(8) -- shots + player
			biff.f:setMask(9)
			biff.f:setUserData( {entity = biff,} )
			biff.f:setRestitution(0.6)
		end,
	knife = function( game, hero, vx, vy )
			local biff = weaponTypes.common( game, hero, vx, vy )
			imageLib.addRenderableSprite(biff.renderables,heroImages["common"],1.0,1.0,1)
			biff.s = love.physics.newCircleShape(8)
			biff.f = love.physics.newFixture(biff.b, biff.s, 0.1)
			weaponTypes.setFixtureProps( biff )
		end,
	mace = function( game, hero, vx, vy )
			local biff = weaponTypes.common( game, hero, vx, vy )
			imageLib.addRenderableSprite(biff.renderables,heroImages["common"],1.0,1.0,2)
			biff.s = love.physics.newCircleShape(8)
			biff.f = love.physics.newFixture(biff.b, biff.s, 0.1)
			weaponTypes.setFixtureProps( biff )
		end,		
}

heroNearObject = function( hero, obj )
	local ox = obj.x
	local oy = obj.y + obj.height
	local dx = (hero.x - ox)
	local dy = (oy-hero.y)
	--print(dx,dy,ox,oy,hero.x,hero.y)
	if (dx >= -32.0) and (dy >= 0) and (dx < obj.width + 64) and (dy < obj.height) then
		return true
	end
	return false
end

function doAction( target, dt )
	local props = target.properties
	if (not props.count) then
		props.count = 1
	end	
	--print (target.timer, props.count)
	if (props.count > 0) then
		if not target.timer then target.timer = 0.0 end		
		if (target.timer > 0.0) then
			target.timer = math.max(target.timer - dt, 0.0)
		else
			--print(target.type, target.name, props.action, target.properties.count, target.properties.delay, target.properties.spawnFunction)
			--TODO - use metatables to attach actions to objects
			--TODO - target could be an Entity, not an object in the map
			local actionSet = objectTypes[target.type] or target
			local action = actionSet.actions[props.action]			
			if action then
				print('found action')				
				action(target, target)
			end
			target.timer = (props.delay or 6.0)				
		end --timer
	end --count
end

function game:checkObjects( layer, hero, dt )
	local objectLevel = self.level.map.ol[layer]
	if (objectLevel) then
		for idx, obj in pairs(objectLevel.objects) do
			if obj.type == 'switch' then
				local ox = obj.x
				local oy = obj.y
				if (obj.gid) then
					ox = ox + self.level.map.tiles[obj.gid].width / 2					
				end
				--is it near?
				local dx = math.abs(hero.x - ox)
				local dy = (hero.y - oy)
				if (dx < 16.0) and (dy < 96) then
					--print('near',obj.name, dx, dy)
					hero.controls.sensedObject = obj
				end
			elseif obj.type == 'door' then
				--test for position
				--test for required key
				if (not obj.open) then
					--[[
					local ox = obj.x
					local oy = obj.y + obj.height
					local dx = (hero.x - ox)
					local dy = (oy-hero.y)
					--print(dx,dy,ox,oy,hero.x,hero.y)
					if (dx >= -32.0) and (dy >= 0) and (dx < obj.width + 64) and (dy < obj.height) then
						print('near',obj.name,'needs',obj.properties.key)
						if (hero.inventory[obj.properties.key]) then
							objectTypes['door'].actions.open(obj)
						end
					end
					]]--
					if (heroNearObject( hero, obj ) ) then
						if (hero.inventory[obj.properties.key]) then
							print('near',obj.name,'needs',obj.properties.key)
							objectTypes['door'].actions.open(obj)
						end
					end
				end
			elseif obj.type == 'trigger' then
				--rectangle trigger
				
				--how many times will it trigger?
				--start with just once
				local doTrigger = false
				if ( not obj.triggered ) then
					if ( heroNearObject( hero, obj ) ) then
						obj.triggered = true
						doTrigger = true
					end
				end
				
				if ( doTrigger ) then
					local target = self.level:findObject(obj.properties.targetClass or 'Switches',obj.properties.target)
					if target then
						if not target.active then
							target.active = true
						end
						doAction(target,dt)
					end --target found
				end -- near trigger
			else				
				--repeating triggers, spawners, etc
				if (obj.active and obj.properties.action) then
					doAction( obj, dt )
				end
			end
		end
	end
end

function game:updateControls(dt)
	local hero = app.player.hero
	
	if love.keyboard.isDown("escape") then
      love.event.push("quit")   -- actually causes the app to quit   
    end 
	
	if (hero.controls.jumpCooldown > 0) then
		hero.controls.jumpCooldown = math.max(hero.controls.jumpCooldown - dt, 0)
	end
	
	if (hero.controls.activateCooldown > 0) then
		hero.controls.activateCooldown = math.max(hero.controls.activateCooldown - dt, 0)
	end
		
	if (hero.controls.throwCooldown > 0) then
		hero.controls.throwCooldown = math.max(hero.controls.throwCooldown - dt, 0)
	end
	
	--update hero sensors manually
	--ladder
	hero.controls.sensedLadder = false
	for idx, l in pairs(self.level.ladders) do
		if (pointInBounds(hero.x,hero.y,l.bounds)) then
			hero.controls.sensedLadder = true
		end
	end
	
	hero.controls.sensedObject = nil
	
	--look for objects
	--perform possible physics-changing actions here
	self:checkObjects('Switches', hero, dt)
	self:checkObjects('Triggers', hero, dt)
	--[[
	local objectLevel = self.level.map.ol['Switches']
	if (objectLevel) then
		for idx, obj in pairs(objectLevel.objects) do
			if obj.type == 'switch' then
				local ox = obj.x
				local oy = obj.y
				if (obj.gid) then
					ox = ox + self.level.map.tiles[obj.gid].width / 2					
				end
				--is it near?
				local dx = math.abs(hero.x - ox)
				local dy = (hero.y - oy)
				if (dx < 16.0) and (dy < 96) then
					--print('near',obj.name, dx, dy)
					hero.controls.sensedObject = obj
				end
			elseif obj.type == 'door' then
				--test for position
				--test for required key
				if (not obj.open) then
					local ox = obj.x
					local oy = obj.y + obj.height
					local dx = (hero.x - ox)
					local dy = (oy-hero.y)
					--print(dx,dy,ox,oy,hero.x,hero.y)
					if (dx >= -32.0) and (dy >= 0) and (dx < obj.width + 64) and (dy < obj.height) then
						print('near',obj.name,'needs',obj.properties.key)
						if (hero.inventory[obj.properties.key]) then
							objectTypes['door'].actions.open(obj)
						end
					end
				end
			end
		end
	end
	]]--
	
	--grinder / environment damage
	if (hero.controls.sensedGrinder > 0) then
		--apply time damage
		local dam = dt * hero.controls.sensedGrinder
		hero:takeDamage(dam)
	end
	
	local dx, dy = hero.b:getLinearVelocity()
	
	--clamp velocity	
	--TODO - better to apply a restraining force prop to velocity*2
	--hero.b:setLinearVelocity(math.clamp(dx,-200,200),math.clamp(dy,-500,500))
	--hero.b:applyForce(-math.sign(dx) * (dx * dx) * xDamping,-dy * yDamping)
	--hero.b:applyForce(0.0,-dy * yDamping)
	if (hero.controls.sensedGround > 0) then
		hero.b:applyForce(-math.sign(dx) * (dx * dx) * 0.004, 0.0)
	else
		if (math.abs(dx) > 100.0) then
			hero.b:applyForce(-math.sign(dx) * (dx * dx) * 0.004, 0.0)
		end
	end
	
	--TODO - better callback/event here
	if (hero.controls.throw) then
		--[[
		self.spawnThrown( self, hero, 640 * hero.renderables[1].sx, -128 )
		self.spawnThrown( self, hero, 640 * hero.renderables[1].sx, -128 + 250 )
		self.spawnThrown( self, hero, 640 * hero.renderables[1].sx, -128 - 250 )
		]]--
		
		if (hero.weapons.main.type) then
			weaponTypes[hero.weapons.main.type](self, hero, 640 * hero.renderables[1].sx, -128)
			if (hero.weapons.main.count > 1) then
				weaponTypes[hero.weapons.main.type](self, hero, 640 * hero.renderables[1].sx, -128 + 250)
			end
			if (hero.weapons.main.count > 2) then
				weaponTypes[hero.weapons.main.type](self, hero, 640 * hero.renderables[1].sx, -128 - 250)
			end			
		end
		
		hero.controls.throw = nil
		TEsound.play(soundCache['weapon_throw'])
	end
end

function game:update(dt)
	app.mouse.x = love.mouse.getX()
	app.mouse.y = love.mouse.getY()
	
	--run simulation
	self.world:update(dt)
	--sim may populate control state
	
	--run user code
	for otype, list in pairs(self.objects) do
		self:updateObjects(list, dt)
	end
	
	self:updateItems(dt)
	effects.update(dt)
	self:updateControls(dt)
	
	app.gui.healthCup.healthFrame = math.clampModulo(app.gui.healthCup.healthFrame + dt * 10.0,0,3)	
end

function game:spawnEffect(inType, inX, inY)
	local effect = effects:spawn(inType, inX, inY)
	table.insert(self.effects,effect)
end

function findLadder(ladders, inx, iny)
	for idx, l in pairs(ladders) do
		if (l.x == inx) then
			--does it extend?
			if (iny == l.bottom + 1) then
				l.bottom = iny
				return l
			end
			if (iny == l.top-1) then
				l.top = iny
				return l
			end
		end
	end
	
	--not found
	local newLadder = { top = iny, bottom = iny, x = inx, }
	table.insert(ladders, newLadder)
	return newLadder
end

function game:makeItemFromObject(obj)
	if (obj) then
		print('Item',obj.type,'at',obj.x,obj.y)			
		local physObj = {} --self:addbox(object.x + theTile.width / 2,object.y - theTile.height / 2)
		physObj.b = love.physics.newBody(self.world, obj.x, obj.y, "dynamic")
		physObj.s = love.physics.newRectangleShape( 16, -16, 32, 32 )
		physObj.f = love.physics.newFixture(physObj.b, physObj.s, 0.3)
		physObj.f:setRestitution(0.7)
		physObj.f:setFriction(0.7)
		physObj.b:setFixedRotation(true)
		physObj.f:setCategory(2)	--2 -> item
		physObj.f:setMask(9)
		obj.physics = physObj
		obj.alive = true
		obj.visible = true
		bodyResponse = {}
		bodyResponse.object = obj
		bodyResponse.onContact = itemContact
		physObj.f:setUserData(bodyResponse)
		table.insert(self.items,obj)
	end
end

function game:load(inFileName)
	print("Load level file " .. inFileName)
	self.fileName = inFileName
	local newLevel = tileLib.loadLevel(inFileName)
	self.level = newLevel
	newLevel.map.draw_objects = false	--suppress wireframe objects	
	
	local solidBlocks = {}	
	function makeSolidBlocks(inx, iny, props)		
		findLadder(solidBlocks,inx,iny)
	end
	self.level:scan('solid',makeSolidBlocks)
	--make bodies
	local function addSolidBlock( block )
		local t = {}
		local x = block.x * 64 - 32
		local y = block.top * 32 - 16
		local h = (1 + block.bottom - block.top) * 32
		t.b = self.ground
		t.s = love.physics.newRectangleShape(x, y + h / 2 - 16, 64, h)
		t.f = love.physics.newFixture(t.b, t.s)
		table.insert(self.boxes, t)
		return t;
	end
	for idx, block in ipairs(solidBlocks) do addSolidBlock( block ) end
	
	--look for solid objects
	--for idx, layer in pairs(self.level.map.ol) do
	local olSwitches = self.level.map.ol['Switches']
	if (olSwitches) then
		print(olSwitches.name)
		for oidx, object in pairs(olSwitches.objects) do
			print(object.name, object.x, object.y, object.width, object.height)
			--local obj = Object:new(self, name, type, x, y, width, height, gid, prop)
			--q: do switches need physics?
			if (object.gid) then
				local theTile = self.level.map.tiles[object.gid]
				if (theTile.properties.solid) then
					print('Added solid object ',object.name)
					local physObj = {}
					physObj.b = love.physics.newBody(self.world, object.x + 32, object.y - 16, "kinematic")
					physObj.s = love.physics.newRectangleShape(0, 0, 64, 32)
					physObj.f = love.physics.newFixture(physObj.b, physObj.s)
					physObj.f:setCategory(4)
					object.physics = physObj
				end
			else
				object.visible = false
				if (object.properties.solid) then
					local physObj = {}
					physObj.b = love.physics.newBody(self.world, object.x + object.width / 2, object.y + object.height / 2, "static")
					physObj.s = love.physics.newRectangleShape(object.width, object.height)
					physObj.f = love.physics.newFixture(physObj.b, physObj.s)
					--physObj.f:setCategory(4)
					object.physics = physObj
				end
			end
		end
	end
	
	newLevel.ladders = {}	
	function makeLadder(inx, iny, props)
		print('Ladder at',inx,iny)
		--find a ladder with that x
		findLadder(newLevel.ladders,inx,iny)
	end
	self.level:scan('ladder',makeLadder)
	
	for idx, l in pairs(newLevel.ladders) do
		l.bounds = {}
		l.bounds.left = (l.x - 1) * 64 
		l.bounds.right = l.x * 64
		l.bounds.top = l.top * 32
		l.bounds.bottom = l.bottom * 32
	end
	
	function makeEnemy(obj)
		if (obj) and (not obj.delay) then
			print('Enemy at',obj.x,obj.y,obj.type)
			if (not enemyLib[obj.type]) then
				print('Unknown enemy type',obj.type)
				return
			end
			local newEnemy = enemyLib[obj.type](self,obj.x,obj.y)
			newEnemy.name = obj.name
			--set custom properties
			--maybe not use simple assignment, as cannot set function references this way
			--set 'special' props by name, then use simple assignment for other cases
			for name, value in pairs(obj.properties) do
				newEnemy[name] = value
			end
		end
	end	
	self.level:scanObjects('Enemies',makeEnemy)
	
	function makeItem(obj)
		self:makeItemFromObject(obj)
	end
	
	self.level:scanObjects('Items',makeItem)
end

function game:updateItems(dt)
	local last = #self.items
	for i=#self.items,1,-1 do
		--update tile object pos from physics
		local obj = self.items[i]
		obj:moveTo( obj.physics.b:getX(), obj.physics.b:getY())
		
		--remove dead items
		if (not obj.alive) then
			obj.physics.f:destroy()
			obj.physics.b:destroy()
			obj.visible = false
			table.remove(self.items,i)
		end
	end
end

game.addToList = function(item, list)
	for idx, s in pairs(list) do
		if (s.alive == false) then
			list[idx] = item
			return
		end
	end
	table.insert(list,item)
end

function game:addObject(otype, object)
	object.level = self
	game.addToList(object,self.objects[otype])
end

game.drawObject = function(d, inx, iny)	
	if (d.renderables) then
		for idx, r in pairs(d.renderables) do
			r.x = inx or d.x
			r.y = iny or d.y
			r.theta = d.theta
			r.colour = d.colour
			imageLib.drawSprite(r)
		end
	else
		imageLib.drawSprite(d)
	end
end

game.drawObjects = function(dlist)	
	for idx, d in pairs(dlist) do
		if (d.alive) then
			game.drawObject(d)
		end
	end
end

function game:updateObject(d, dt)
	if (not d.alive) then return end
	
	--time expiry
	if (d.lifeTime and (d.lifeTime > 0.0)) then
		d.lifeTime = d.lifeTime - dt
		if (d.onExpire and (d.lifeTime <= 0.0)) then
			d:onExpire()
			d.expired = true
		end
	end
	
	--may have expired
	if (not d.alive) then return end
	
	--generic update, not state-based
	if (d.update) then
		d:update(dt)
	end
	
	--state
	if (d.state) and (d.state.controls) then
		d.state.controls(d)
	end
	
	if (d.b) then	--simulation
		--TODO - interaction here
		d.x = d.b:getX()
		d.y = d.b:getY()
		d.theta = d.b:getAngle()
		return
	end
	
end

function game:updateObjects(dlist, dt)
	for idx, entity in pairs(dlist) do		
		entity:updateEntity(dt)
		self:updateObject(entity, dt)
		if (entity.alive == false) then
			if (entity.expired == false) and (entity.onExpire) then
				entity:onExpire()
				entity.expired = true
			end			
			dlist[idx] = nil
		end
	end
end

function love.load()
	-- Set the background color
	love.graphics.setBackgroundColor(0x00, 0x00, 0x07)
	love.graphics.setColor(255, 255, 255, 255)
	love.mouse.setGrab(true)
	
	app:init()
	local level = app:loadLevel("2.tmx")
	app.state = level
	app.playerLevel = app.state
end

function love.mousepressed(x, y, button)
	app.state:mousepressed(x,y,button)
end

function love.keypressed(key, unicode)
	app.state:keypressed(key, unicode)
	
   --Debug
	if key == "`" then --set to whatever key you want to use
		app.pause = true
		debug.debug()
		app.pause = false
	end
	
	if key == '3' then
		local hero = app.player.hero
		--if (hero and (#hero.inventory > 0)) then
			--drop
			for idx, item in pairs(hero.inventory) do
				print(item.name, hero.x, hero.y)
				item:moveTo( hero.x - 64.0, hero.y - 90.0 )
				app.state:makeItemFromObject(item)
			end
		--end
	end
	
	if (key == '4') then
		local hero = app.player.hero
		hero.weapons.main.type = 'mace'
	end
	if (key == '5') then
		local hero = app.player.hero
		hero.weapons.main.type = 'knife'
	end	
end

function love.draw()
	app.state:draw()
end

function love.update(dt)
	if (dt > 0.1) then dt = 0.1 end	--timestep limiter
	app.state:update(dt)
	TEsound.cleanup()
end
