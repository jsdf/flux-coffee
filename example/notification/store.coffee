{after} = require 'method-combinators'
findIndex = require 'find-index'

Dispatcher = require 'flux-coffee/dispatcher'
Store = require 'flux-coffee/store'

_notificationQueue = []

class NotificationStore extends Store
  @name: 'NotificationStore'

  # combinator to emit change event after handler
  @withChange: after => @emitChange()

  @action 'NOTIFICATION_CREATE', @withChange (action) ->
    _notificationQueue.push action.notification

  @action 'NOTIFICATION_DESTROY', @withChange (action) ->
    _notificationQueue.splice(findIndex(_notificationQueue, (item) -> item.id is action.id)), 1)

  @getCurrentNotification: -> _notificationQueue[0]

# Register to handle all updates
Dispatcher.register NotificationStore

module.exports = NotificationStore
