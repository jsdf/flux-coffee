###
Store
###

extend = require 'xtend/mutable'

CHANGE_EVENT = 'change'

class Store
  extend(@, EventEmitter::)

  # implement in subclass
  # @name: 'Store'
   
  ###
  Define an action handler for this store
  @param {string} name The name of the action.
  @param {function} handler A function to handle the action, which takes the 
    action object as a parameter and throws if the action fails, or returns a
    Promise (created by Dispatcher.waitFor) if the action has dependencies.
  ###
  @action: (name, handler) ->
    unless typeof name is 'string'
      throw new Error("Missing action name string parameter")
    unless typeof handler is 'function'
      throw new Error("Missing action handler function parameter")

    @actions ?= {}
    @actions[name] = handler.bind(@)

  ###
  Register a Store's handler so that it may be invoked by an action.
  @param {object} payload The dispatch payload, including an 'action' object 
    property which in turn has an 'actionType' string property.
  @return {(Promise|boolean|null)} A promise-resolving/rejecting value
  ###
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

  @emitChange: ->
    @emit CHANGE_EVENT

  ###
  @param {function} callback
  ###
  @addChangeListener: (callback) ->
    @on CHANGE_EVENT, callback
  
  ###
  @param {function} callback
  ###
  @removeChangeListener: (callback) ->
    @removeListener CHANGE_EVENT, callback

module.exports = Store
