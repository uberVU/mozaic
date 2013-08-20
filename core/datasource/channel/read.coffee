define ['cs!channels_utils'], (channels_utils) ->

    class DataSourceChannelReadMixin
        ###
            Includes methods to read from a http endpoint
        ###

        _afterChannelDataArrived: (channel_key, arrived_content, reason='refresh') ->
            ###
                This function gets called after data is inserted into a
                given channel of the datasource.

                The reasons for this getting called can be multiple:

                - an AJAX request triggered via Backbone.Collections.fetch()
                  has finished (see success callback from
                  _fetchChannelDataFromServer)

                - channel receives data from "initial data" mechanism, where
                  you are able to specify initial data that you got from
                  somewhere else to fill the channel. For example: if you
                  are displaying a list of tweets, and the API endpoint gives
                  you the first 2 replies for each tweet, you can create
                  channels with "initial data" containing those first 2 replies

                - channel receives data from a "brother from another mother",
                  that is it's a cloned channel and his brother already has
                  data.
            ###
            meta = @meta_data[channel_key]

            # Get the collection that has just received items.
            #
            # In the case of streampoll requests, because a stremapoll channel
            # corresponds to 2 Backbone Collections (the normal one, and the
            # buffer one) we have to be careful to select the correct collection
            # on which to run postFetch.
            collection = @data[channel_key]
            if reason == 'streampoll'
                collection = collection.buffer

            # If there are widgets waiting for new items to arrive in the
            # channel, we will subscribe them to the newly arrived models'
            # events right now.
            @_checkForNewlyArrivedAndAwaitedModels(channel_key)

            # If collection has defined a callback for "after data has arrived"
            # call that too. In Mozaic's case, in base_collection, we define
            # this callback in order to propagate the "no data" has arrived
            # event that's missing from Backbone.
            if _.isFunction(collection.postFetch)
                collection.postFetch(arrived_content, meta.params)

            if meta.first_time_fetch
                # Refreshing should only start after data has arrived into the
                # channel for the first time, regardless of the method of
                # arrival.
                @_startRefreshing(channel_key)

            # Since this function is called every time data arrives, make sure
            # that we don't start refreshing the same channel twice (or any
            # other operation that depends on the first arrival of data).
            meta.first_time_fetch = false

        _fetchChannelDataFromServer: (channel, reason='refresh', callback=null) ->
            ###
                Fetch the data for the channel given the params.

                channel: the given channel. The HTTP parameters for fetching
                         the channel data are taken from @meta_data[channel].params
                reason: 'refresh' (default), 'streampoll' or 'scroll'
                callback: a (channel_guid, success) function that will
                          be called after the fetch is complete
                Returns: nothing
            ###

            # Sanity check - the only valid reasons for fetching data are
            # 'refresh', 'scroll' and 'streampoll'.
            if not (reason in ['refresh', 'scroll', 'streampoll'])
                throw "Invalid reason: #{reason}"
                return

            conf = @_getConfig(channel)
            channel_key = channels_utils.getChannelKey(channel)
            meta = @meta_data[channel_key]
            # Streampoll doesn't increment waiting fetch count.
            # Otherwise, when changing tabs periodic requests for new
            # mentions will NEVER stop, which is just plain wrong.
            if reason != 'streampoll'
                waiting_fetches = if meta.waiting_fetches then meta.waiting_fetches else 0
                meta.waiting_fetches = waiting_fetches + 1

            # Build the current parameters. For normal requests,
            # they are the current default values overlapped with
            # the current values (found in @meta_data[channel_key]).
            default_value = @_getDefaultParams(channel)
            params = _.extend({}, default_value, meta.params)

            # If we're fetching on behalf of a scroll / streampoll request,
            # make sure that we give the scroll/streampoll_params function
            # the opportunity to modify the current HTTP params.
            if reason in ['scroll', 'streampoll']
                fn_name = reason + '_params'
                if not (fn_name of conf)
                    logger.error("Configuration for channel #{channel_key} should have function #{fn_name}")
                    return
                # Retrieve the new parameters
                params = conf[fn_name](@data[channel_key], params)
                if not params
                    # Cancel the current streampoll/scroll request if params == null.
                    # Careful - emtpy dict { } evaluates to true in JavaScript!
                    return

                if reason is 'scroll' and _.isEqual(params, meta.last_params)
                    logger.warn("Already scrolled #{channel} with the same" +
                                "params")
                    return

            # Always the last params inside the channel's meta data. Might be
            # useful for comparison when creating new ones for a new request
            meta.last_params = params

            # If the encode_POST_as_JSON flag is set, instead of URL-encoding
            # the parameters as for normal forms, send them encoded as JSON.
            if conf.fetch_through_POST and conf.encode_POST_as_JSON
                params_for_fetch = JSON.stringify(params)
            else
                params_for_fetch = Utils.deepClone params

            # Channel has an associated URL. Fetch data from that URL.
            fetch_params =
                async: @_async_fetches
                # Don't add models on refresh (reset entire collection instead).
                add: reason != 'refresh'
                # For POST requests, the URL should contain no extra GET params,
                # and those params should rather be sent through POST data.
                # This is because we might have large data to POST,
                # and as we all know, the GET URI has a pretty low length limit.
                type: if conf.fetch_through_POST then 'POST' else 'GET'
                data: if conf.fetch_through_POST then params_for_fetch else {}

            # When the data is encoded as JSON, be careful to set the correct
            # content-type.
            if conf.fetch_through_POST and conf.encode_POST_as_JSON
                fetch_params.contentType = 'application/json'

            # Story behind this decision to insert a fetched callback before triggering reset:
            # When you are binding a widget to a collection (datasource._bindWidgetToRelationalChannel)
            # you are doing 2 things:
            # 1. widget is subscribed to all collection events ('reset' included):
            #    - if collection is updated then the widget is notified to refresh contents
            # 2. if the collection is already filled: @meta_data[collection].last_fetch?
            #    then the widget is notified to refresh contents
            # With a fetched event before reset you are setting meta.last_fetch eliminating a race condition
            # where 'reset' event will cause a bindWidgetToRelationalChannel
            # the step 2 above will find last_fetch null thus leaving the widget empty
            fetch_params.fetched = =>
                if reason != 'streampoll'
                    meta.last_fetch = Utils.now()

            # Define success & error functions as wrappers around callback.
            fetch_params.success = (collection, response) =>

                # Ignore response if channel was removed in the meantime
                # One scenario for this happening is a really slow API call
                # while user changes the page and channel gets garbage
                # collected.
                return unless @reference_data[channel_key]?

                if reason != 'streampoll'
                    meta.waiting_fetches = meta.waiting_fetches - 1
                else if @data[channel_key].length is 0
                    # If the collection is empty flush the buffer
                    # so directly so you don't end in a situation where
                    # you have to click "Show new mentions" in order to see
                    # the first mentions of a stream
                    @_flushChannelBuffer(channel_key)

                was_first_fetch = meta.first_time_fetch

                # NOTE: we don't really use "xhr" for collection.parse, and
                # neither does Backbone.js, so we're just leaving it out!
                @_afterChannelDataArrived(channel_key, collection.parse(response, null), reason)

                # callback should not be moved to _afterChannelDataArrived
                # because we're only using it right now to re-schedule new
                # refreshes AFTER an HTTP request. Therefore, it doesn't make
                # sense to call it after we copy data around.
                callback(channel_key, true) if callback

                if was_first_fetch and (not @_getConfig(channel_key).disable_clone)
                    @_fillWaitingChannels(channel_key)

            if callback
                #callback defaults to null in about all calls (just one call
                #sets a value).
                fetch_params.error = (collection, response) =>
                    # Ignore response if channel was removed in the meantime
                    return unless @reference_data[channel_key]?
                    callback(channel_key, false)

            # What channel should receive the data we're about to fetch -
            # the original channel, or that channel's buffer?
            # (The first fetch should always be into the real channel).
            if reason == 'streampoll' and @_getBufferSize(channel) and @meta_data[channel_key].last_fetch?
                receiving_channel = @data[channel_key].buffer
                # If the buffer is full, avoid doing any more fetches.
                if receiving_channel.length >= conf.buffer_size
                    return
            else
                receiving_channel = @data[channel_key]

            # Render the URL to which we're GET-ing or POST-ing.
            receiving_channel.url = Utils.render_url(conf.url, params, [], conf.fetch_through_POST)
            # Trigger a custom invalidate event before fetching the
            # collection from the server (invalidate gets triggered
            # every time a request is made to the server). The format
            # of the event is: model, collection
            receiving_channel.trigger('invalidate', null, receiving_channel)
            receiving_channel.fetch(fetch_params)

        _checkForNewlyArrivedAndAwaitedModels: (channel) ->
            ###
                Checks if some new models which were awaited for have appeared
                into the given channel. If there are, bind the respective
                widgets to the individual models and drop the widget references.
            ###

            # Check if channel still exists
            if not (channel of @meta_data)
                logger.warn("Channel #{channel} has probably been garbage collected too early")
                return

            # Check if channel has pending items to wait for
            if not ('delayed_single_items' of @meta_data[channel])
                return

            remaining_delayed_items = []
            for delayed_item in @meta_data[channel].delayed_single_items
                single_item = @data[channel].get(delayed_item.id)

                # If the item still hasn't appeared, plan it for later re-use
                if not single_item
                    remaining_delayed_items.push(delayed_item)
                    continue
                # Otherwise, do the binding and drop the widget reference
                else
                    @_bindWidgetToRelationalChannel(delayed_item.fake_channel,
                                                    delayed_item.channel,
                                                    delayed_item.widget_data)

            # Check if there are still single items to wait for
            if remaining_delayed_items.length > 0
                @meta_data[channel].delayed_single_items = remaining_delayed_items
            else
                delete @meta_data[channel]['delayed_single_items']

        _fillWaitingChannels: (channel_guid) ->
            ###
                Try to fill each waiting channel that is a duplicate of
                this one.
            ###
            duplicates = @_getChannelDuplicates(channel_guid)
            for dest_channel_guid in duplicates
                if (not @meta_data[dest_channel_guid].last_fetch?) and (@meta_data[dest_channel_guid].waiting_for_cloned_data)
                    # If dest_channel does not yet have data, clone into it
                    # by using this channel as clone source.
                    @_cloneChannel(dest_channel_guid, channel_guid)

        _flushChannelBuffer: (channel_guid) ->
            ###
                Flush channel buffer by moving buffer data into channel data,
                then reset buffer.
            ###
            logger.info "Flushing channel #{channel_guid} buffer"
            channel = @data[channel_guid]

            conf = @_getConfig(channel_guid)
            # Get where to append the buffered items: 'begin' or 'end'
            add_to = conf.streampoll_add_to || 'end'
            # Get the field after which to sort the buffer items
            sort_field = conf.streampoll_sort_field

            # Sort the buffer items before flushing
            channel.buffer.models = _.sortBy(channel.buffer.models, (model) -> model.get(sort_field)) if sort_field?
            # If we add to the beginning, we take the elements in reverse order
            # from the buffer and add each element to the beginning.
            if add_to == 'begin'
                while channel.buffer.length > 0
                    model = channel.buffer.shift()
                    channel.unshift(model)
            # Otherwise, just append the whole buffer to the end of the collection
            else if add_to == 'end'
                # Add all models from buffer into channel, without event silencing.
                channel.add(channel.buffer.models)
                # Reset buffer without triggering any events.
                channel.buffer.reset([])

            @_restartRefreshing(channel_guid)

        _getBufferSize: (channel) ->
            ###
                Returns the buffer size for a given channel (0 for no buffer).
            ###
            conf = @_getConfig(channel)
            # Only streampoll channels may have buffers.
            if conf.refresh_type == 'streampoll' and conf.buffer_size?
                return conf.buffer_size
            else
                return 0
