--sprite type
--default values for image, blendMode, scale, offset
imageLib = {}

imageLib.loadImageWithTrans = function(fileName)
	function maskMagenta( x, y, r, g, b, a )
		if (r > 253) and (g < 2) and (b > 253) then
			return 0,0,0,0
		end
		return r,g,b,a
	end

	local source = love.image.newImageData(fileName)
	source:mapPixel( maskMagenta )
	return love.graphics.newImage(source)
end

imageLib.makeSprite = function(target, name, fileName, inmode, insx, insy, mask)
	local sprite = { sx = insx or 1.0, sy = insy or 1.0,}
	sprite.name = name
	if (mask) then
		sprite.image = imageLib.loadImageWithTrans(fileName)
	else
		sprite.image = love.graphics.newImage(fileName)
	end
	sprite.ox = sprite.image:getWidth() / 2
	sprite.oy = sprite.image:getHeight() / 2
	if (inmode) then
		sprite.blendMode = inmode
	end
	target[name] = sprite
	return sprite
end

imageLib.makeTiledSprite = function(target, name, fileName, inmode, insx, insy, tx, ty, hotspot, trans)
	local sprite = imageLib.makeSprite(target, name, fileName, inmode, insx, insy, trans)
	sprite.quads = {}
	--TODO - ty
	local iw = sprite.image:getWidth()
	local ih = sprite.image:getHeight()
	local tw = iw / tx
	local th = math.floor(ih / ty)
	if (hotspot == nil) then
		sprite.ox = tw / 2
		sprite.oy = th / 2
	end 
	if (hotspot == 'bottom') then
		sprite.ox = tw / 2
		sprite.oy = th
	end
	
	local	topy = 0
	for yidx = 1, ty do
		for idx=1,tx do
			local q = love.graphics.newQuad((idx-1) * tw, topy, tw, th, iw, ih)
			table.insert(sprite.quads,q)		
		end
		topy = topy + th
	end
	return sprite
end

imageLib.makeSpriteSheet = function(target, name, fileName, inmode, trans, quads)
	local sprite = imageLib.makeSprite(target, name, fileName, inmode, insx, insy, trans)
	sprite.quads = {}
	sprite.sheet = quads
	local iw = sprite.image:getWidth()
	local ih = sprite.image:getHeight()	
	
	--todo - per-quad hotspots?
	--for idx, inq in ipairs(sprite.sheet) do
	for idx = 1,#quads,1 do
		inq = quads[idx]
		print("SpriteSheet: ",idx,inq.x, inq.y, inq.w, inq.h, iw, ih)
		local q = love.graphics.newQuad(inq.x, inq.y, inq.w, inq.h, iw, ih)
		table.insert(sprite.quads,q)
		if (hotspot == nil) then
			inq.ox = inq.w / 2
			inq.oy = inq.h / 2		
		elseif (hotspot == 'bottom') then
			inq.ox = inq.w / 2
			inq.oy = inq.h
		end
	end
			
	return sprite
end

imageLib.makeRenderableSprite = function(insprite,insx,insy,frameNo)
	local	renderable = { sprite = insprite, sx = insx, sy = insy, frame = frameNo or 1, }
	return renderable
end

imageLib.addRenderableSprite = function(target,insprite,insx,insy,frameNo)
	table.insert(target, imageLib.makeRenderableSprite(insprite,insx,insy,frameNo))
end

imageLib.updateRenderable = function(r, dt)
	if (r.sprite.quads) then
		r.frame = r.frame + dt * 10.0
		if (r.frame > (#r.sprite.quads + 1)) then
			r.frame = 1
		end
	end
end

imageLib.drawSprite = function(d, inx, iny)
	if (not d.sprite) then return end
	
	if (d.colour) then
		love.graphics.setColor(d.colour[1],d.colour[2],d.colour[3],d.colour[4])
	end
	
	local blendMode = d.blendMode or d.sprite.blendMode
	
	if (blendMode) then
		love.graphics.setBlendMode(blendMode)
	end	
	--print(d.sprite.name)
	local x = inx or d.x or 0.0
	local y = iny or d.y or 0.0
	
	if (d.sprite.quads) then
		local theFrame = math.floor(d.frame)
		local ox, oy = d.sprite.ox, d.sprite.oy
		if (d.sprite.sheet) then
			if (not d.sprite.sheet[theFrame]) then
				print('Missing frame',theFrame)
				return
			end
			ox = d.sprite.sheet[theFrame].ox
			oy = d.sprite.sheet[theFrame].oy
		end
		love.graphics.drawq(d.sprite.image, d.sprite.quads[theFrame], x, y, d.theta or 0.0, d.sx or d.sprite.sx or 1.0, d.sy or d.sprite.sy or 1.0, ox, oy)
	else
		love.graphics.draw(d.sprite.image, x, y, d.theta or 0.0, d.sx or d.sprite.sx or 1.0, d.sy or d.sprite.sy or 1.0, d.sprite.ox, d.sprite.oy)
	end
	if (blendMode) then
		love.graphics.setBlendMode("alpha")
	end
	if (d.colour) then
		love.graphics.setColor(255,255,255)
	end	
end

imageLib.drawSpriteList = function(dlist)
	for idx, d in pairs(dlist) do
		if (d.alive) then
			imageLib.drawSprite(d)			
			love.graphics.push()
			love.graphics.translate(d.x, d.y)
			if d.children then imagelib.drawSpriteList(d.children) end			
			love.graphics.pop()
		end
	end
end
