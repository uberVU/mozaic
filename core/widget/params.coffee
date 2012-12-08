define ['cs!channels_utils'], (channels_utils) ->

    class WidgetParamsMixin
        ###
            This class contains all parameter-related code for
            a Mozaic widget. This includes data_params, events,
            dom elements, etc.
        ###

        _checkChannels: (subscribed_channels, channel_mapping) ->
            ###
                Make a sanity check to see if the constructors receives all the needed
                channels.
                Basically, every item in subscribed_channel list must have a reference
                in channels list.
                The order in which channels are defined should not matter
                eg. :
                      subscribed_channels = ['/mentions', '/tags']
                      channel_mapping = ['/mentions': '/mentions/guid1',
                                         '/tags': '/tags/guid2']
                      return true
            ###
            for subscribed_channel in subscribed_channels
                if not (channels_utils.getChannelKey(subscribed_channel) of channel_mapping)
                    logger.error "Widget #{@params['name']} with id #{@params['id']}"+
                      "is missing #{subscribed_channel}."+
                      "Channel mapping: #{JSON.stringify(channel_mapping)}"
                    return false

            return true

        _initParamsDefaults: ->
            ###
                Initialize widget params default values.
            ###
            # If there is nothing to initialize, just return.
            if not ('params_defaults' of @)
                return

            # First pass is for non-function values
            for k, v of @params_defaults
                # If "this" already has k, it needs no default value
                if k of @
                    continue
                # First pass skips function values to give a more complete
                # view of "this" on the second pass to these functions
                if $.isFunction(v)
                    continue
                if v == 'data-params'
                    if k of @params
                        @[k] = @params[k]
                else
                    @[k] = v

            # Second pass will also run the functions
            for k, v of @params_defaults
                # If "this" already has k, it needs no default value
                if k of @
                    continue
                # This time we execute only functions
                if $.isFunction(v)
                    @[k] = v.apply(@, [@params[k]])

        _checkForRequiredParams: ->
            ###
                Checks that the widget has all necessary required params.
            ###

            # If there is nothing to check, bail out.
            if not ('params_required' of @)
                return

            for p in @params_required
                if not p of @
                    logger.error("Widget #{params['widget_id']} is missing required parameter #{p}")

        _parseDomEvents: ->
            ###
                Parse event keys for variables, if elements are defined.

                You can insert references to _elements_ (explained under
                the renderLayout method) inside _events_ selectors, by
                adding the `@` (at) character in front of their name.

                Example:

                    elements:
                        button: '.button'
                    events:
                        '.click @button': 'buttonClickHandler'

                @see #renderLayout
            ###
            return if _.isEmpty(@elements)
            # Init fresh events object
            events = {}
            for key, handler of @events
                for name, selector of @elements
                    # Create regexp rule to match element name and
                    # replace element name with its selector
                    rule = new RegExp "@#{name}( |$)"
                    key = key.replace rule, "#{selector}$1"
                events[key] = handler
            # Replace events object and get rid of previous keys
            @events = events

        _getTranslatedDomEvents: ->
            ###
                Map Backbone event handler names to actual method
                references from current widget.
            ###
            return if _.isEmpty(@events)
            events = {}
            for key, method of @events
                fn = @[method]
                if _.isFunction(fn)
                    events[key] = fn
            return events

        _parseDomElements: ->
            ###
                Parse the DOM elements whose jQuery selectors are specified
                in @elements. This is a shortcut for avoiding to write
                jQuery selectors all the time.

                This needs to be done every time renderLayout() is called
                because that's when the Dom elements are actually created /
                refreshed.

                Also, if there are post-renderLayout manipulations of the
                DOM, @elements will not work for that.
                # TODO(andrei): find a smarter mechanism to also handle this
                # edge case, something like jQuery.live().
            ###
            if @elements
                for name, selector of @elements
                    @[name] = @view.$el.find(selector)
