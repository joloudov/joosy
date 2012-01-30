class Joosy.Resource.Generic extends Joosy.Module
  @include Joosy.Modules.Log
  @include Joosy.Modules.Events

  @beforeLoad: (action) -> @::__beforeLoad = action

  @create: ->
    shim = ->
      shim.__call.apply(shim, arguments)

    if shim.__proto__
      shim.__proto__ = @prototype
    else
      for key, value of @prototype
        shim[key] = value
    
    @apply(shim, arguments)

    shim

  constructor: (data) ->
    @__fillData(data)
    
  get: (path) ->
    target = @__callTarget(path)
    target[0][target[1]]

  set: (path, value) ->
    target = @__callTarget(path)
    target[0][target[1]] = value

    @trigger 'changed'

  __callTarget: (path) ->
    if path.has(/\./) && !@e[path]?
      path    = path.split '.'
      keyword = path.pop()
      target  = @e
      
      for part in path
        target[part] ||= {}
        target = target[part]

      [target, keyword]
    else
      [@e, path]

  __call: (path, value) ->
    if value
      @set path, value
    else
      @get path

  __fillData: (data) ->
    @e = @__prepareData(data)

  __prepareData: (data) ->
    data = Object.extended(data)
    data = @__beforeLoad(data) if @__beforeLoad?
    data