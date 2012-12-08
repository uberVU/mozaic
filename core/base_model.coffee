define [], () ->
    class BaseModel extends Backbone.Model

        unsyncable_attributes: []

        # This array is looked up in datasource and the values
        # from sync_with_server are searched in the response
        # and overwritten in the model, if they exist.
        sync_with_server: []

        initialize: ->
            # Add global unsyncable attributes on top of model specific ones
            # TODO: This is commented out for now because the stream wizard
            # depends on it. We should find a way to wire this property through
            # our local channels without sending it to the server
            #@unsyncable_attributes.push('form')

        validate: (attributes, options) ->
            ###
                Check to see if the model is already in collection and
                log this as a warning message
            ###

            # Don't prevent adding an existing item to a collection
            # (because it will throw an error). However, log a message
            # for the developers to know there's something wrong.
            #
            # When this message is logged, it means that we're probably
            # requesting the same data more than once and wasting HTTP requests.
            if options and options.collection and options.collection.get(attributes.id)
                logger.warn("Trying to add an existing model #{attributes.id} " +
                         "(#{JSON.stringify(attributes)}}) to a collection")

            return false

        url: ->
            ###
                Returns the url of the model or the url of the collection
                if the model has not been saved yet.
                http://documentcloud.github.com/backbone/#Model-url
                A model that has not yet been saved will not have a collection
                (this is our usage pattern right now). Fallback to the
                urlRoot of the model in that case
            ###
            if @collection?
                if @id?
                    return Utils.model_url(@collection.url, @id)
                else
                    return @collection.url
            else if @urlRoot?
                if @id?
                    return Utils.model_url(@urlRoot, @id)
                else
                    return @urlRoot
            throw('Set a collection or the urlRoot property on the model')

        getNested: (path) ->
            ###
                @path {String}  Object path e.g. 'user/name'
                @return {Mixed}
            ###
            return Utils.getNestedAttr(this, path)

        getSchema: (schema_name = 'default') ->
            throw('Implement this in your model for form support')

        postCreate: (model) =>
            ###
                Overwrite this in your model in order to ALWAYS run
                code exactly after the model has been successfully saved
                to the server.
            ###
            return

        postUpdate: (model) =>
            ###
                Overwrite this in your model in order to ALWAYS run
                code exactly after the model has been successfully updated
                on the server.
            ###
            return

        postDelete: (model) =>
            ###
                Overwrite this in your model in order to ALWAYS run
                code exactly after the model has been successfully deleted
                from the server.
            ###
            return

        postCUD: (model) =>
            ###
                Overwrite this in your model in order to ALWAYS run
                code exactly after the model has been either created, or
                updated, or deleted.

                If you're concerned with the type of update, you should
                overwrite the more specific methods (postCreate, postUpdate,
                postDelete).
            ###
            return

        save: (key, value, options) ->
            ###
                Overwrite the save method to provide a way to
                black list unwanted local attributes.
                For example we set a folders attribute on a stream
                and that doesn't map to any server attributes, so
                we shouldn't send it.

                Iterate over the unsyncable attributes and unset their
                values before sending the request to the server and
                then set them back once the operation is done.
            ###
            unsynced_values = []
            for attribute in @unsyncable_attributes
                # Keep the current value of the attribute
                # to set it again after the save
                unsynced_values.push(@get(attribute))
                @unset(attribute, { silent: true })
            # Options might not be passed from above
            # Model#save() can be called in three ways:
            # 1. model.save() or
            # 2. model.save(key, value, options)
            # 3. model.save({key: value,...}, options)
            # @see http://backbonejs.org/docs/backbone.html
            # In the third case, `value` param is in fact the options hash,
            # so to overwrite save() we need to check for this case.
            if _.isObject(options) # second call type
                old_success = options.success or $.noop
            if _.isObject(key) # third call type
                old_success = value.success or $.noop

            new_success = (model, response) =>
                (if @isNew() then @postCreate else @postUpdate)(model)
                @postCUD(model)
                old_success(model, response)

            if _.isObject options
                options.success = new_success
            if _.isObject key
                value.success = new_success

            super(key, value, options)
            for attribute, i in @unsyncable_attributes
                # Set the old value back
                @set(attribute, unsynced_values[i], { silent: true })

        destroy: (options) =>
            ###
                Overwrite the destroy method to provide an easy hook
                for models to execute code after the model is successfully
                deleted.
            ###
            options = _.clone(options) or {}
            old_success = options.sucess or =>
            options.success = (model, response) =>
                                  @postDelete(model)
                                  @postCUD(model)
                                  old_success(model, response)
            super(options)

    return BaseModel