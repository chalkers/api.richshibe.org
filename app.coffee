#Removes a given element from an array
Array::remove = (e) -> @[t..t] = [] if (t = @indexOf(e)) > -1

http = require('http')
https = require('https')
plist = require('plist')

http.createServer((request, response) ->
 
 response.writeHead(200, { 'Content-Type': 'application/x-plist' })
 response.write plist.build(calculateAverages()).toString()
 response.end()
 
).listen(process.env.PORT || 5000)
 
console.log 'Server Started'

markets =
  doge_btc:
    cryptsy: {}
    coins_e: {}
    vircurex: {}
    average: {}
  btc_usd:
    mt_gox: {}
    bitstamp: {}
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
      markets.doge_btc.coins_e = price: @data.ltp * 1
        #trade_time: @data.systime
    catch error
      markets.doge_btc.coins_e = price: undefined
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
      markets.doge_btc.cryptsy = price: doge.lasttradeprice * 1
        #trade_time: doge.lasttradetime
    catch error
      markets.doge_btc.cryptsy = price: undefined
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
      markets.doge_btc.vircurex = price: @data.value * 1
    catch error
      markets.doge_btc.vircurex = price: undefined
      console.log error
    @content = ""

class MtGox extends API
  constructor: (@market, @protocol=https)->

  options: ->
      host: 'data.mtgox.com'
      path: "/api/1/#{@market}/ticker"
      method: 'GET'
      port: 443

  onEnd: ->
    try
      @data = JSON.parse(@content)
      markets.btc_usd.mt_gox = price: @data.return.avg.value * 1
    catch error
      markets.btc_usd.mt_gox = price: undefined
      console.log error
    @content = ""

class Bitstamp extends API
  constructor: (@protocol=https)->

  options: ->
      host: 'www.bitstamp.net'
      path: "/api/ticker/"
      method: 'GET'
      port: 443

  onEnd: ->
    try
      @data = JSON.parse(@content)
      markets.btc_usd.bitstamp = price: @data.last * 1
    catch error
      markets.btc_usd.bitstamp = price: undefined
      console.log error
    @content = ""

calculateAverages = ->
  calculateAverage([markets.doge_btc.vircurex.price, markets.doge_btc.coins_e.price, markets.doge_btc.cryptsy.price], "doge_btc")
  calculateAverage([markets.btc_usd.mt_gox.price, markets.btc_usd.bitstamp.price], "btc_usd")
  markets

calculateAverage = (prices, market)->
  prices.remove(undefined)
  average = 0
  average += price for price in prices
  markets[market].average = price: (average / prices.length).toFixed(8) * 1


cryptsy = new Cryptsy(132)
coinsE = new CoinsE("DOGE_BTC")
vircurex = new Vircurex("DOGE")
mtgox = new MtGox("BTCUSD")
bitstamp = new Bitstamp()

#Inital calls
processMarkets = ->
  cryptsy.process()
  coinsE.process()
  vircurex.process()
  mtgox.process()
  bitstamp.process()

processMarkets()

#Calls Every Minute
setInterval processMarkets, 60 * 1000