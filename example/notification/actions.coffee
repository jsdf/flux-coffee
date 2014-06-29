Dispatcher = require('flux-coffee/dispatcher')

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
