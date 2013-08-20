define [
    'cs!mozaic_module',
    'cs!channels_utils',
    'cs!core/datasource/channel',
    'cs!core/datasource/channel/create',
    'cs!core/datasource/channel/read',
    'cs!core/datasource/channel/update',
    'cs!core/datasource/channel/destroy',
    'cs!core/datasource/refresher',
    'cs!core/datasource/scheduler',
    'cs!core/datasource/gc',
    'cs!core/datasource/widget'
],(
    Module,
    channels_utils,
    DataSourceChannelMixin,
    DataSourceChannelCreateMixin,
    DataSourceChannelReadMixin,
    DataSourceChannelUpdateMixin,
    DataSourceChannelDestroyMixin,
    DataSourceRefresher,
    DataSourceScheduler,
    DataSourceGCMixin,
    DataSourceWidgetMixin
) ->

    class DataSource extends Module

        checkIntervalForUnusedChannels: 10000
        default_max_refresh_factor: 10

        constructor: ->
            # Call super in order to get mixin functionality
            super()

            @config = App.DataSourceConfig

            # Pre-process channel definitions in order to factor in
            # channel templates. This will allow us to write less
            # for very similar channels and group the common properties
            # together.
            #
            # Moreover, channel templates support the notion of parent,
            # so that there is actually a 3-level hierarchy:
            # parent of channel template - channel template - channel def
            for k, v of @config.channel_templates
                if v.parent
                    if not (v.parent of @config.channel_templates)
                        logger.error("Channel template #{k} has invalid parent #{v.parent}")
                        continue
                    parent = @config.channel_templates[v.parent]
                    @config.channel_templates[k] = _.extend({}, parent, v)

            for k, v of @config.channel_types
                if v.template
                    if not (v.template of @config.channel_templates)
                        logger.error("Channel type #{k} has invalid template #{v.template}")
                        continue
                    template = @config.channel_templates[v.template]
                    @config.channel_types[k] = _.extend({}, template, v)

        initialize: ->
            logger.info "Initializing data source"

            # Create a big collection hash which stores all the models,
            # collections and data which will be rendered
            @data = {}
            @meta_data = {}
            @reference_data = {}

            # Setting this to false will cause all fetches to perform
            # synchronous ajax requests (used only for testing).
            @_async_fetches = true

            # Subscribe DataSource to the new widget channel.
            # This will make it subscribe widgets to changes for the data they are monitoring.
            @pipe = loader.get_module('pubsub')

            # Requests for new data channels (coming from widgets / controllers).
            @pipe.subscribe('/new_data_channels', @newDataChannels)

            # Announcements that new widgets are available
            # This binds the widgets' methods to the proper channel events
            # (we need this because channels are private to the DataSource)
            @pipe.subscribe('/widget_ready', (data) => @newWidget(data))

            # Announcements that widgets were removed
            # This binds the widgets' methods to the proper channel events
            # (we need this because channels are private to the DataSource)
            @pipe.subscribe('/destroy_widget', (data) => @destroyWidget(data))
            setInterval(@checkForUnusedChannels, @checkIntervalForUnusedChannels)

            # Requests for scrolling channels
            @pipe.subscribe('/scroll', @pushDataAfterScroll)

            # Requests for refreshing data of a given channel
            @pipe.subscribe('/refresh', @pushDataAfterRefresh)

            # Requests for modifying a given data channel
            @pipe.subscribe('/modify', @modifyDataChannel)

            # Requests for adding new data to a given channel
            @pipe.subscribe('/add', @addToDataChannel)

            # Requests for deleting data from a given channel
            @pipe.subscribe('/delete', @deleteFromDataChannel)

        newDataChannels: (channels) =>
            ###
                Create some new data channels on-demand.

                Controllers and widgets usually issue this kind of request,
                in order to decide which data sources to "glue" to their
                subordinated widgets on their page.
            ###

            logger.info "Initializing new channels in DataSource"
            for channel_guid, channel_data of channels
                do(channel_guid, channel_data) =>
                    # If the channel is already initialized, do nothing,
                    # otherwise initialize the associated collection.
                    if channel_guid of @data
                        return

                    logger.info("Initializing channel #{channel_guid}")

                    channel_type = channel_data.type
                    channel_params = _.clone(channel_data.params)

                    # Cannot use @_getType() because channel doesn't exist yet.
                    if channel_type of @config.channel_types
                        # Create reference data synchronously, in order for it
                        # to be available ASAP, e.g. on /new_widget events
                        # In theory, this won't longer be needed after we fix
                        # issue https://github.com/uberVU/mozaic/issues/54
                        @reference_data[channel_guid] =
                            # Create the reference data of a channel with an
                            # empty object for referencing all widgets that
                            # will be subscribed to that channel at any
                            # specific point in time
                            widgets: []

                        resource_type = @config.channel_types[channel_type].type
                        if resource_type == 'relational'
                            @_initRelationalChannel(channel_guid, channel_type, channel_params)
                        else if resource_type == 'api'
                            @_initApiChannel(channel_guid, channel_type, channel_params)
                    else
                        logger.error("Trying to initialize channel of unknown type: #{channel_type}")

        syncModelWithResponse: (model, response, silent = true) ->
            ###
                Given a model and a response, if the
                model has a sync_with_server list,
                look each field in the response and
                overwrite it in the model, if it exists.
            ###
            return unless $.isArray(model?.sync_with_server)

            obj = {}
            for field in model.sync_with_server
                if field of response
                    obj[field] = response[field]
            model.set(obj, { silent: silent })

        destroy: ->
            logger.info "Destroying data source"

        _getChannelDuplicates: (channel_guid) =>
            ###
                Determines all duplicates of some channel. Returns a list
                of channel_guids, or an empty list, if not duplicates are found.
            ###
            duplicates = [ ]
            channel_data = @meta_data[channel_guid]
            for other_channel_guid, other_channel_data of @meta_data
                if channel_guid != other_channel_guid and
                   channel_data.type == other_channel_data.type and
                   _.isEqual(channel_data.params, other_channel_data.params)
                    duplicates.push(other_channel_guid)
            return duplicates

        _finishChannelInitialization: (channel_guid) =>
            ###
                Channel initialization ends with one of the following outcomes,
                depending on existence of channel duplicates:
                    1) if no duplicates exist => fetch
                    2) if duplicates exist and some have data => clone
                    3) if duplicates exist but none have data => wait
                Waiting for data only happens when a duplicate exists that
                does not have data (yet). That channel is currently waiting
                for data (in fetching state), and when it receives data, it
                will fill this channel as well (via _fillWaitingChannels).
            ###
            # Get the channel's start_immediately configuration. It tells us
            # whether we should fetch channel data from server right after
            # channel instantiation. Defaults to true
            start_immediately = @_getConfig(channel_guid).start_immediately
            if not start_immediately?
                start_immediately = true

            # Cloning / fetching logic:
            duplicates = @_getChannelDuplicates(channel_guid)
            if duplicates.length == 0 or @_getConfig(channel_guid).disable_clone
                # 1) No channel duplicates exist, perform fetch.
                refresh_interval = @_getRefreshInterval(channel_guid)
                if refresh_interval > 0
                    if start_immediately
                        # Fetch the initial data for the channel
                        @_fetchChannelDataFromServer(channel_guid)
                else
                    # Fetch the initial data for the channel
                    if not @meta_data[channel_guid].populate_on_init and start_immediately
                        @_fetchChannelDataFromServer(channel_guid)
                    else
                        # If this channel was populated on init, mark it
                        # as having data.
                        @meta_data[channel_guid].last_fetch = Utils.now()
            else
                # If at least one duplicate was fetched (has data), use it
                # as a cloning source. Otherwise, this channel will wait
                # for data.
                duplicate_channel_guid = null
                for other_channel_guid in duplicates
                    if @meta_data[other_channel_guid].last_fetch?
                        duplicate_channel_guid = other_channel_guid
                        break
                if duplicate_channel_guid
                    @_cloneChannel(channel_guid, duplicate_channel_guid)
                else
                    logger.info "Channel #{channel_guid} is waiting for data"

            # Setup periodic refresh if needed.
            @_startRefreshing(channel_guid)

            # Announce widget starter a new channel is available
            @pipe.publish('/initialized_channel', {name: channel_guid})

    DataSource.includeMixin(DataSourceChannelMixin)
    DataSource.includeMixin(DataSourceChannelCreateMixin)
    DataSource.includeMixin(DataSourceChannelReadMixin)
    DataSource.includeMixin(DataSourceChannelUpdateMixin)
    DataSource.includeMixin(DataSourceChannelDestroyMixin)
    DataSource.includeMixin(DataSourceRefresher)
    DataSource.includeMixin(DataSourceScheduler)
    DataSource.includeMixin(DataSourceGCMixin)
    DataSource.includeMixin(DataSourceWidgetMixin)
