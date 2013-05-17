define ['cs!channels_utils'], (channels_utils) ->

    class DataSourceChannelCreateMixin
        ###
            Includes methods around adding data to a datasource channel and
            syncing data with the server
        ###

        addToDataChannel: (channel, dict) ->
            ###
                This gets called whenever a new widget publishes to '/add' channel

            ###
            logger.info "Adding new data to #{channel} in DataSource"
            # Get the collection associated with this channel
            collection = channels_utils.getChannelKey(channel)

            # HACK: determine the sync for this item. It is sent in the
            # dict updates ...
            sync = dict['__sync__']
            delete dict['__sync__']

            model = new @data[collection].model(dict)

            # Based on the sync argument we decide whether we should
            # save the model on the server
            if sync

                # Copy the url of the collection to the model, until the model
                # is appended to the collection. Check BaseModel.url()
                #
                # If collection doesn't have an URL, we will take the vanilla URL
                # from the configuration of the channel and check if it needs
                # any parameters. If it doesn't, we will use it. Otherwise,
                # we will raise an error.
                if not @data[collection].url?
                    channel_config = @_getConfig(collection)
                    if not channel_config.url? or channel_config.url.search(/{{[^{}]*}}/) != -1
                        logger.error("Channel #{collection} doesn't have an URL or it needs params")
                        return
                    collection_url = channel_config.url
                else
                    collection_url = @data[collection].url

                model.urlRoot = collection_url

                # Trigger a custom invalidate event before the
                # model is saved to the server. Backbone.Model emits
                # a sync event if the save was successful
                model.trigger('invalidate', model, null)
                # Instead of adding the model to the collection via .create perform
                # a manual save and if the operation is successful then append the
                # model to the collection. By default collection.create appends
                # the model to the collection even if the model wasn't saved
                # successfully (and we don't want that)
                model.save(model.attributes, {
                    error: (model, response, options) =>
                        # Ignore response if channel was removed in the meantime
                        return unless @reference_data[collection]?
                        # Trigger an error event on the collection, even though the model
                        # is not part of the collection yet. This is a CONVENTION to
                        # ease the work with new models
                        @data[collection].trigger('error', model, @data[collection], response)
                    success: (model, response) =>
                        # Ignore response if channel was removed in the meantime
                        return unless @reference_data[collection]?
                        if _.isArray(response)
                            # Sometimes, we make one single POST which
                            # result in multiple items being created. In
                            # this case, the response will be an array
                            # of individual items, and these should be added
                            # to the channel instead of the original POSTed
                            # model.
                            model_class = @meta_data[collection].model_class
                            for response_item in response
                                model = new model_class(response_item)
                                @data[collection].add(model)
                        else if _.isObject(response)
                            # Update model with attributes to sync from response.
                            @syncModelWithResponse(model, response)
                            # Make sure that we propagate ID of object
                            # coming from server to the actual Backbone Model.
                            # Otherwise, the model freshly added in the collection
                            # will not have an ID and we cannot use it immediately.
                            model.set('id', response.id, {silent: true})
                            @data[collection].add(model)
                        else
                            @data[collection].add(model)
                })
            else
                # Just add the model in the collection
                @data[collection].add(model)
