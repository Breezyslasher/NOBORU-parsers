Asura = Parser:new("Asura Scans", "https://asuracomic.net", "ENG", "ASURASCANS ", 1)
Asura.Disabled = false


local function stringify(string)
	return string:gsub(
		"&#([^;]-);",
		function(a)
			local number = tonumber("0" .. a) or tonumber(a)
			return number and u8c(number) or "&#" .. a .. ";"
		end
	):gsub(
		"&(.-);",
		function(a)
			return HTML_entities and HTML_entities[a] and u8c(HTML_entities[a]) or "&" .. a .. ";"
		end
	)
end

local function downloadContent(link)
	local f = {}
	Threads.insertTask(
		f,
		{
			Type = "StringRequest",
			Link = link,
			Table = f,
			Index = "text"
		}
	)
	while Threads.check(f) do
		coroutine.yield(false)
	end
	return f.text or ""
end

function Asura:getManga(link, dt)
	local content = downloadContent(link)
	dt.NoPages = true
	for Img, Link, Name in content:gmatch('<div id="manga%-item%-%d+".-src="([^"]+)".-href="([^"]+)".-title="([^"]+)"') do
		dt[#dt + 1] = CreateManga(stringify(Name), Link, Img, self.ID, Link)
		dt.NoPages = false
		coroutine.yield(false)
	end
end

function Asura:getPopularManga(page, dt)
	local content = downloadContent(self.Link .. "/series?page=" .. page .. "&order=rating")
	dt.NoPages = true

	for block in content:gmatch('<a href="series/.-</a>') do
		local Link = block:match('<a href="([^"]+)"')
		local Img = block:match('<img[^>]-src="([^"]+)"')
		local Name = block:match('<span class="block text%-%[13%.3px%] font%-bold">(.-)</span>')

		if Img and Link and Name then
			-- Ensure full URL
			if not Link:match("^https?://") then
				Link = self.Link .. "/" .. Link:gsub("^/", "")
			end
			dt[#dt + 1] = CreateManga(stringify(Name), Link, Img, self.ID, Link)
			dt.NoPages = false
			coroutine.yield(false)
		end
	end
end






function Asura:searchManga(search, page, dt, tags)
	local query = search and search:gsub(" ", "+") or ""
	page = page or 1

	local url = self.Link .. "/?s=" .. query .. "&post_type=wp-manga&paged=" .. page
	local content = downloadContent(url)
	if not content then return end

	local covers = {}
	-- Parse the image blocks
	for block in content:gmatch('<div class="col%-4 col%-md%-2">(.-)</a>') do
		local mangaUrl = block:match('<a href="([^"]+)"')
		local imgSrc = block:match('<img[^>]-src="([^"]+)"')
		if mangaUrl and imgSrc then
			covers[mangaUrl] = imgSrc
		end
	end

	-- Parse the title blocks
	for link, name in content:gmatch('<div class="post%-title">.-<a href="([^"]+)">([^<]+)</a>') do
		local image = covers[link] or ""
		dt[#dt + 1] = CreateManga(name, link, image, self.ID, self.Link)
	end
end



	



function Asura:prepareChapter(chapter, dt)
	local content = downloadContent(chapter.Link)
	for img in content:gmatch('<div class="w%-full mx%-auto center">.-<img.-src="(https://[^"]+%.webp)"') do
		dt[#dt + 1] = img
	end
end



function Asura:loadChapterPage(link, dest_table)
	dest_table.Link = link
end
function Asura:getChapters(manga, dt)
	local content = downloadContent(manga.Link)

	for block in content:gmatch('<div class="pl%-4 py%-2 border rounded%-md.-</a></div>') do
		local link = block:match('<a href="([^"]+)"')
		local name = block:match('<h3 class="text%-sm text%-white.-flex.-">(.-)</h3>')

		if link and name then
			-- Clean chapter name
			local cleanName = name:gsub("<[^>]->", ""):gsub("^%s+", ""):gsub("%s+$", "")
			dt[#dt + 1] = {
				Name = stringify(cleanName),
				Link = link:gsub("^/", ""), -- relative path cleanup
				Pages = {},
				Manga = manga
			}
		end
	end
end

function Asura:getLatestManga(page, dt)
	local content = downloadContent(self.Link .. "/series?page=" .. page .. "&order=update")
	dt.NoPages = true

	for block in content:gmatch('<a href="series/.-</a>') do
		local Link = block:match('<a href="([^"]+)"')
		local Img = block:match('<img[^>]-src="([^"]+)"')
		local Name = block:match('<span class="block text%-%[13%.3px%] font%-bold">(.-)</span>')

		if Img and Link and Name then
			if not Link:match("^https?://") then
				Link = self.Link .. "/" .. Link:gsub("^/", "")
			end
			dt[#dt + 1] = CreateManga(stringify(Name), Link, Img, self.ID, Link)
			dt.NoPages = false
			coroutine.yield(false)
		end
	end
end
