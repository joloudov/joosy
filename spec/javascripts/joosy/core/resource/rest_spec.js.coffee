describe "Joosy.Resource.REST", ->

  beforeEach ->
    @server = sinon.fakeServer.create()
    class @Test extends Joosy.Resource.REST
      @entity 'test'

  afterEach ->
    @server.restore()

  it "should have default primary key", ->
    expect(@Test::__primaryKey).toEqual 'id'

  it "should have appropriate accessors", ->
    @Test.entity 'tada'
    expect(@Test::__entityName).toEqual 'tada'
    @Test.source 'uri'
    expect(@Test.__source).toEqual 'uri'
    expect(@Test.__buildSource()).toEqual 'uri/'
    @Test.primary 'uid'
    expect(@Test::__primaryKey).toEqual 'uid'

  it "should build source url based on entity name", ->
    options =
      extension: 'id'
      params:
        test: 1
    expect(@Test.__buildSource(options)).toEqual '/tests/id?test=1'

  it "should have overloaded constructor", ->
    resource = @Test.create 'someId'
    expect(resource.id).toEqual 'someId'

    data = {id: 'someId', field: 'value'}

    rooted   = @Test.create {test: data}
    unrooted = @Test.create data

    expect(rooted.e).toEqual unrooted.e
    expect(rooted.id).toEqual 'someId'
    expect(rooted.e.id).toEqual 'someId'
    expect(rooted.e.field).toEqual 'value'

  it 'should find single object', ->
    @Test.beforeLoad beforeLoadCallback = sinon.spy (data) ->
      expect(data.id).toEqual 1
      expect(data.name).toEqual 'test1'
      Object.extended(data)
    @Test.find 1, callback = sinon.spy (target) ->
      expect(target.id).toEqual 1
      expect(target.e?.name).toEqual 'test1'
    target = @server.requests[0]
    expect(target.method).toEqual 'GET'
    expect(target.url).toMatch /^\/tests\/1\?_=\d+/
    target.respond 200, 'Content-Type': 'application/json',
      '{"test": {"id": 1, "name": "test1"}}'
    expect(callback.callCount).toEqual 1
    expect(beforeLoadCallback.callCount).toEqual 1

  it 'should find objects collection with params', ->
    callback = sinon.spy (collection) ->
      i = 1
      expect(collection instanceof Joosy.Resource.RESTCollection).toBeTruthy()
      collection.data.each (target) ->
        expect(target.id).toEqual i
        expect(target.e?.name).toEqual 'test' + i
        i += 1
    @Test.find null, callback
    target = @server.requests[0]
    expect(target.method).toEqual 'GET'
    expect(target.url).toMatch /^\/tests\/\?_=\d+/
    target.respond 200, 'Content-Type': 'application/json',
      '[{"id": 1, "name": "test1"}, {"id": 2, "name": "test2"}]'
    expect(callback.callCount).toEqual 1

  it 'should find all objects collection', ->
    callback = sinon.spy (collection) ->
      i = 1
      expect(collection instanceof Joosy.Resource.RESTCollection).toBeTruthy()
      collection.data.each (target) ->
        expect(target.id).toEqual i
        expect(target.e?.name).toEqual 'test' + i
        i += 1
    @Test.find callback
    target = @server.requests[0]
    expect(target.method).toEqual 'GET'
    expect(target.url).toMatch /^\/tests\/\?_=\d+/
    target.respond 200, 'Content-Type': 'application/json',
      '[{"id": 1, "name": "test1"}, {"id": 2, "name": "test2"}]'
    expect(callback.callCount).toEqual 1

  it 'should destroy single object', ->
    obj = @Test.create 1
    callback = sinon.spy (target) ->
      expect(target).toBe obj
    obj.destroy callback
    target = @server.requests[0]
    expect(target.method).toEqual 'DELETE'
    expect(target.url).toEqual '/tests/1'
    target.respond 200
    expect(callback.callCount).toEqual 1

  it "should identify identifiers", ->
    [0, 123, -5, '123abd', 'whatever'].each (variant) =>
      expect(@Test.__isId variant).toBeTruthy()
    [(->) , [], {}, null, undefined, true, false].each (variant) =>
      expect(@Test.__isId variant).toBeFalsy()

  it "should trigger 'changed' on fetch", ->
    resource = @Test.find 1, callback = sinon.spy (target) ->
      expect(target.id).toEqual 1
      expect(target.e?.name).toEqual 'test1'
    target = @server.requests[0]
    expect(target.method).toEqual 'GET'
    expect(target.url).toMatch /^\/tests\/1\?_=\d+/
    target.respond 200, 'Content-Type': 'application/json',
      '{"test": {"id": 1, "name": "test1"}}'
    expect(callback.callCount).toEqual 1
    
    resource.bind 'changed', callback = sinon.spy()
    resource.fetch()
    
    target = @server.requests[1]
    expect(target.method).toEqual 'GET'
    expect(target.url).toMatch /^\/tests\/1\?_=\d+/
    target.respond 200, 'Content-Type': 'application/json',
      '{"test": {"id": 1, "name": "test1"}}'
      
    expect(callback.callCount).toEqual 1