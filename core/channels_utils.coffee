define [], () ->
    channels_utils =

        splitChannel: (channel) ->
            ###
                Split a channel name into the 3 components: collection, id, events

                Widgets can declare interest in a channel of the form:
                /collection_name/id/events

                * collection_name is mandatory, and is the name of
                    the followed entities (e.g., mentions)
                * id is the ID of the entity followed, or "all" (optional)
                    - /mentions_guid/234 will declare interest in mention with id 234
                    - /mentions_guid/all will declare interest in all mentions
                    If "id" is missing, it is assumed to be "all"
                * events is the type of events to be monitored
                    - "all" for all events
                    - "add/remove/reset/change/etc." for a specific event
            ###
            parts = channel[1..].split('/')
            if parts.length >= 3
                return [parts[0], parts[1], parts[2]]
            if parts.length == 2
                return [parts[0], parts[1], "all"]
            return [parts[0], "all", "all"]

        formChannel: (collection, id, events)->
            ###
                Form a channel name given its components.

                This is the exact opposite of splitChannel().
            ###
            if not collection?
                throw('A channel key requires at least a collection fragment')
            keys = [collection]
            if id?
                keys.push(id)
                keys.push(events) if events?
            return '/' + keys.join("/")

        translateChannel: (channel, mapping) ->
            [collection, id, events] = channels_utils.splitChannel(channel)
            true_collection = mapping['/' + collection]
            channels_utils.formChannel(true_collection[1..], id, events)

        translateChannels: (channels, mapping) ->
            ###
                Translates the channels using the given mapping.
            ###
            result = {}
            for channel in channels
                result[channel] = channels_utils.translateChannel(channel, mapping)
            result

        getChannelKey: (channel) ->
            ###
                Returns the channel key for a specific channel
                (i.e., without the id and events)
            ###
            '/' + channels_utils.splitChannel(channel)[0]

        widgetMethodForChannel: (widget, channel_key, skip_check = false) ->
            ###
                Returns the name of the widget method that is bound
                to a given channel's events.
            ###

            if channel_key[0] == '/'
                method_name = 'get_' + channel_key[1..]
            else
                method_name = 'get_' + channel_key

            return method_name

    return channels_utils
