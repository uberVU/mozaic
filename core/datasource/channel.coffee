define ['cs!channels_utils'], (channels_utils) ->

    class DataSourceChannelMixin
        ###
            Include methods to initialize a data channel. It will become
            a class ...
        ###

        _initRelationalChannel: (name, type, params) ->
            ###
                Initialize a relational channel.

                A relational channel is backed by a Backbone collection. This
                will dynamically load the collection class via require.js,
                create an instance of the collection class and perform
                final channel initialization logic.
            ###

            # Load the collection class via require.js
            collection_name = @config.channel_types[type].collection or type[1..]
            collection_module = "cs!collection/" + collection_name

            require [collection_module], (collection_class) =>
                @data[name] = new collection_class()
                conf = @config.channel_types[type]
                eternal = params['__eternal__']?
                delete params['__eternal__'] if eternal
                @meta_data[name] =
                    type: type
                    params: params
                    eternal: eternal
                    collection_class: collection_class
                    model_class: @data[name].model
                if conf.populate_on_init and params._initial_data_
                    # Avoid creating empty models
                    if not _.isEmpty(params._initial_data_)
                        @data[name].add(params._initial_data_)
                    delete params._initial_data_
                    # The url of a collection is set after fetching server
                    # data, but for collections with initial data the fetch
                    # branch is not executed. Set the url here.
                    default_value = @_getDefaultParams(name)
                    url_params = _.extend({}, default_value, params)
                    if conf.url?
                        @data[name].url = Utils.render_url(conf.url, url_params)
                # Initialize buffer.
                if conf.buffer_size? and conf.buffer_size
                    @data[name].buffer = new collection_class()
                    # Give access to the collection from the buffer
                    @data[name].buffer.collection = @data[name]
                @_finishChannelInitialization(name)

        _initApiChannel: (name, type, params) ->
            ###
                Initialize an API channel.

                This will only create a raw data object instantly and perform
                final channel initialization logic.
            ###
            # Load the collection class via require.js
            collection_name = @config.channel_types[type].collection or 'raw_data'
            collection_module = "cs!collection/" + collection_name

            require [collection_module], (collection_class) =>
                @data[name] = new collection_class()
                conf = @config.channel_types[type]
                eternal = params['__eternal__']?
                delete params['__eternal__'] if eternal
                @meta_data[name] =
                    type: type
                    params: params
                    eternal: eternal
                    collection_class: collection_class
                # If there is a default value for this channel, set it.
                if 'default_value' of conf
                    @data[name].setDefaultValue(conf.default_value)
                # If the populate_on_init flag is set for this channel, then
                # the parameters sent when creating the channel serve as initial values.
                if conf.populate_on_init or (params.populate_on_init? and params.populate_on_init)
                    if params.populate_on_init?
                        delete params['populate_on_init']
                    @data[name].set(params)
                @_finishChannelInitialization(name)

        _getConfig: (channel) ->
            ###
                Returns the configuration for a given channel.
            ###

            # Get the channel key. This is where the actual data is in @data
            channel_key = channels_utils.getChannelKey(channel)

            # Use @meta_data to find out the actual type of this channel
            channel_type = @meta_data[channel_key].type

            # Finally, retrieve channel type configuration
            @config.channel_types[channel_type]

        _getType: (channel) ->
            ###
                Returns the channel type: relational / api / etc.
            ###
            @_getConfig(channel).type

        _getDefaultParams: (channel) ->
            ###
                Returns the default HTTP params for a given channel.
                This feature is only supported by relational channels for now.

                For API channels, the default_value has a completely different
                meaning: the default value of the JSON data.

                TODO(andrei): refactor this to be less dumb
            ###

            type = @_getType(channel)
            # We only support HTTP params for channels of type relational
            if type != 'relational'
                return {}
            conf = @_getConfig(channel)
            conf.default_value or {}

        _cloneChannel: (channel_guid, source_channel_guid) ->
            ###
                Clones the source channel to channel_guid.
            ###
            logger.info "Cloning #{channel_guid} from #{source_channel_guid}"
            @meta_data[channel_guid].cloned_from = source_channel_guid
            # Mark the new clone as having been recently fetched.
            @meta_data[channel_guid].last_fetch = @meta_data[source_channel_guid].last_fetch
            dest = @data[channel_guid]
            source = @data[source_channel_guid]
            channel_type = @_getType(channel_guid)
            if channel_type == 'relational'
                # Clone model without triggering any events.
                silence = { silent: true }
                for model in source.models
                    dest.add(model.clone(), silence)
                # Trigger the golden news
                dest.trigger('reset', dest)
                # Clone buffer
                if 'buffer' of source
                    for model in source.buffer.models
                        dest.buffer.add(model.clone(), silence)
                # Clone url property
                if 'url' of source
                    dest.url = source.url
            else if channel_type == 'api'
                dest.set(source.data)
