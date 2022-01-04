--PoptartNoahh & Sceptive

bmp = {}
bmp.__index = bmp

function bmp.Parse(file)
	local self = {}
	local contents = file:GetBinaryContents()
	local function file_seek(position)
		return contents:sub(position):byte()
	end
	local function make_header(offset)
		return tonumber("0x" .. ("%x"):format(file_seek(offset + 2)) .. ("%x"):format(file_seek(offset + 1)))
	end
	self.file_size, self.file_name = file.Size, file.Name
	self.bitmap_offset = make_header(0x0A)
	self.width, self.height = make_header(0x12), make_header(0x16)
	self.bpp = make_header(0x1C)
	self.image = {}
	for x = 1, self.width do
		self.image[x] = {}
	end
	self.packet_size = self.bpp / 8
	self.padding = (4 - (self.width * self.packet_size) % 4) % 4
	self.palette = {}
	if self.bpp <= 8 then
		for i = 0, 2 ^ self.bpp - 1 do
			local offset = 0x36 + 4 * i + 1
			table.insert(self.palette, Color3.fromRGB(file_seek(offset + 2), file_seek(offset + 1), file_seek(offset)))
		end
	end
	local bitmap_encoding = {
		[32] = function(position)
			return Color3.fromRGB(file_seek(position + 3), file_seek(position + 2), file_seek(position + 1)), file_seek(position + 4) or 1
		end,
		[24] = function(position)
			return Color3.fromRGB(file_seek(position + 3), file_seek(position + 2), file_seek(position + 1))
		end,
		[16] = function(position)
			local rgb, byte = {}, binary.get(file_seek(position + 2)) .. binary.get(file_seek(position + 1))
			for i = 0, 2 do
				local offset = 2 + i * 5
				rgb[i + 1] = binary.reverse(byte:sub(offset, offset + 4)) / 31
			end
			return Color3.new(unpack(rgb))
		end,
		[8] = function(position)
			return self.palette[file_seek(position + 1) + 1]
		end,
		[4] = function(position)
			local byte = binary.get(file_seek(position + 1))
			return self.palette[(position % math.floor(position) == 0 and binary.reverse(byte:sub(1, 4)) or binary.reverse(byte:sub(5, 9))) + 1]
		end,
	}

	local get_encoding = bitmap_encoding[self.bpp]
	if get_encoding then
		local pixels, i = 0, self.bitmap_offset
		for _ = self.bitmap_offset, self.width * self.packet_size * self.height + self.bitmap_offset - self.packet_size, self.packet_size do
			local color, alpha = get_encoding(i)
			pixels += 1
			i += self.packet_size
			if pixels % self.width == 0 then
				i += self.padding
			end
			self.image[self.width - (pixels - 1) % self.width][math.ceil(pixels / self.width)] = {color, alpha and alpha / 255 or 1}
		end
	else
		error("Supported bitmap formats: 32-bit, 24-bit, 16-bit, 8-bit, 4-bit")
	end

	self.Pixel = function(x, y)
		local pixel = self.image[x][y]
		if pixel then
			return unpack(pixel)
		end
	end

	return setmetatable(self, 
		{
			__index = function(_, index)
				if index == "Size" then
					return self.file_size
				elseif index == "Name" then
					return self.file_name
				elseif index == "Width" then
					return self.width
				elseif index == "Height" then
					return self.height
				end
			end
		}
	)
end

binary = {
	get = function(n)
		local b = ""
		while n ~= 0 do
			b = (n % 2) .. b
			n = math.floor(n / 2)
		end
		b = ("0"):rep(8 - #b) .. b
		return b
	end,
	reverse = function(s)
		local a, b = s:reverse(), 0
		for j = 1, 5 do
			b += (if a:sub(j, j) == "1" then 1 else 0) * math.pow(2, j - 1)
		end
		return b
	end,
}

return bmp

--[[
	local Image = BMP.Parse(file)
	for x = 1, Image.Width do
		for y = 1, Image.Height do
			local color, alpha = Image.Pixel(x, y)
			if alpha then
				local transparency = 1 - alpha
			end
		end
	end
]]
