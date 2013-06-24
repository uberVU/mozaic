define ['cs!channels_utils'], (channels_utils) ->

    class WidgetChannelsMixin
        ###
            This class contains all data channel interaction code from
            mozaic widgets. A channel is basically a Backbone collection
            that is managed by the Mozaic datasource.
        ###

        addChannel: (channel, dict, sync = true) ->
            ###
                Adds a new model to the collection represented by the channel name
            ###

            # Translate the channel using the channel mapping received
            # from the controller.
            translated_channel = channels_utils.translateChannel(channel, @channel_mapping)

            # Crunch the "sync" argument in the updates dict
            dict['__sync__'] = sync

            pipe = loader.get_module('pubsub')
            pipe.publish('/add', translated_channel, dict)

        modifyChannel: (channel, dict, options = {}) ->
            ###
                Request a modification of a certain data channel.
                If new_value is true, the sent value is the new value
                of the parameters for the data channel (e.g., internal
                parameters are reset).

                @param {String} channel
                @param {Object} dict
                @param {Object} options
                @param {String} [options.update_mode = 'append']
                                    Appends the parameters to existing ones
                                    (possibly overwriting them)
                @param {String} [options.update_mode = 'reset']
                                    Makes these the actual parameters
                                    (and updates the old values)
                @param {String} [options.update_mode = 'exclude']
                                    Excludes these parameters
                                    (deletes them from the current parameters)
                @param {Boolean} [options.already_translated]
                                    The channel is already in GUID form, don't
                                    bother to translate it
                @param {Boolean} [options.sync]
                                    Decides whether a server sync should be done (POST/PUT),
                                    or only a local update of the backbone model. Note:
                                    the local model update is also done if sync = true,
                                    but *AFTER* the server response has come back.
                @param {Boolean} [options.silent]
                                    Decides whether the local backbone model update (which
                                    is done regardless of the sync flag) should be done
                                    silently or not.
                @param {Object} [options.filter]
                                    A collection of filters to select which objects from
                                    collection will be updated

                How to use this:
                @modifyChannel('/mention/123', {title: 'new title'})
                @modifyChannel('/mentions_count', {count: 123})
            ###

            options = _.defaults(options,
                update_mode:        'append'
                already_translated: false
                sync:               true
                silent:             false)

            # Translate the channel using the channel mapping received
            # from the controller.

            if not options.already_translated
                translated_channel = channels_utils.translateChannel(channel, @channel_mapping)
            else
                translated_channel = channel

            # Replace tokens in the translated channel with tokens from params
            # This will allow us to post modifications to stuff like /mention/{{id}}
            replaced_channel = @replaceTokensWithParams(translated_channel)

            pipe = loader.get_module('pubsub')
            pipe.publish('/modify', replaced_channel, dict, _.pick(options, 'update_mode','sync','silent', 'filter'))


        deleteChannel: (channel, options = {sync: true}) ->
            ###
                Delete a model from the channel. The channel argument should be
                of this form: '/folders/123', as it contains the id of the model
                to be deleted
            ###

            # Translate the channel using the channel mapping received
            # from the controller.
            translated_channel = channels_utils.translateChannel(channel, @channel_mapping)

            pipe = loader.get_module('pubsub')
            pipe.publish('/delete', translated_channel, options)

        scrollChannel: (channel) ->
            ###
                Publish the scroll event on pubsub for
                the specified channel argument
            ###
            translated_channel = channels_utils.translateChannel(channel, @channel_mapping)

            pipe = loader.get_module('pubsub')
            pipe.publish('/scroll', [translated_channel])

        refreshChannel: (channel, params = null, already_translated = false) ->
            ###
                Shortcut for refreshing a single channel.
                See refreshChannels for more info.
            ###
            if not params
                @refreshChannels([channel], already_translated)
            else
                dict = {}
                dict[channel] = params
                @refreshChannels(dict, already_translated)

        refreshChannels: (channels, already_translated = false) ->
            ###
                Request a refresh of certain data channels to which this widget is subscribed.
                Note! This method will not work for channels the widget is not subscribed to!

                The method of the widget corresponding to the channel will be called
                back whenever the data is available.
            ###

            # We want to refresh an array of channels without any parameters at all
            if $.isArray(channels)
                if already_translated
                    translated_channels = channels
                else
                    [translated_channels] = [@channel_mapping[channel] for channel in channels]
                pipe = loader.get_module('pubsub')
                pipe.publish('/refresh', translated_channels)
            # We want to refresh a dict with keys = channels and values = params for refresh
            else if $.isPlainObject(channels)
                if already_translated
                    translated_channels = channels
                else
                    translated_channels = {}
                    for k, v of channels
                        translated_channels[@channel_mapping[k]] = v
                pipe = loader.get_module('pubsub')
                pipe.publish('/refresh', translated_channels)

        subscribeToChannel: (channel, type, params) =>
            ###
                Subscribes the current widget to a new channel. There are
                2 main use-cases here:

                1) conditionally decide whether to subscribe to notifications
                   to a channel that is passed on inject

                   @subscribeToChannel('/social_profiles')

                2) create a new channel and subscribe to it immediately.

                   @subscribeToChannel('/social_profiles_for_posting',
                                       '/social_profiles',
                                       {'parent_id': 1234})

                For the second use-case, note that the local alias of the
                widget might be different from the channel type name as defined
                in datasource.js (social_profiles_for_posting vs.
                social_profiles).
            ###

            # Prevent widgets from subscribing 2 times to the same
            # channel. The behaviour is unpredictable in this case.
            # However, we do support use-cases like this:
            #
            # subscribed_channels: ['/mentions', '/mentions/123']
            if _.contains(@subscribed_channels, channel)
                logger.warn("Widget #{@params.widget_id} is already " +
                            "subscribed to #{channel}")
                return null

            # Prevent widgets from subscribing to global channels at
            # runtime. It should not be their decision to be subscribed
            # to channels like this, but rather that of the one who injects
            # the widget. Widgets should be kept reusable to the max.
            if channels_utils.isGlobal(channel)
                logger.error("Widget #{@params.widget_id} is not allowed to " +
                             "subscribe to global channel #{channel} at runtime")
                return null

            # Use-case # 2 - subscribe to a newly created channel. What
            # differs in this case is that we need to create a channel
            # and add it to channel mapping.
            if type?
                # Make sure that the channel we're trying to create doesn't
                # already exist in channel_mapping.
                if channel of @channel_mapping
                    logger.error("Widget #{@params.widget_id} already has " +
                                 "channel #{channel} in its channel mapping")
                    return null

                channel_params = {}
                channel_params[type] = params
                [channel_uid] = Utils.newDataChannels(channel_params)
                @channel_mapping[channel] = channel_uid
            else
                # Check that the channel is indeed in the channel mapping.
                if not (channel of @channel_mapping)
                    logger.error("Widget @{params.widget_id} wants to " +
                                 "subscribe to channel #{channel} not " +
                                 "present in channel_mapping!")
                    return null

            # Now we only need to add the channel to subscribed-channels,
            # no matter what.
            @subscribed_channels.push(channel)
            logger.info("Widget #{@params.widget_id} is successfully "
                        "subscribed to #{channel}")

            return @channel_mapping[channel]

       _translateGlobalChannelsFromChannelMapping: ->
            ###
                Alter @channel_mapping by translating the global channels
                contained within. This means that for the DataSource and
                for the widget itself, the existence of global channels
                will be completely transparent.
            ###
            for channel, channel_guid of @channel_mapping
                if channels_utils.isGlobal(channel_guid)
                    @channel_mapping[channel] = channels_utils.translateGlobalChannel(channel_guid)
