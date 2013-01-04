express = require 'express'
introspect = require 'introspect'
resterTools = require 'rester-tools'

exports.run = ({ endpoint, port, api, jsonrpc, version }) ->

  app = express()
  app.set('json spaces', 2)

  app.post endpoint, [
    resterTools.replaceContentTypeMiddleware({ 'text/plain': 'application/json' })
    express.json()
  ], (req, res) ->
    if req.body?.jsonrpc == '2.0' && req.body?.method == 'version'
      return res.send(if req.body?.id? then { jsonrpc: "2.0", result: version, id: req.body.id } else 204)

    jsonrpc.answer req.body, (err, data) ->
      res.send(if err? then 400 else (data ? 204))

  Object.keys(api).forEach (method) ->
    jsonrpc.add(method, introspect(api[method]).slice(0, -1), api[method])

  Object.keys(api).forEach (method) ->
    app.get "#{endpoint}:method", (req, res) ->
      res.set('content-type', 'text/javascript')

      if req.params.method == 'version' && version?
        str = JSON.stringify({ jsonrpc: "2.0", result: version, id: req.query.callback })
        res.send("#{req.query.callback}(#{str})")
        return

      jsonrpc.answerJSONP req.params.method, req.query, (err, data) ->
        res.send(if err? then 400 else (data ? '').toString())

  app.all '*', (req, res) ->
    res.header('content-type', 'text/plain')
    res.send('Invalid function.', 404)

  app.listen(port)

  app
