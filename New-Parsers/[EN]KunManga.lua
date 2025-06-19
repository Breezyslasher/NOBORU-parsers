KunManga = Parser:new("KunManga", "https://kunmanga.com", "ENG", "KUNMANGA ", 1)
KunManga.Disabled = false


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

function KunManga:getManga(link, dt)
	local content = downloadContent(link)
	self:parseMangaList(content, dt)
end


function KunManga:getPopularManga(page, dt)
	local content = downloadContent(self.Link .. "/manga/page/" .. page .. "/?m_orderby=trending")
	self:parseMangaList(content, dt)
end





function KunManga:searchManga(search, page, dt, tags)
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



	



function KunManga:prepareChapter(chapter, dt)
	local content = downloadContent(chapter.Link)
	
	for Link in content:gmatch('<img[^>]+src%s*=%s*["\']%s*([^"\'>]+)%s*["\'][^>]*class%s*=%s*["\']wp%-manga%-chapter%-img["\']') do
		dt[#dt + 1] = Link:gsub("\\/", "/")
	end
end


function KunManga:loadChapterPage(link, dest_table)
	dest_table.Link = link
end
function KunManga:getChapters(manga, dt)
	local content = downloadContent(manga.Link)

	for li in content:gmatch('<li class="wp%-manga%-chapter[^>]-">(.-)</li>') do
		local link = li:match('<a[^>]-href="([^"]+)"')
		local name = li:match('<a[^>]*>(.-)</a>')

		if link and name then
			-- Remove tags inside the <a> and decode entities
			local cleanName = name:gsub("<[^>]->", ""):gsub("^%s+", ""):gsub("%s+$", "")
			dt[#dt + 1] = {
				Name = stringify(cleanName),
				Link = link:gsub(manga.Link, ""), -- optionally remove base
				Pages = {},
				Manga = manga
			}
		end
	end
end

function KunManga:getLatestManga(page, dt)
	local content = downloadContent(self.Link .. "/manga/page/" .. page .. "/?m_orderby=new-manga")
	self:parseMangaList(content, dt)
end

function KunManga:parseMangaList(content, dt)
	dt.NoPages = true

	for block in content:gmatch('<div class="col%-6 col%-md%-3 badge%-pos%-1">.-</div>%s*</div>') do
		local Img = block:match('<img[^>]-src="([^"]+)"')
		local Link = block:match('<a href="([^"]+)"')
		local Name = block:match('<div class="post%-title.-<h3.-<a[^>]+>([^<]+)</a>')

		-- Fix webp
		if Img and Img:match("%.webp$") then
			Img = Img:gsub("%.webp$", ".jpg")
		end

		if Img and Link and Name then
			dt[#dt + 1] = CreateManga(stringify(Name), Link, Img, self.ID, Link)
			dt.NoPages = false
			coroutine.yield(false)
		end
	end
end
