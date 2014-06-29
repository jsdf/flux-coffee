# Implementing Flux in CoffeeScript

I've adapted the dispatcher from the React TodoMVC example.

I've chosen to use the Bluebird promise library, though any library or polyfill
for the standard would work.
```coffee
{Promise} = require 'bluebird'
```

Dispatch handlers provided by stores are stored in an object, keyed by the store
name, as are the promises or promise-resolving values returned by handlers
during a particular dispatch cycle.
```coffee
_handlers = {}
_pendingDispatches = {}
```
The dispatcher is implemented as a static class, with only class methods.
```coffee
class Dispatcher
```

Rather than registering a callback, as in the example dispatcher, store
singletons are registered against the dispatcher. The stores should have a 'name'
and a 'receiveDispatch' method, which is used as the dispatch callback.
```coffee
  @register: (store) ->
    _handlers[store.name] = store.receiveDispatch.bind(store)
```

The dispatch method accumulates the promises returned by the dispatch handlers
in objects keyed by store name.
```coffee
  @dispatch: (payload) ->
    _pendingDispatches = {}
    resolves = {}
    rejects = {}

    storeNames = Object.keys(_handlers)
    for storeName in storeNames
      _pendingDispatches[storeName] = new Promise (resolve, reject) ->
        resolves[storeName] = resolve
        rejects[storeName] = reject

    # dispatch to handlers and resolve/reject promises.
    for storeName in storeNames
      handleResolve = -> resolves[storeName](payload)
      handleReject = -> rejects[storeName](new Error("Dispatcher handler unsuccessful"))

      Promise.resolve(_handlers[storeName](payload)).then(handleResolve, handleReject)

    _pendingDispatches = {} # reset
```

`waitFor` is mostly the same as the example implementation, except it accepts
an array of store objects as dependencies.
```coffee
  @waitFor: (dependencies, handler) ->
    selectedPromises = dependencies.map (dependency) ->
      _pendingDispatches[dependency.name] or throw new Error("Unknown waitFor dependency #{dependency.name}")
    Promise.all(selectedPromises).then(handler)
```

We implement a base class for the stores, which can be watched for changes.
```coffee
extend = require 'xtend/mutable'

CHANGE_EVENT = 'change'

class Store
  extend(@, EventEmitter::)

  @emitChange: ->
    @emit CHANGE_EVENT

  @addChangeListener: (callback) ->
    @on CHANGE_EVENT, callback

  @removeChangeListener: (callback) ->
    @removeListener CHANGE_EVENT, callback
```

Taking advantage of CoffeeScript's executable class bodies, a class method
is provided for convenience when defining actions on Store subclasses.
```coffee
  @action: (name, handler) ->
    @actions ?= {}
    @actions[name] = handler.bind(@)
```
The `receiveDispatch` method which the store provides to the dispatcher catches
errors thrown in the handlers. `false` is returned for an error to cause the
promise for this store to reject. If the handler returns a promise it is passed
on, otherwise true is returned to resolve the promise in the dispatcher.
```coffee
  @receiveDispatch: ({action} = payload) ->
    actionHandler = @actions[action.actionType]
    if actionHandler?
      try
        result = actionHandler(action)
      catch err
        false # reject promise
      finally
        result or true # resolve with promise returned by handler
    else
      true # nothing to do, resolve promise
```
