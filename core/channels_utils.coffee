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

        contains_channel: (channel_list, channel) ->
            ###
                Check if a channel is present in the given channel_list. E.g

                channels_utils.contains_channel(
                   ["/social_posts/{{id}}", "/social_profiles", "/users/{{account_id}}"]
                   '/users'
                )
                -> true
            ###
            channel_name = channels_utils.splitChannel(channel)[0]
            for ch in channel_list
                ch_name = channels_utils.splitChannel(ch)[0]
                return true if channel_name == ch_name
            false

        createGlobalChannel: (alias, params, type) ->
            ###
               Creates a global channel of the given type with the given params
               under the given alias. Global channels will have the "eternal"
               flag on - a.k.a. they will never be garbage collected even though
               there are no widgets subscribed to them.

               The channel_alias -> channel_id mapping should be stored
               in the Mozaic global object.

               The result of the function is the channel id of the newly created
               channel because we might need to use it right away.
            ###

            # By default, if not type is specified, alias is the type of channel
            type = type or alias
            params = params or {}

            # Make sure that Mozaic.global_channels key exists
            Mozaic.globalChannels = Mozaic.globalChannels or {}

            # Prevent double creation of the same global channel
            if alias of Mozaic.globalChannels
                logger.error("Trying to create global channel for already " +
                             "existing alias: #{alias}")
                return null

            # Create a new channel, and store the uid in the global mapping
            channel_params = {}
            channel_params[type] = _.extend({}, params, {'__eternal__': true})
            [channel_uid] = Utils.newDataChannels(channel_params)
            Mozaic.globalChannels[alias] = channel_uid

            return channel_uid

        getGlobalChannel: (alias) ->
            # Make sure that Mozaic.global_channels key exists
            Mozaic.globalChannels = Mozaic.globalChannels or {}

            # Sanity check for retrieving an unknown global channel
            if not (alias of Mozaic.globalChannels)
                logger.error("Trying to retrieve inexisting " +
                             "global channel: #{alias}")
                return null

            return Mozaic.globalChannels[alias]

        isGlobal: (channel) ->
            ###
                Returns true iff a channel is global.
            ###
            return _.str.startsWith(channel, 'GLOBAL/')

        removeGlobalPrefix: (channel) ->
            ###
                Removes the 'GLOBAL' prefix from a given channel.
            ###
            return channel['GLOBAL'.length...]

        translateGlobalChannel: (channel) ->
            ###
                Given a global channel of the form:

                GLOBAL/social_profiles/123/change

                extract the name of the alias from the channel and translate
                it into the actual channel id of that alias.
            ###

            # Nothing to translate, it's not a global channel
            if not channels_utils.isGlobal(channel)
                return channel

            # Remove the 'GLOBAL' prefix and then use the translateChannel
            # api with a mapping containing a single element.
            channel_without_prefix = channels_utils.removeGlobalPrefix(channel)

            # Split the channel into its components, and perform translation
            channel_key = channels_utils.getChannelKey(channel)
            channel_uid = getGlobalChannel(channel_key)
            if not channel_uid
                return null

            # Prefer to use existing API over calling formChannel directly
            return translateChannel(channel, {channel_key: channel_uid})
