# PubSub module
# inspired by Backbone Events + new functionality

# A module that can be mixed in to *any object* in order to provide it with
# custom events. You may bind with `on` or remove with `off` callback functions
# to an event; trigger`-ing an event fires all callbacks in succession.

define [], () ->
    class PubSub
        # Regular expression used to split event strings
        eventSplitter = /\s+/;
        slice = Array.prototype.slice;
        constructor: ->
            @_publishedEvents = {}
        initialize: ->
            logger.info "Initializing PubSub"
            @
        destroy: ->
            logger.info "Destroying PubSub"

        # Bind one or more space separated events, `events`, to a `callback`
        # function. Passing `"all"` will bind the callback to all events fired.
        subscribe: (events, callback, context) ->
            #logger.info "--subscribing to #{events}"

            # Subscribing to an event without providing a callback makes no sense
            return @ if not callback
            events = events.split(eventSplitter)
            calls = @_callbacks or (@_callbacks = {})
            # Create an immutable callback list, allowing traversal during
            # modification.  The tail is an empty object that will always be used
            # as the next node.
            while event = events.shift()
                list = calls[event];
                node = if list then list.tail else {}
                node.next = tail = {}
                node.context = context
                node.callback = callback
                calls[event] = {tail: tail, next: if list then list.next else node}

                if event is 'all'
                    for event of @_publishedEvents
                        #console.error @_publishedEvents[event]
                        for data in @_publishedEvents[event]
                            @publish(event, data)

                else if @_publishedEvents[event]
                    for data in @_publishedEvents[event]
                        @publish(event, data)

            @

        # Publish one or many events, firing all bound callbacks. Callbacks are
        # passed the same arguments as 'publish' is, apart from the event name
        # (unless you're listening on 'all', which will cause your callback to
        # receive the true name of the event as the first argument).
        publish: (events, data) ->
            #logger.info "--publishing to #{events}"
            rest = slice.call(arguments, 1)
            events = events.split(eventSplitter)

            if not (calls = @_callbacks)
                while event = events.shift()
                    @_queueEvent(event, data)
                return @

            all = calls.all
            
            # For each event, walk through the linked list of callbacks twice,
            # first to publish the event, then to publish any 'all' callbacks.
            while event = events.shift()
                # Remove published event after it was 
                i = _.indexOf(@_publishedEvents[event], data)
                if i > -1
                    #logger.info "Remove #{i} from published events '#{event}' event"
                    @_publishedEvents[event].splice(i,1)
                # if the current event is not yet registered, remember it
                if calls[event] is undefined
                    @_queueEvent(event, data)

                if node = calls[event]
                    tail = node.tail
                    while (node = node.next) isnt tail
                        node.callback.apply(node.context or @, rest)

                if node = all
                    tail = node.tail
                    args = [event].concat(rest)
                    while (node = node.next) isnt tail
                        node.callback.apply(node.context or @, args)

            @

        # TODO -> needs to be tested
        # Remove one or many callbacks. If 'context' is null, removes all callbacks
        # with that function. If 'callback' is null, removes all callbacks for the
        # event. If 'events' is null, removes all bound callbacks for all events.
        unsubscribe: (events, callback, context) ->
            logger.info "--unsubscribing from #{events}"

            # No events, or removing *all* events.
            return if not (calls = @_callbacks)
            if not (events or callback or context)
                delete @_callbacks
                @

            if @_publishedEvents[events] not undefined
                delete @_publishedEvents[events]
            

            # Loop through the listed events and contexts, splicing them out of the
            # linked list of callbacks if appropriate.
            events = if events then events.split(eventSplitter) else _.keys(calls)
            while event = events.shift()
                node = calls[event]
                delete calls[event]
                continue if not node or not (callback or context)

                # Create a new list, omitting the indicated callbacks.
                tail = node.tail
                while (node = node.next) isnt tail
                    cb = node.callback
                    ctx = node.context
                    if (callback and cb isnt callback) or (context and ctx isnt context)
                        @subscribe(event, cb, ctx)
            @

        # Create a queue in which put the data for events which will be fired in the future
        _queueEvent: (event, data) ->
            #logger.info "--there is no subscribe channel for '#{event}'' yet. Putting it to waiting queue."
            if @_publishedEvents[event] is undefined
                @_publishedEvents[event] = [data]
            else
                @_publishedEvents[event].push(data)

    return PubSub