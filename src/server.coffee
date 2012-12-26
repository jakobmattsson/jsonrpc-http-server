express = require 'express'
introspect = require 'introspect'
resterTools = require 'rester-tools'

exports.run = ({ endpoint, port, api, jsonrpc }) ->

  app = express()
  app.set('json spaces', 2)

  app.post endpoint, [
    resterTools.replaceContentTypeMiddleware({ 'text/plain': 'application/json' })
    express.json()
  ], (req, res) ->
    jsonrpc.answer req.body, (err, data) ->
      res.send(if err? then 400 else (data ? 204))

  Object.keys(api).forEach (method) ->
    jsonrpc.add(method, introspect(api[method]).slice(0, -1), api[method])

  Object.keys(api).forEach (method) ->
    app.get "#{endpoint}:method", (req, res) ->
      jsonrpc.answerJSONP req.params.method, req.query, (err, data) ->
        res.set('content-type', 'text/javascript')
        res.send(if err? then 400 else (data ? '').toString())

  app.all '*', (req, res) ->
    res.header('content-type', 'text/plain')
    res.send('Invalid function.', 404)

  app.listen(port)

  app
