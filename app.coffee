#Removes a given element from an array
Array::remove = (e) -> @[t..t] = [] if (t = @indexOf(e)) > -1

http = require('http')
https = require('https')
plist = require('plist')

http.createServer((request, response) ->
 
 response.writeHead(200, { 'Content-Type': 'application/json' })
 response.write plist.build(calculateAverage()).toString()
 response.end()
 
).listen(process.env.PORT || 5000)
 
console.log 'Server Started'

markets =
  cryptsy: {}
  coins_e: {}
  vircurex: {}
  average: {}

class API
  onData: (chunk) ->
    @content += chunk.toString()

  onEnd: ->

  onError: (error) ->
    console.log "Error while calling endpoint.", error

  process: ->
    @content = ""
    that = this
    request = @protocol.request this.options(), (response) ->
      response.on 'data', (chunk) -> 
        that.onData(chunk)
      response.on 'end', ->
        that.onEnd()
    request.on 'error', (error) ->
      that.onError(error)
    request.end()

class CoinsE extends API
  constructor: (@market, @protocol=https)->

  options: ->
      host: 'www.coins-e.com'
      path: "/api/v2/market/#{@market}/depth/"
      method: 'GET'
      port: 443

  onEnd: ->
    try
      @data = JSON.parse(@content)
      markets.coins_e = price: @data.ltp * 1
        #trade_time: @data.systime
    catch error
      markets.coins_e = price: undefined
      console.log error
    @content = ""
  
class Cryptsy extends API
  constructor: (@market, @protocol=http)->

  options: ->
      host: 'pubapi.cryptsy.com'
      path: "/api.php?method=singlemarketdata&marketid=#{@market}"
      method: 'GET'

  onEnd: ->
    try
      @data = JSON.parse(@content)
      doge = @data.return.markets.DOGE
      markets.cryptsy = price: doge.lasttradeprice * 1
        #trade_time: doge.lasttradetime
    catch error
      markets.cryptsy = price: undefined
      console.log error
    @content = ""



class Vircurex extends API
  constructor: (@market, @protocol=https)->

  options: ->
      host: 'api.vircurex.com'
      path: "/api/get_last_trade.json?base=#{@market}&alt=BTC"
      method: 'GET'
      port: 443

  onEnd: ->
    try
      @data = JSON.parse(@content)
      markets.vircurex = price: @data.value * 1
    catch error
      markets.vircurex = price: undefined
      console.log error
    @content = ""

calculateAverage = ->
  prices = [markets.vircurex.price, markets.coins_e.price, markets.cryptsy.price]
  prices.remove(undefined)
  average = 0
  average += price for price in prices
  markets.average = price: (average / prices.length).toFixed(8) * 1
  markets

cryptsy = new Cryptsy(132)
coinsE = new CoinsE("DOGE_BTC")
vircurex = new Vircurex("DOGE")

#Inital calls
cryptsy.process()
coinsE.process()
vircurex.process()

#Calls Every Minute
setInterval ->
  cryptsy.process()
  coinsE.process()
  vircurex.process()
, 60 * 1000