# PubSub module
# inspired by Backbone Events + new functionality

# A module that can be mixed in to *any object* in order to provide it with
# custom events. You may bind with `on` or remove with `off` callback functions
# to an event; trigger`-ing an event fires all callbacks in succession.

define [], () ->
    class PubSub
        # Regular expression used to split event strings
        eventSplitter = /\s+/
        slice = Array.prototype.slice

        constructor: ->
            @_callbacks = {}
            @_callbacks['all'] = {}

        initialize: ->
            logger.info "Initializing PubSub"

        destroy: ->
            logger.info "Destroying PubSub"

        # Bind one or more space separated events, `events`, to a `callback`
        # function. Passing `"all"` will bind the callback to all events fired.
        subscribe: (events, callback, context) ->
            # Subscribing to an event without providing a callback makes no sense
            return if not callback

            events = events.split(eventSplitter)
            for event in events
                if not (event of @_callbacks)
                    @_callbacks[event] = []
                list = @_callbacks[event]
                list.push({context: context, callback: callback})

        # Publish one or many events, firing all bound callbacks. Callbacks are
        # passed the same arguments as 'publish' is, apart from the event name
        # (unless you're listening on 'all', which will cause your callback to
        # receive the true name of the event as the first argument).
        publish: (events, data, register=false) ->
            rest = slice.call(arguments, 1)
            events = events.split(eventSplitter)

            if not (calls = @_callbacks)
                return

            for event in events
                if calls[event]
                    for node in calls[event]
                        node.callback.apply(node.context or @, rest)
                for node in calls['all']
                    node.callback.apply(node.context or @, rest)

        # Remove one or many callbacks. If 'context' is null, removes all callbacks
        # with that function. If 'callback' is null, removes all callbacks for the
        # event. If 'events' is null, removes all bound callbacks for all events.
        unsubscribe: (events, callback, context) ->
            logger.info "--unsubscribing from #{events}"

            # No events, or removing *all* events.
            return if not (calls = @_callbacks)
            if not (events or callback or context)
                delete @_callbacks

            events = if events then events.split(eventSplitter) else _.keys(calls)

            for event in events
                # If there are no callbacks for this event, bail out.
                if not calls[event]
                    continue

                # If we want to delete all the callbacks for a given event, do it.
                if (not callback) and (not context)
                    delete calls[event]
                    continue

                # If we reached this point, we must remove a non-empty callback
                # from a list of events. This is actually pretty simple:
                # iterate through the list and skip this item
                new_list = []
                for node in calls[event]
                    if node.callback != callback or node.context != context
                        new_list.push(node)
                calls[event] = new_list

    return PubSub