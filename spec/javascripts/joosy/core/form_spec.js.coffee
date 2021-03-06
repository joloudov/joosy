describe "Joosy.Form", ->

  beforeEach ->
    @server = sinon.fakeServer.create()
    @seedGround()
    @nudeForm = "<form id='nude'><input name='test[foo]'/><input name='test[bar]'/><input name='test[bool]' type='checkbox' value='1'/></form>"
    @putForm  = "<form id='put' method='put'><input name='test[camel_baz]'/></form>"
    @moreForm = "<form id='more' method='put'><input name='test[ololo]'/></form>"

    @ground.find('#sidebar').after(@nudeForm).after(@putForm).after(@moreForm)

    @nudeForm = $('#nude')
    @putForm  = $('#put')
    @moreForm = $('#more')

    class Test extends Joosy.Resource.REST
      @entity 'test'

    @resource = Test.create
      foo: 'foo',
      bar: 'bar'
      camelBaz: 'baz'
      bool: true

  afterEach ->
    @server.restore()

  describe "Initialization", ->

    beforeEach ->
      @spy = sinon.spy $.fn, 'ajaxForm'

    afterEach ->
      @spy.restore()

    it "should properly act with options", ->
      formWithProperties = new Joosy.Form @nudeForm, invalidationClass: 'fluffy'
      expect(formWithProperties.container).toEqual @nudeForm
      expect(formWithProperties.invalidationClass).toEqual 'fluffy'
      expect(formWithProperties.fields.length).toEqual 3

      expect(@spy.callCount).toEqual 1

    it "should properly act with callback", ->
      formWithCallback = new Joosy.Form @putForm, callback=sinon.spy()
      expect(formWithCallback.container).toEqual @putForm
      expect(formWithCallback.invalidationClass).toEqual 'field_with_errors'
      expect(formWithCallback.success).toBe callback
      expect(formWithCallback.fields.length).toEqual 1

      expect(@spy.callCount).toEqual 1

    it "should hijack form method if it differs from POST/GET", ->
      form   = new Joosy.Form @putForm, callback=sinon.spy()
      marker = @putForm.find "input[type=hidden]"
      expect(@putForm.attr('method')?.toLowerCase()).toEqual 'post'
      expect(marker.attr 'name').toEqual '_method'
      expect(marker.attr 'value').toEqual 'put'

  describe "Filling", ->

    beforeEach ->
      @nudeForm = new Joosy.Form @nudeForm
      @putForm  = new Joosy.Form @putForm
      @moreForm = new Joosy.Form @moreForm

    it "should fill form, set propert action and method and store resource", ->
      @nudeForm.fill @resource
      expect(@nudeForm.fields[0].value).toEqual 'foo'
      expect(@nudeForm.fields[1].value).toEqual 'bar'
      expect(@nudeForm.fields[2].checked).toEqual true
      expect(@nudeForm.fields[2].value).toEqual '1'
      expect(@nudeForm.container.attr('method').toLowerCase()).toEqual 'post'
      expect(@nudeForm.container.attr 'action').toEqual '/tests/'
      expect(@nudeForm.__resource).toEqual @resource

    it "should fill form with camelized properties", ->
      @putForm.fill @resource
      expect(@putForm.fields[0].value).toEqual 'baz'
      expect(@putForm.container.attr('method').toLowerCase()).toEqual 'post'
      expect(@putForm.container.attr 'action').toEqual '/tests/'

    it "should fill form with decorator", ->
      @moreForm.fill @resource, (e) ->
        e.ololo = e.camelBaz
        e
      expect(@moreForm.fields[0].value).toEqual 'baz'

  describe "Callbacks", ->

    beforeEach ->
      @nudeForm = new Joosy.Form @nudeForm, @spy=sinon.spy()
      @nudeForm.fill @resource
      @nudeForm.container.submit()
      @target = @server.requests.last()

    it "should trigger 'success'", ->
      expect(@target.method).toEqual 'POST'
      expect(@target.url).toEqual '/tests/'
      @target.respond 200, 'Content-Type': 'application/json', '{"form": "works"}'
      expect(@spy.callCount).toEqual 1
      expect(@spy.args[0][0]).toEqual {form: 'works'}

    it "should fill class for invalidated fields by default", ->
      @target.respond 422, 'Content-Type': 'application/json', '{"foo": "error!"}'
      expect($(@nudeForm.fields[0]).attr 'class').toEqual 'field_with_errors'

    it "should trigger 'error' and complete default action if it returned true", ->
      @nudeForm.error = sinon.spy ->
        true
      @target.respond 422, 'Content-Type': 'application/json', '{"foo": "error!"}'
      expect($(@nudeForm.fields[0]).attr 'class').toEqual 'field_with_errors'
      expect(@nudeForm.error.callCount).toEqual 1
      expect(@nudeForm.error.args[0][0]).toEqual
        "foo": "error!"

    it "should trigger 'error' and skip default action if it returned false", ->
      @nudeForm.error = sinon.spy ->
        false
      @target.respond 422, 'Content-Type': 'application/json', '{"foo": "error!"}'
      expect($(@nudeForm.fields[0]).attr 'class').toNotEqual 'field_with_errors'
      expect(@nudeForm.error.callCount).toEqual 1

    it "should clear fields before another submit", ->
      @target.respond 422, 'Content-Type': 'application/json', '{"foo": "error!"}'
      expect($(@nudeForm.fields[0]).attr 'class').toEqual 'field_with_errors'
      @nudeForm.container.submit()
      expect($(@nudeForm.fields[0]).attr 'class').toNotEqual 'field_with_errors'

    it "should trigger 'before' and do default action if it returns true", ->
      @target.respond 422, 'Content-Type': 'application/json', '{"foo": "error!"}'
      expect($(@nudeForm.fields[0]).attr 'class').toEqual 'field_with_errors'
      @nudeForm.before = sinon.spy ->
        true
      @nudeForm.container.submit()
      expect($(@nudeForm.fields[0]).attr 'class').toNotEqual 'field_with_errors'
      expect(@nudeForm.before.callCount).toEqual 1

    it "should trigger 'before' and skip default action if it returns false", ->
      @target.respond 422, 'Content-Type': 'application/json', '{"foo": "error!"}'
      expect($(@nudeForm.fields[0]).attr 'class').toEqual 'field_with_errors'
      @nudeForm.before = sinon.spy ->
        false
      @nudeForm.container.submit()
      expect($(@nudeForm.fields[0]).attr 'class').toEqual 'field_with_errors'
      expect(@nudeForm.before.callCount).toEqual 1
      
  describe "Error response handling", ->
    
    beforeEach ->
      @nudeForm = new Joosy.Form @nudeForm, @spy=sinon.spy()
    
    it "should prepare simple response", ->
      errors = {zombie: ['suck'], puppies: ['rock']}
      result = @nudeForm.__stringifyErrors(errors)
      
      expect(result).toEqual zombie: ['suck'], puppies: ['rock']
      
    it "should prepare inline response", ->
      errors = {"zombie.in1.subin1": ['suck'], "zombie.in2": ['rock']}
      result = @nudeForm.__stringifyErrors(errors)
      
      expect(result).toEqual {"zombie[in1][subin1]": ['suck'], "zombie[in2]": ['rock']}
      
    it "should prepare inline response with resource attached", ->
      @nudeForm.fill @resource
      errors = {"zombie.in1.subin1": ['suck'], "zombie.in2": ['rock']}
      result = @nudeForm.__stringifyErrors(errors)

      expect(result).toEqual {"test[zombie][in1][subin1]": ['suck'], "test[zombie][in2]": ['rock']}
      
    it "should prepare simple response with resource attached", ->
      @nudeForm.fill @resource
      errors = {zombie: ['suck'], puppies: ['rock']}
      result = @nudeForm.__stringifyErrors(errors)

      expect(result).toEqual { "test[zombie]": ['suck'], "test[puppies]": ['rock'] }
      
    it "should prepare complexe response", ->
      @nudeForm.fill @resource
      errors = {fluffies: {zombie: {mumbas: ['ololo']}}}
      result = @nudeForm.__stringifyErrors(errors)

      expect(result).toEqual { "fluffies[zombie][mumbas]": ['ololo'] }