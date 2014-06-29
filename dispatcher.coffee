###
Dispatcher

The Dispatcher is capable of registering handlers and invoking them.
More robust implementations than this would include a way to order the
handlers for dependent Stores, and to guarantee that no two stores
created circular dependencies.
###

{Promise} = require 'bluebird'

###
An object of callbacks provided by stores to receive dispatches, keyed by storeName.
###
_handlers = {}
###
An object of promises (or promise-resolving values) returned by each store's
receiveDispatch handler for the current dispatch, keyed by 'storeName'.
###
_pendingDispatches = {}

class Dispatcher
  ###
  Register a Store's handler so that it may be invoked by an action.
  @param {object} store The store to be registered. It should have a 'name'
    string property and a 'receiveDispatch' function property.
  @return {string} The key of the handler within the _handlers object.
  ###
  @register: (store) ->
    unless typeof store.name is 'string'
      throw new Error("Store should have a 'name' property which is a string")
    unless typeof store.receiveDispatch is 'function'
      throw new Error("Store should have a 'receiveDispatch' property which is a function")

    _handlers[store.name] = store.receiveDispatch.bind(store)

  ###
  dispatch
  @param  {object} payload The data from the action.
  ###
  @dispatch: (payload) ->
    # First create object of promises for handlers to reference.
    _pendingDispatches = {}
    resolves = {}
    rejects = {}

    storeNames = Object.keys(_handlers)
    for storeName in storeNames
      _pendingDispatches[storeName] = new Promise (resolve, reject) ->
        resolves[storeName] = resolve
        rejects[storeName] = reject
    
    # Dispatch to handlers and resolve/reject promises.
    for storeName in storeNames
      handleResolve = ->
        resolves[storeName](payload)
      handleReject = ->
        rejects[storeName](new Error("Dispatcher handler unsuccessful"))
      
      # Callback can return an obj, to resolve, or a promise, to chain.
      # See waitFor() for why this might be useful.
      Promise.resolve(_handlers[storeName](payload)).then(handleResolve, handleReject)

    _pendingDispatches = {} # reset
  
  ###
  Allows a store to wait for the registered handlers of other stores
  to get invoked before its own does.
  This is very useful in larger, more complex applications.
  
  Example usage where StoreB waits for StoreA:
  class StoreA extends Store
    # other methods omitted
    @receiveDispatch: (payload) ->
      # switch statement with lots of cases

  Dispatcher.register StoreA

  class StoreB extends Store
    # other methods omitted
    @receiveDispatch: (payload) ->
      switch payload.action.actionType
        when MyConstants.FOO_ACTION
          Dispatcher.waitFor [StoreA], ->
            # Do stuff only after StoreA's handler returns.

  Dispatcher.register StoreB
  
  It should be noted that if StoreB waits for StoreA, and StoreA waits for
  StoreB, a circular dependency will occur, but no error will be thrown.
  A more robust Dispatcher would issue a warning in this scenario.
  ###
  @waitFor: (dependencies, handler) ->
    selectedPromises = dependencies.map (dependency) ->
      _pendingDispatches[dependency.name] or throw new Error("Unknown waitFor dependency #{dependency.name}")
    Promise.all(selectedPromises).then(handler)

module.exports = Dispatcher
