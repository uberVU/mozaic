define ['cs!channels_utils'], (channels_utils) ->

    class WidgetBackboneEventsMixin
        ###
            This class contains all state-changing and loading-related
            code of the core widget functionality.
        ###

        _translateEventParams: (item_type, event_type, params...) ->
            ###
                Translates event parameters from a list to a map given the event type.
            ###

            # If widget is detached from DOM, stop propagating events to it.
            if @isDetachedFromDOM
                return null

            if item_type == 'collection'
                if event_type == 'add'
                    return {type: 'add', model: params[0], collection: params[1], options: params[2]}
                else if event_type == 'remove'
                    return {type: 'remove', model: params[0], collection: params[1]}
                else if event_type == 'reset'
                    if params[0].collection_type == 'api'
                        return {type: 'reset', model: params[0]}
                    else
                        return {type: 'reset', collection: params[0]}
                else if event_type == 'destroy'
                    return {type: 'destroy', model: params[0], collection: params[1]}
                else if event_type == 'sync'
                    if params[0].collection_type == 'api'
                        return {type: 'sync', model: params[0]}
                    else
                        return {type: 'sync', collection: params[0]}
                else if event_type == 'error'
                    return {type: 'error', model: params[0], collection: params[1], response: params[2]}
                else if event_type == 'change'
                    # For API channels, the first parameter is the collection
                    if params[0].collection_type == 'api'
                        translated_event_params = {type: 'change', model: params[0]}
                    # Otherwise, for relational channels, we have
                    # a model and an optional collection
                    else
                        translated_event_params = {type: 'change', model: params[0]}
                        model = params[0]
                        if model.collection?
                            translated_event_params['collection'] = model.collection
                    return translated_event_params
                else if event_type == 'no_data'
                    # For Relationnal channels when the server response has length 0
                    translated_event_params = {type: 'no_data', collection: params[0]}
                else if event_type[0..6] == 'change:'
                    return {type: 'change_attribute', attribute: event_type[7..], model: params[0], collection: params[0]?.collection}
                else if event_type == 'invalidate'
                    # When triggering invalidate the order of params is as such:
                    # trigger('invalidate', model, collection). The model can
                    # be null when we trigger invalidate on a collection before
                    # fetching it's data.
                    # This is only for relational channels, for API channels
                    # the first parameter of the event is the collection.
                    if params[0]? and params[0].collection_type == 'api'
                        return {type: 'invalidate', model: params[0]}
                    # For relational channels, the parameters are model & collection
                    else
                        return {type: 'invalidate', model: params[0], collection: params[1]}
            else if item_type == 'item'
                if event_type == 'all'
                    return {type: 'change', model: params[0]}
                else if event_type == 'change'
                    model = params[0]
                    translated_event_params = {type: 'change', model: model}
                    # Pass the collection of the model as an argument if it exists
                    if model.collection?
                        translated_event_params['collection'] = model.collection
                    return translated_event_params
                else if event_type[0..6] == 'change:'
                    return {type: 'change_attribute', attribute: event_type[7..], model: params[0], collection: model: params[0]?.collection}
                else if event_type == 'error'
                    return {type: 'error', model: params[0], response: params[1]}
                else if event_type == 'invalidate'
                    return {type: 'invalidate', model: params[0]}
                else if event_type == 'no_data'
                    # For API channels when the server response is {} (empty)
                    return {type: 'no_data', collection: params[0]}
                else if event_type == 'sync'
                    return {type: 'sync', model: params[0], response: params[1]}
                else if event_type == 'remove'
                    return {type: 'remove', model: params[0], collection: params[1], response: params[2]}
                else if event_type == 'destroy'
                    return {type: 'destroy', model: params[0], collection: params[1], response: params[2]}

        _setupEventParamsTranslation: ->
            ###
                Sets up event parameter translation from backbone.js format to our own.

                This is done by creating a new function for each event.
            ###

            overwritten_functions = {}
            for channel in @_getSubscribedChannels()
                [collection, item, events] = channels_utils.splitChannel(channel)
                collection = channels_utils.getChannelKey(channel)
                do(channel, collection, item, events) =>
                    # Get which method of the widget is responsible for events
                    # of this data channel.
                    method = channels_utils.widgetMethodForChannel(@, collection)

                    # Don't overwrite the same function twice (for example, render)
                    if not (method of overwritten_functions)
                        overwritten_functions[method] = true
                        old_fn = @[method]
                        if old_fn
                            # If user is subscribing to a collection's events
                            if item == 'all'
                                # All events of a collection => first param of the function is the event type
                                if events == 'all'
                                    @[method] = (event_type, params...) =>
                                        translated_params = @_translateEventParams('collection', event_type, params...)
                                        if translated_params
                                            old_fn(translated_params)
                                # A specific event of a collection => event type is taken from channel
                                else
                                    @[method] = (params...) =>
                                        translated_params = @_translateEventParams('collection', events, params...)
                                        if translated_params
                                            old_fn(translated_params)
                            # A specific item of a given collection
                            else
                                # All events of an item of a collection
                                if events == 'all'
                                    @[method] = (event_type, params...) =>
                                        translated_params = @_translateEventParams('item', event_type, params...)
                                        if translated_params
                                            old_fn(translated_params)
                                # A set of events of an item of a collection
                                else
                                    @[method] = (params...) =>
                                        translated_params = @_translateEventParams('item', events, params...)
                                        if translated_params
                                            old_fn(translated_params)
