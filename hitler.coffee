http = require "http"
Bottleneck = require "bottleneck"
util = require "util"
cheerio = require "cheerio"
con = (v) -> util.puts util.inspect v
Object::toArray = () -> Object.keys @
Array::toPath = () -> @join " -> "
rImg = new RegExp "^\/wiki\/(?!.+?(?:[.]jpg|[.]png|[.]svg)$)", "i"

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
			"user-agent": "Hiter Bot v0.1"
		}
	}, (res) ->
		res.on "data", (chunk) ->
			data += chunk.toString "utf8"
		res.on "end", () ->
			cb null, data
	req.on "error", (err) ->
		cb err
	req.end()

parsePage = (addr, depth, cb) ->
	if depth.length > 4 then return

	getPage addr, (err, data) ->
		if err then throw err

		$ = cheerio.load data
		parsed = $("a").toArray()
			.map (a) ->
				href = a.attribs?.href or ""
				lhref = href.toLowerCase()
				if lhref[-12..] == "/wiki/hitler" or lhref[-18..] == "/wiki/adolf_hitler"
					console.log "\n\n"+depth.concat(href).toPath()+"   FOUND HITLER!!! in "+addr+"\n\n"
					wikiLimiter.stopAll()
				href
			.filter (a) ->
				rImg.test a

		console.log "("+depth.length+") Parsed "+addr+", "+parsed.length+" links"
		parsed.forEach (a) ->
			if not visited[a]?
				wikiLimiter.submit parsePage, a, depth.concat(a), ->
				visited[a] = true
		cb()

start = "/wiki/"+process.argv[2]
wikiLimiter.submit parsePage, start, [start], ->
