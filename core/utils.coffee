define ['cs!utils/urls', 'cs!utils/time', 'cs!utils/dom', 'cs!utils/images', 'cs!utils/misc'], (Urls, Time, Dom, Images, Misc) ->
    Utils =
        title: {}

        guid: (name) ->
            return _.uniqueId(name + '-')

        inject: (widgetName, options = {}) ->
            ###
                Inject a widget dynamically, under a specified container
                element or inside a modal window.

                The container option can be either a string, an HTML element
                or a jQuery selector, and will end up casted as a jQuery
                selector either way. If no container is specified the widget
                will be opened inside a modal and a `modalTitle` option should
                be specified for it.

                Example:

                    # Inject widget in container
                    Utils.inject('item-count',
                        container: '.item-count-container'
                        params:
                            channels: ...
                    )

                    # Inject widget in modal
                    Utils.inject('item-count',
                        modalTitle: 'Here is an Item Count'
                        params:
                            channels: ...
                    )

                @param (string) widgetName The name of the widget to be injected
                                            (defined in the modules.js mappings)
                @param (object) options Extra options for injecting the widgets,
                                        here are the available ones:
                    - (string) id The id attribute
                    - (string) classes Extra set of classes
                    - (object) data Extra set of data attributes (the `widget`
                                    and `params` keys are reserved for the widget
                                    name and params respectively and thus will be
                                    overwritten is present)
                    - (object) params The data params that the widget will
                                      receive, they will be strigified and passed
                                      through the `data-params` attribute
                    - (string|HTML|jQuery) container Where in the DOM to inject
                                                     the widget at (a modal will
                                                     be used if not specified)
                    - (string) modalTitle Fallbacks to widgetName when missing
                                          and ignored when using a container
                    - (object) modalParams A different set of params for the modal
                                           widget itself
                    - (string) placement Method of injecting:
                        - replace: Inside container, replaces its current contents
                        - before - Outside container, before it
                        - after - Outside container, after it
                        - prepend - Inside container, first element
                        - append (default) - Inside container, last element

                @return (bool|HTML) false on failure or the HTML element on
                                    success
            ###
            # No need to validate container if we're not using one (using modal
            # instead)
            if options.container?
                container = options.container

                # Force casting of element into a jQuery selector
                unless (container instanceof jQuery)
                    container = $(container)

                # No need to create widget if the container is invalid. Also make
                # sure to return a false value in this case
                return false if not container.length

            # Build DOM element based on the widget options
            options.name = widgetName
            node = @_buildDomElementByWidgetOptions(options)

            # Inject into existing on container or fire up a modal with the
            # newly created widget, based on the existence of a container option
            if container?
                # Choose where and how to inject the created DOM element based on
                # the specified container and related options
                if options.placement is 'replace'
                    container.html(node)
                else
                    container[options.placement or 'append'](node)
            else
                pipe = loader.get_module('pubsub')
                pipe.publish('/modal',
                    html: node
                    # Deprecated: The modal window widget uses this for adding
                    # a class to the modal, based on the injected widget.
                    # Should be part of the modalParams
                    data_widget: widgetName
                    title: options.modalTitle or widgetName
                    params: options.modalParams or {}
                )

            # Return created widget DOM element on success
            return node

        buildDomElement: (type, id, classes, data) ->
            ###
                Build DOM element based on a specified type, id, list of
                classes and a data dict. Only the type is required.
            ###
            node = $("<#{type}></#{type}>")
            node.attr('id', id) if id
            node.attr('class', classes) if classes
            unless _.isEmpty(data)
                for k, v of data
                    # Strings get an extra set of quotes when they get
                    # stringified, so we should only stringify objects
                    v = JSON.stringify(v) if _.isObject(v)
                    node.attr("data-#{k}", v)
            return node

        injectWidget: (el, widget_name, params, extra_classes = null, clean = null, el_type = null, modal = false, prepend = false, before = false, after = false) ->
            ###
                @deprecated

                Utils.inject should be used in favor of this one,
                but it cannot yet be removed in order to provide backwards
                compatibility to all existing widgets.

                TODO: This should be changed to use the new Utils.inject
                internally in order to speed up the migration process of these
                two methods.

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
            classes = if extra_classes then "mozaic-widget #{extra_classes}" else "mozaic-widget"
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
                modal_params = if params.modal_params? then params.modal_params
                pipe.publish '/modal',
                    html: html
                    title: title
                    data_widget: widget_name
                    params: modal_params

        findObjectKey: (obj, val) ->
            ###
                Given an object, find the key for a value.
            ###
            for prop of obj
                if obj.hasOwnProperty(prop) and obj[prop] == val
                    return prop

        getNestedAttr: (obj, path, separator = '/') ->
            ###
                Get a value of a sub-set of the data.

                path: a "path" with items separated by separator (e.g. "/")
                Returns: the data at the given path or null
            ###
            result = obj
            for field in path.split(separator)
                result = Utils.getAttributeFromModel(result, field)
            result

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

        notifyFilterChanges: ->
            # nothing for now

        notify: (message, type = 'notice') ->
            ###
                Displays a notification message.

                Supported types:
                  - loading
                  - status
                  - success
                  - error
                  - notice

                _loading_ and _status_ are special types that do not remove
                themselves automatically after a period of time.

                Any other type can be used if there's a corresponding
                CSS class to represent it accordingly.

                @see notifications.coffee
            ###
            # Get pubsub pipe
            pipe = loader.get_module('pubsub')
            # Publish through /notifications channel
            pipe.publish('/notifications', { type: type, message: message })

        setTitle: (params) ->
            ###
                Dinamically modify page title name when navigating through site
                by creating a dict with current page title and count (if keyword)
            ###

            # The method can be called with a null parameter in order to reset
            # the current ones
            if not params?
                @title = {}
            else
                # Reset count if a new page has been specified
                delete @title.count if params.page

                # Allow only some parameters to be modified
                allowed_title_parameters = ['page', 'count']
                params = _.pick(params, allowed_title_parameters...)

                # Update cached copy of title params
                _.extend(@title, params)

            # A standard page title has the following form:
            #       ({{count}}) {{page}}
            #   Count is set when streampoll gets data (if it is 0 is now shown)
            if @title.page
                title = @title.page
                title = "(#{@title.count}) #{title}" if @title.count
            window.document.title = title

        clearNotifications: () ->
            ###
                Clear all notifications, regardless of the
                "loading" stashed count

                @see notifications.coffee
            ###
            # Get pubsub pipe
            pipe = loader.get_module('pubsub')
            # Publish through /notifications channel
            pipe.publish('/notifications', { type: 'clear_all' })

        closeModal: ->
            ###
                Close any opened modal window by publishing an empty message
                on the '/closemodal' channel
            ###
            pipe = loader.get_module('pubsub')
            pipe.publish('/closemodal', {})

        createModuleInstance: (Module, params...) ->
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
                    if error.message == Constants.UNAUTHORIZED_EXCEPTION
                        throw error
                    logger.error("Exception trying to instantiate " + Module.name + " with params " + arguments + ":" + error)
            return result

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

        titleize: (name, opts = {}) =>
            ###
                Return a string with all its words capitalized. E.g.

                Utils.titleize('a little Shit')
                -> "A Little Shit"
            ###
            words = name.split ' '
            keepLowerCase = opts.keepLowerCase || ['and', 'the', 'of']
            titleWords = _.map words, (w) ->
               if _.indexOf(keepLowerCase, w.toLowerCase()) != -1
                   return w.toLowerCase()
               else
                   return _.str.titleize w

            return titleWords.join ' '

        getAttributeFromModel: (model, key, params...) ->
            ###
                Retrieves the value from a model, but also
                checks if this is a function, calling it in that
                context if so. Gives priority to function.
            ###
            if model
                if key of model
                    value = model[key]
                else if model.has?(key)
                    value = model.get(key)
            if $.isFunction(value)
                return value.apply(model, params)
            value

        _buildDomElementByWidgetOptions: (options) ->
            ###
                Build DOM element based on the format of widget options
                received by the inject method
            ###
            type = options.type or 'div'
            id = options.id
            classes = 'mozaic-widget'
            classes = "#{classes} #{options.classes}" if options.classes
            data = options.data or {}
            data.widget = options.name
            data.params = options.params or {}
            node = @buildDomElement(type, id, classes, data)

    # Extend Utils with other utils functions (see utils/ dir) in order
    # to keep the same Utils.method() interface.
    _.extend(Utils, Urls)
    _.extend(Utils, Time)
    _.extend(Utils, Dom)
    _.extend(Utils, Images)
    _.extend(Utils, Misc)

    window.Utils = Utils
    return Utils
