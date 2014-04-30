-- Some global stuff that the examples use.
loader = require("AdvTiledLoader.Loader")
loader.path = "maps/"

tileLib = {}
tileLib.limitDrawing = false		-- If true then the drawing range example is shown
tileLib.useBatch = true			-- If true then the layers are rendered with sprite batches
tileLib.tx = 0					-- X translation of the screen
tileLib.ty = 0					-- Y translation of the screen
tileLib.scale = 1				-- Scale of the screen

function tileLib:solid(inx, iny)
	if (inx < 1) then return true end
	if (iny < 1) then return true end
	
	local layer = self.map.tl['Floor']
	if (layer) then
		if layer.tileData[iny] then
			local tileID = layer.tileData[iny][inx]
			if (tileID == 0) then return false end
			local tile = self.map.tiles[layer.tileData[iny][inx]]
			if tile.properties.solid then return true end
		end
	end
	return false
end

function tileLib:scanCommands(layerName,fn)
	local	commands = {}
	local layer = self.map.tl[layerName]
	if (layer) then
		local y = 1
		while (layer.tileData[y]) do
			local row = layer.tileData[y]
			local x = 1
			while (row[x]) do
				local tileID = row[x]
				if (tileID > 0) then
					local tile = self.map.tiles[tileID]
					if tile.properties.spawn then
						local command = {cx = x,cy = y,spawn = tile.properties.spawn}
						table.insert(commands,command)
					end
				end
				x = x + 1
			end
			y = y + 1
		end
	end
	return commands
end

function tileLib:scanObjects(layerName,fn)
	local	commands = {}
	local layer = self.map.ol[layerName]
	if (layer) then
		for idx, obj in pairs(layer.objects) do
			fn(obj)
		end
	end
end

function tileLib:scanSolids(fn)
	local	commands = {}
	--local layer = self.map.tl['Floor']
	for idx, layer in pairs(self.map.tl) do
		local y = 1
		while (layer.tileData[y]) do
			local row = layer.tileData[y]
			local x = 1
			while (row[x]) do
				local tileID = row[x]				
				if (tileID > 0) then
					local tile = self.map.tiles[tileID]
					if tile.properties.solid then
						--print("Solid tile at " .. x .. "," .. y)
						fn(x,y,tile.properties)
					end
				end
				x = x + 1
			end
			y = y + 1
		end
	end
	return commands
end

-- Called from love.draw()
function tileLib:draw()

	-- Set sprite batches
	self.map.useSpriteBatch = tileLib.useBatch

	-- Scale and translate the game screen for map drawing
	local ftx, fty = math.floor(tileLib.tx), math.floor(tileLib.ty)
	love.graphics.push()
	love.graphics.scale(tileLib.scale)
	love.graphics.translate(ftx, fty)
	
	-- Limit the draw range 
	if tileLib.limitDrawing then 
		self.map:autoDrawRange(ftx, fty, tileLib.scale, -100) 
	else 
		self.map:autoDrawRange(ftx, fty, tileLib.scale, 50) 
	end
	
	-- Draw the map and the outline of the drawing area. If benchmark is checked then it draws 20 times.
	self.map:draw()	
	love.graphics.rectangle("line", self.map:getDrawRange())
	
	-- Reset the scale and translation.
	love.graphics.pop()
end

-- Resets the example
function tileLib.reset()
	tileLib.tx = 0
	tileLib.ty = 0
end

function tileLib:findObject(layer,name)
	local theLayer = self.map.ol[layer]
	if (theLayer) then
		--print('found switches')
		for idx, obj in pairs(theLayer.objects) do
			if obj.name == name then
				--print('found switch')
				return obj
				--print(sw1.properties.Target,sw1.properties.Action)
			end
		end
	end
	return nil
end

function tileLib:scan(key,fn)
	for idx, layer in pairs(self.map.tl) do
		local y = 1
		while (layer.tileData[y]) do
			local row = layer.tileData[y]
			local x = 1
			while (row[x]) do
				local tileID = row[x]				
				if (tileID > 0) then
					local tile = self.map.tiles[tileID]
					if tile.properties[key] then
						print("Key found on tile at " .. x .. "," .. y)
						fn(x,y,tile.properties)
					end
				end
				x = x + 1
			end
			y = y + 1
		end
	end
	return commands
end

-- Load the examples
function tileLib.loadLevel( file )
	--TODO - set metaTable
	local level = { map = loader.load(file), } -- reset = tileLib.reset, solid=tileLib.solid, draw=tileLib.draw, scan = tileLib.scan, findObject = tileLib.findObject, scanCommands=tileLib.scanCommands, scanSolids=tileLib.scanSolids } --"test2.tmx"	
	setmetatable(level, {__index = tileLib})
	level:reset()
	return level
end

-- Scroll in and out
--[[
function love.mousepressed( x, y, mb )
	if mb == "wu" then
		tileLib.scale = tileLib.scale + 0.2
	end

	if mb == "wd" then
		tileLib.scale = tileLib.scale - 0.2
	end
end
]]--
--[[
function tileLib:update(dt)
	-- Move the camera
	if love.keyboard.isDown("up") then tileLib.ty = tileLib.ty + 250*dt end
	if love.keyboard.isDown("down") then tileLib.ty = tileLib.ty - 250*dt end
	if love.keyboard.isDown("left") then tileLib.tx = tileLib.tx + 250*dt end
	if love.keyboard.isDown("right") then tileLib.tx = tileLib.tx - 250*dt end
	
	-- Call update in our example if it is defined
	--if level.update then level:update(dt) end
end
]]--
--[[
function love.keypressed(k)
	-- quit
    if k == 'escape' then
        love.event.push('q')
    end
	
	-- limit drawing
	if k == 'c' then
		if tileLib.limitDrawing then tileLib.limitDrawing = false else tileLib.limitDrawing = true end
	end
	
	-- use sprite batches
	if k == 'b' then
		if tileLib.useBatch then tileLib.useBatch = false else tileLib.useBatch = true end
	end

end
]]--

--[[
function love.draw()

	-- Draw our example
	level:draw()
	
	information = {string.format("(%d,%d)", -tileLib.tx, -tileLib.ty), 
					"Scale: " .. tileLib.scale,  
					tileLib.limitDrawing and "Limiting drawing" or "Drawing entire screen",
				    string.format("Drawing %d time(s). FPS: %d", 1, fps), 
					tileLib.useBatch and "Using SpriteBatches" or "Not Using SpriteBatches"}
	
	-- Draw a box so we can see the text easier
	love.graphics.setColor(0,0,0,100)
	love.graphics.rectangle("fill",0,0,350,120)
	love.graphics.setColor(255,255,255,255)
	
	-- print display text
	for i=1,#instructions do
		love.graphics.print(instructions[i], 0, (i-1)*20)
	end
	for i=1,#information do
		love.graphics.print(information[i], 160, (i-1)*20)
	end

end
]]--