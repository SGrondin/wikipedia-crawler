http = require "http"
Bottleneck = require "bottleneck"
util = require "util"
cheerio = require "cheerio"
filesize = require "filesize"
con = () -> util.puts Array::slice.call(arguments, 0).map((a)->util.inspect a).join " "
Object::toArray = () -> Object.keys @
Array::toPath = () -> @join " -> "
rImg = new RegExp "^\/wiki\/(?!.+?(?:[.]jpg|[.]png|[.]svg)$)", "i"

nbPagesDownloaded = 0
nbBytes = 0
nbLinks = 0
visited = {}
wikiLimiter = new Bottleneck 15, 200
getPage = (addr, cb) ->
	data = ""
	req = http.request {
		hostname: "en.wikipedia.org"
		port: 80
		method: "GET"
		path: addr
		headers:{
			"user-agent": "Hitler Bot v0.1"
		}
	}, (res) ->
		res.on "data", (chunk) ->
			nbBytes += chunk.length
			data += chunk.toString "utf8"
		res.on "end", () ->
			cb null, data
	req.on "error", (err) ->
		cb err
	req.end()

parsePage = (addr, depth, cb) ->
	if depth.length > 4 then return

	getPage addr, (err, data) ->
		if err then con err, depth.toPath()
		nbPagesDownloaded++

		$ = cheerio.load data
		parsed = $("a").toArray()
			.map (a) ->
				href = a.attribs?.href or ""
				lhref = href.toLowerCase()
				if lhref[-12..] == "/wiki/hitler" or lhref[-18..] == "/wiki/adolf_hitler"
					found addr, depth.concat(href)
				href
			.filter (a) ->
				rImg.test a

		nbLinks += parsed.length
		console.log "("+depth.length+") Parsed "+addr+", "+parsed.length+" links"
		parsed.forEach (a) ->
			if not visited[a]?
				wikiLimiter.submit parsePage, a, depth.concat(a), ->
				visited[a] = true
		cb()

found = (addr, depth) ->
	console.log "\n\n"+depth.toPath()+"   FOUND HITLER!!!\n"+
		nbPagesDownloaded+" pages ("+filesize(nbBytes)+") downloaded\n"+
		nbLinks+" links found\n\n"
	wikiLimiter.stopAll()

start = "/wiki/"+process.argv[2]
wikiLimiter.submit parsePage, start, [start], ->
