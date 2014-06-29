# Implementing Flux in CoffeeScript

The starting point for this code was the Flux TodoMVC example, from which it has
been adapted, taking advantage of some of CoffeeScript's metaprogramming/DSL
sugar.

## [dispatcher.coffee](dispatcher.coffee)
The Dispatcher in Flux is a singleton, against which the stores register handlers.

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




## [store.coffee](store.coffee)

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
`@action` is provided for convenience when defining actions on Store subclasses.
```coffee
  @action: (name, handler) ->
    @actions ?= {}
    @actions[name] = handler.bind(@)
```
The `receiveDispatch` method is provided by the store to be bound by the
dispatcher. It catches errors thrown in the handlers, returning `false` to cause
the corresponding dispatch promise for this store to reject. If the handler
returns a promise itself (eg. created by `waitFor`) it is passed on, otherwise
`true` is returned to resolve the corresponding promise in the dispatcher.
```coffee
  @receiveDispatch: ({action} = payload) ->
    actionHandler = @actions[action.actionType]
    if actionHandler?
      try
        result = actionHandler(action)
      catch err
        false # reject promise
      finally
        result or true # resolve with promise returned by handler (or true)
    else
      true # nothing to do for this store, resolve promise
```

Now we have our Dispatcher singleton and Store base class, we can implement
a concrete store with actions as an example of how these elements would be
combined in a real application. For this example we'll implement a store
representing a queue of notifications to be shown to the user.

## [notification/store.coffee](example/notification/store.coffee)
The notification store makes use of the dispatcher, which it gains access to
via `require`, which returns a reference to the singleton.
```coffee
{after} = require 'method-combinators'
findIndex = require 'find-index'

Dispatcher = require 'flux-coffee/dispatcher'
Store = require 'flux-coffee/store'
```

The actual notification data is stored inside the module closure but outside of
the store singleton class so that it is not directly accessible by the rest of
the application, and must instead be accessed via actions and getters.
```coffee
_notificationQueue = []
```

The concrete notification store subclasses `Store`, and provides a 'name'
property, which is used to register it against the dispatcher.
```coffee
class NotificationStore extends Store
  @name: 'NotificationStore'
```
`after`, from @raganwald's
[method-combinators](https://github.com/raganwald/method-combinators),
is used to create a decorator for the actions which trigger a change event.

```coffee
  # combinator to emit change event after handler
  @withChange: after => @emitChange()
```
The `@action` class method is invoked in the executable class body to define
actions with handlers for each of the actions the store can respond to.
```coffee
  @action 'NOTIFICATION_CREATE', @withChange (action) ->
    _notificationQueue.push action.notification

  @action 'NOTIFICATION_DESTROY', @withChange (action) ->
    _notificationQueue.splice(findIndex(_notificationQueue, (item) -> item.id is action.id)), 1)
```
Additionally, a getter is provided to make relevant data accessible to the rest
of the application.
```coffee
  @getCurrentNotification: -> _notificationQueue[0]
```

Finally, the store is registered with the dispatcher, so that it can respond to
dispatched actions.
```coffee
Dispatcher.register NotificationStore
```


## [notification/actions.coffee](example/notification/actions.coffee)
In addition to the store, a public API of semantic actions is provided for the
rest of the application to use to manipulate the store.
```coffee
Dispatcher = require 'flux-coffee/dispatcher'

class NotificationActions
  @addNotification: (id, text) ->
    payload =
      action:
        actionType: 'NOTIFICATION_CREATE'
        id: id
        text: text
    Dispatcher.dispatch(payload)

  @removeNotification: (id) ->
    payload =
      action:
        actionType: 'NOTIFICATION_DESTROY'
        id: id
    Dispatcher.dispatch(payload)

module.exports = NotificationActions
```
