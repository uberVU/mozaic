define ['cs!utils/urls', 'cs!utils/time'], (Urls, Time) ->
    Utils =
        title: {}

        guid: (name) ->
            return _.uniqueId(name + '-')

        injectWidget: (el, widget_name, params, extra_classes = null, clean = null, el_type = null, modal = false, prepend = false, before = false, after = false) ->
            ###
                Inject a given widget under the DOM element el, given its name
                and initial params. You can pass an additional modal argument
                to inject the widget in a modal window. The modal will inject the
                html in it's body

                el: the element where the widget will be inserted. should be a jQuery selector
                widget_name: the name/type of the widget
                params: data that will be passed to the widget
                extra_classes: additional css classes, default is none
                clean: specifies if the new widget should replace whatever is in el or be appended to it
                el_type: type of element to be rendered (e.g. div, ul, li)
                prepend: use prepend instead of append
                before: insert BEFORE element (as a sibling of the element)
                after: insert AFTER element (as a sibling of the element)
            ###
            stringified_params = JSON.stringify(params)
            classes = if extra_classes then "uberwidget #{extra_classes}" else "uberwidget"
            type = if el_type then "#{el_type}" else "div"

            # Escape stringified_params to avoid html rendering errors
            stringified_params = _.escape(stringified_params)

            html = "<#{type}
                        class='#{classes}'
                        data-widget='#{widget_name}'
                        data-params='#{stringified_params}'
                    ></#{type}>"

            if not modal
                if clean? and clean
                    el.html(html)
                else
                    if before
                        el.before(html)
                    else if after
                        el.after(html)
                    else if prepend
                        el.prepend(html)
                    else
                        el.append(html)
            else
                pipe = loader.get_module('pubsub')
                title = if params.title? then params.title else widget_name
                pipe.publish('/modal', { html: html, title: title })

        injectLocationList: (el, children, channels) =>
            ###
                Location list insert - this is basically called
                recursively to build the whole location tree.

                Replaces previous location list widget to reduce
                the passing of variables through html propreties,
                and improve overall performance.
            ###
            # Get sorted list out of children
            list = _.sortBy children, (x) -> x.keyword

            for child in list
                # Build location widget params
                params =
                    channels: channels
                    location: child

                # Inject widget
                Utils.injectWidget el, 'location', params, null, null, 'li'

        locationParams: (location = {}) ->
            ###
                Similar to extractLocation and completeLocation,
                but with some small differences:
                1. No continent
                2. All other location fields are required, but any
                other fiend must dissapear.
            ###
            params = {}
            for field in ['country', 'region', 'city']
                params[field] = location[field] or ''
            params

        extractLocation: (dict, also_exclude = false) ->
            ###
                Extract location in the new format from a dict.
            ###
            result = {}
            result.continent = dict.continent if dict.continent
            result.country = dict.country if dict.country
            result.region = dict.region if dict.region
            result.city = dict.city if dict.city
            if also_exclude
                Utils.excludeLocation(dict)
            result

        completeLocation: (location) ->
            ###
                Given a location, make sure it has all the fields.

                This should be used when publishing a new value for locations-related
                filters, because otherwise it would be pretty clumsy to overwrite the
                old values.
            ###
            location.continent = '' if not location.continent
            location.country = '' if not location.country
            location.region = '' if not location.region
            location.city = '' if not location.city
            location

        excludeLocation: (dict) ->
            ###
                Exclude location-related filters from a dict.
            ###
            for k in ['continent', 'country', 'region', 'city']
                if dict[k]
                    delete dict[k]

        getMostSpecificLocation: (location) ->
            ###
                Return the most specific location.
            ###
            if $.isPlainObject(location)
                value = location
            else
                value = JSON.parse(location)
            return value.city if value.city
            return value.region if value.region
            return value.country if value.country
            return value.continent if value.continent
            return ""

        attachCallback: (object, method_names, callback) ->
            ###
                Attach callback to object method(s), that will
                run right after each of the selected methods

                object: The object of the methods
                method_names: Space-separated list of method names
                callback: Callback function to be attached

                TODO: Add extra param for before/after callback positioning
            ###
            methods = (name for name in method_names.split(' ') when object[name])

            for i, name of methods
                # Create different scope for each ref var, otherwise the all
                # the methods would reference to the last assigned value only
                do(name) ->
                    ref = object[name]
                    object[name] = ->
                        return_value = ref.apply(this, arguments)
                        callback()
                        return return_value

        newDataChannels: (types...) ->
            ###
                Returns a set of new data channel GUIDs, given their types.

                How to call this:

                First version - without initial parameters for the data channels
                [mentions, tags, users] = @newDataChannels('/mentions', '/tags', '/users')

                Second version - with initial parameters for the data channels
                [mentions, tags, users] = @newDataChannels({'/mentions': {'gender': 'f', 'sentiment': 'positive'}, '/tags': {}, '/users': {}})

                TODO: fix the flaw that we can't create multiple /mentions channels with the same call.
            ###

            # Make sure that all params are in fact passed as a dict, regardless
            # of the calling convention actually used.
            if $.isPlainObject(types[0])
                types_dict = types[0]
            else
                types_dict = {}
                for type in types
                    types_dict[type] = {}

            channels = {}
            guids = []
            for type, params of types_dict
                guid = Utils.guid(type)
                channels[guid] = {type: type, params: params}
                guids.push(guid)

            # Notify the datasource that we need new channels
            pipe = loader.get_module('pubsub')
            pipe.publish('/new_data_channels', channels)
            guids

        goto: (hashbang, trigger = false) ->
            # Run the navigate() method of backbone router to navigate to the new URL.
            # Make sure we don't trigger a new router match.
            router = loader.get_module('cs!router')
            router.navigate(hashbang, {trigger: trigger})

        notify: (message, type = 'notice') =>
            ###
                Displays a notification message.

                message: the message to display
                type: 'notice', 'error', 'success'
                    (or you can define your own if you
                     target it correctly via CSS)
            ###
            # Get pubsub pipe
            pipe = loader.get_module('pubsub')
            # Publish through /notifications channel
            pipe.publish('/notifications', { type: type, message: message })

        closeModal: ->
            ###
                Close any opened modal window by publishing an empty message
                on the '/closemodal' channel
            ###
            pipe = loader.get_module('pubsub')
            pipe.publish('/closemodal', {})

        _wrapInstanceHelper : (instance, method_name, method) =>
            #create the separate helper so that we don't
            #create a new function object every time we wrap something
            return  () ->
                if App.general.THROW_UNCAUGHT_EXCEPTIONS
                    result = method.apply(instance, arguments)
                else
                    try
                        result = method.apply(instance, arguments)
                    catch error
                        if error == Constants.UNAUTHORIZED_EXCEPTION
                            throw error
                        logger.error("Exception in " + method_name + ":" + error)
                return result

        wrapInstance : (instance) =>
            ###
            wrap an instance object with an error handler
            prevents the interpreter from stopping execution completely on
            uncaught errors
            ###
            for element_name of instance
                #make sure that we are not iterating over a prototype
                #and we actually own the properties
                if instance.hasOwnProperty(element_name)
                    method = instance[element_name]
                    if $.isFunction(method) and not instance[element_name].__super__
                        instance[element_name] = Utils._wrapInstanceHelper(instance, element_name, method)

        createModuleInstance : (Module, params...) ->
            #wrap the new Module() instantiation in order to prevent error propagation
            if !$.isFunction(Module)
                throw "Trying to instantiate something uninstantiable: " + Module
                return
            if App.general.THROW_UNCAUGHT_EXCEPTIONS
                result = new Module(params...)
            else
                try
                    result = new Module(params...)
                catch error
                    if error == Constants.UNAUTHORIZED_EXCEPTION
                        throw error
                    logger.error("Exception trying to instantiate " + Module.name + " with params " + arguments + ":" + error)
            return result

        renderScrollbar: ($el, to) =>
            ###
                Initialize or update tiny scrollbar for the given
                element
            ###
            if $el.length == 0 or !$el.data('tsb')
                $el.tinyscrollbar()
            else
                if to? and $.isNumeric(to)
                    $el.tinyscrollbar_update(to)
                else
                    $el.tinyscrollbar_update('relative')

        mixin: (mixins..., classReference) ->
            ###
                Mixin a class methods into another. Doesn't work with
                our wrapInstanceHelper.

                TODO: It can work if we inspect a
                mixing property of a module in wrapInstanceHelper ...
            ###
            for mixin in mixins
                for key, value of mixin::
                    classReference.key = value
            classReference

        setTitle: (title_params) ->
            ###
                Dinamically modify page title name when navigating through site
                by creating a dict with current page state, keyword_name or/and count
            ###

            # The method can be called with a null parameter when navigating to a
            # new controller, so reset the `count` and `page` parameters, but not `keyword`
            # because the page can have the same action menu and the stream_info widget which
            # sets the keyword_name will not be rendered again.
            if not title_params?
                delete @title.count
                delete @title.page
            else
                # Allow only some parameters to be modified
                allowed_title_parameters = ['keyword', 'count', 'page']
                title_params = _.pick(title_params, allowed_title_parameters...)

                # Extend current title_params with the new title_params
                _.extend @title, title_params

            # A standard page title has the following form:
            #       ({{count}}) {{keyword}} or
            #       {{page}}
            #   Count is set when streampoll gets data (if it is 0 is now shown)
            #   Keyword is the keyword name when we are on a stream / tw / fb / signal page
            #   and is set by the stream_info widget
            #   Page is the page name for Tasks, Tags, Reports ..

            title = window.user.whitelabel
            title = 'uberVU' if title is 'ubervu'

            if @title.page
                title = @title.page
                delete @title.keyword
            else if @title.keyword
                count = if @title.count? then "(#{@title.count})" else ''
                title = [count, "#{@title.keyword}"].join(' ')

            window.document.title = title

        getSocialProfilePlatformsFromIds: (ids = [], parent = '.posting-account-list') ->
            ###
                Get social platform names from profile IDs
            ###
            platforms = []

            # Iterate through all parent selector's children
            $(parent).find('> li').each ->

                # Ignore if ID of current item not selected
                if ids.indexOf($(@).data('value')) == -1
                    return

                # Get platform of current item
                platform = $(@).data('platform')

                # Add platform to list if not already present
                if platforms.indexOf(platform) == -1
                    platforms.push platform

            # Return platform names
            platforms

        getSocialPostContentLimit: (profiles = []) ->
            ###
                Calculate char limit for selected profiles
            ###
            limits = Constants.SOCIAL_PLATFORM_LIMITS
            limit = false

            for profile in profiles

                # Ignore profile if limit is not defined
                if not limits[profile]
                    continue

                # Set limit value directly, if not previosly defined
                if not limit
                    limit = limits[profile]

                # Compare with previous value and settle on min value
                limit = Math.min limit, limits[profile]

            # Return found limit
            limit

        titleize: (name, opts = {}) =>
            words = name.split ' '
            keepLowerCase = opts.keepLowerCase || ['and', 'the', 'of']
            titleWords = _.map words, (w) ->
               if _.indexOf(keepLowerCase, w.toLowerCase()) != -1
                   return w.toLowerCase()
               else
                   return _.str.titleize w
            
            return titleWords.join ' '

        getSocialPostContentCharsLeft: (content, limit) =>
            ###
                Calculate remaining chars available for
                specific platform limits
            ###
            # Return null count if no limit is passed
            if typeof(limit) != 'number'
                return null

            # Trim right side
            content = content.replace /\s+$/, ''

            # Get original length
            length = content.length
            
            # Identify and remove extra link length, if
            # limit set to Twitter limit (140)
            ###
                We're matching a smaller than or equal Twitter
                limit because we might receive a smaller limit
                when a link is set. This shouldn't be a problem
                as long as there isn't any social platform with
                a smaller limit than Twitter. (not likely)
            ###
            if limit <= Constants.SOCIAL_PLATFORM_LIMITS.twitter
                # Process found links
                if matches = content.match(/https?:\/\/[a-z0-9-\.\/]+([a-z0-9\/])/g)
                    for match in matches
                        length -= match.length - Utils.getTwitterLinkLength(match)

            # Return chars left
            limit - length

        getTwitterLinkLength: (link) ->
            ###
                Calculate the length of twitter links after
                being processed by the t.co shortener

                Read more at https://dev.twitter.com/docs/tco-link-wrapper/faq
                
                Warning: It is supposed to increase in mid-August 2012
                Maybe in the future we make a help/configuration call
                first, to make sure we have the right length, for now
                we use Constants.TWITTER_LINK_LENGTH
            ###
            length = Constants.TWITTER_LINK_LENGTH

            # Increase length by one for https protocol
            if link.match(/^https/)
                length += 1

            # Return the smallest of the twitter length limit
            # or the actual length of the link
            Math.min(link.length, length) 

    # Extend Utils with other utils functions (see utils/ dir) in order
    # to keep the same Utils.method() interface.
    _.extend(Utils, Urls)
    _.extend(Utils, Time)

    window.Utils = Utils
    return Utils
