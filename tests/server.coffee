should = require 'should'
_ = require 'underscore'
request = require 'request'
server = require('./coverage').require('server')

describe "rpc call", ->

  endpoint = '/'
  port = 6070
  jsonrpc =
    add: -> calls.add.push(arguments)
    remove: -> calls.remove.push(arguments)
    answer: (body, callback) -> calls.answer.push(body); callback.apply(null, reply)
    answerJSONP: (name, qs, callback) -> calls.answerJSONP.push([name, qs]); callback.apply(null, reply)
  api =
    sum: (v1, v2, v3, callback) ->
    subtract: (minuend, subtrahend, callback) ->
    update: (v1, v2, v3, v4, v5, callback) ->
    notify_hello: (v, x, callback) ->
    get_data: (callback) ->

  reply = null
  calls = {
    add: []
    remove: []
    answer: []
    answerJSONP: []
  }

  server.run({
    version: '123'
    jsonrpc: jsonrpc
    endpoint: endpoint
    port: port
    api: api
  })

  beforeEach ->
    reply = null
    calls = {
      add: []
      remove: []
      answer: []
      answerJSONP: []
    }

  describe "from the spec", ->

    it "with positional parameters (2)", (done) ->
      reply = [null, {}]
      request
        url: "http://localhost:#{port}#{endpoint}"
        method: 'POST'
        headers: { 'Content-type': 'application/json' }
        body: '{"jsonrpc": "2.0", "method": "subtract", "params": [23, 42], "id": "2" }'
      , (err, response, data) ->
        response.statusCode.should.eql 200
        response.headers['content-type'].should.eql 'application/json; charset=utf-8'
        calls.answer.should.eql [{
          jsonrpc: "2.0"
          method: 'subtract'
          params: [23, 42]
          id: "2"
        }]
        done()



    it "should return version nubmer", (done) ->
      request
        url: "http://localhost:#{port}#{endpoint}"
        method: 'POST'
        json:
          jsonrpc: "2.0"
          method: 'version'
          id: "2"
      , (err, response, data) ->
        response.statusCode.should.eql 200
        response.headers['content-type'].should.eql 'application/json; charset=utf-8'
        calls.answer.should.eql []
        data.should.eql { jsonrpc: '2.0', result: '123', id: '2' }
        done()



    it "a notification (1)", (done) ->
      reply = [null]
      request
        url: "http://localhost:#{port}#{endpoint}"
        method: 'POST'
        json:
          jsonrpc: "2.0"
          params: [1,2,3,4,5]
          method: 'update'
      , (err, response, data) ->
        calls.answer.should.eql [{
          jsonrpc: "2.0"
          method: 'update'
          params: [1,2,3,4,5]
        }]
        response.statusCode.should.eql 204
        should.not.exist data
        done()


    it.skip "with invalid JSON", (done) ->
      request
        url: "http://localhost:#{port}#{endpoint}"
        method: 'POST'
        headers: { 'Content-type': 'application/json' }
        body: '{"jsonrpc": "2.0", "method": "subtract, "params": "bar", "baz]'
      , (err, response, data) ->
        response.statusCode.should.eql 200
        data.should.be.a 'string'
        JSON.parse(data).should.eql
          jsonrpc: "2.0"
          id: null
          error:
            code: -32700
            message: "Parse error."
        done()



    it.skip "Batch, invalid JSON", (done) ->

      request
        url: "http://localhost:#{port}#{endpoint}"
        method: 'POST'
        headers: { 'Content-type': 'application/json' }
        body: '[{"jsonrpc": "2.0", "method": "sum", "params": [1,2,4], "id": "1"},{"jsonrpc": "2.0", "method"]'
      , (err, response, data) ->
        response.statusCode.should.eql 200
        data.should.be.a 'string'
        JSON.parse(data).should.eql
          jsonrpc: "2.0"
          id: null
          error:
            code: -32700
            message: "Parse error."
        done()


    it "should work even if the content-type is text/plain (for XDomainRequest)", (done) ->
      reply = [null, { whatever: 1 }]

      request
        url: "http://localhost:#{port}#{endpoint}"
        method: 'POST'
        headers: { 'Content-type': 'text/plain' }
        body: '{"jsonrpc": "2.0", "method": "subtract", "params": [23, 42], "id": "2" }'
      , (err, response, data) ->
        calls.answer.should.eql [{
          jsonrpc: "2.0"
          method: 'subtract'
          params: [23, 42]
          id: "2"
        }]
        response.statusCode.should.eql 200
        JSON.parse(data).should.eql
          whatever: 1
        done()



    it "jsonp transport: with quote escaped parameters", (done) ->
      reply = [null, 'blaha']

      request
        url: "http://localhost:#{port}#{endpoint}subtract?callback=whatever&subtrahend=\"23%22&minuend=42"
        method: 'GET'
      , (err, response, data) ->
        calls.answerJSONP.should.eql [
          ['subtract', { callback: 'whatever', subtrahend: '"23"', minuend: "42" }] # måste testa vad som händer när man stoppar in parse-grejer 
        ]
        response.statusCode.should.eql 200
        response.headers['content-type'].should.eql 'text/javascript'
        data.should.eql 'blaha'
        done()



    it "jsonp transport: with escaped objects as parameters", (done) ->
      reply = [null, {a: 1}]

      request
        url: "http://localhost:#{port}#{endpoint}subtract?callback=whatever&subtrahend=" + encodeURIComponent('{"a":1,"b":2}') + "&minuend=42"
        method: 'GET'
      , (err, response, data) ->
        calls.answerJSONP.should.eql [
          ['subtract', { callback: 'whatever', subtrahend: '{"a":1,"b":2}', minuend: "42" }] # måste testa vad som händer när man stoppar in parse-grejer 
        ]
        response.statusCode.should.eql 200
        response.headers['content-type'].should.eql 'text/javascript'
        data.should.eql '[object Object]'
        done()



    it "invoking non-existing function using POST", (done) ->
      request
        url: "http://localhost:#{port}#{endpoint}unknown"
        method: 'POST'
      , (err, response, data) ->
        response.statusCode.should.eql 404
        data.should.eql 'Invalid function.'
        done()



    it "replies with the version number when the function 'version' is invoked", (done) ->
      request
        url: "http://localhost:#{port}#{endpoint}version?callback=whatever"
        method: 'GET'
      , (err, response, data) ->
        response.statusCode.should.eql 200
        response.headers['content-type'].should.eql 'text/javascript'
        data.should.eql 'whatever({"jsonrpc":"2.0","result":"123","id":"whatever"})'
        done()
