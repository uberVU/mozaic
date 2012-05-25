window.Utils =
    guid: (name) ->
        return _.uniqueId(name + '-')

    has_get_params: (url) ->
        ###
            Returns true if and only if url has GET params.

            For example:
                stream/123/?k1=v1 has GET params
                stream/123?/k1=v1 doesn't
        ###
        last_slice = url.substring(url.lastIndexOf('/') + 1)
        return last_slice.indexOf('?') != -1

    current_url: (without_fragment = true) ->
        ###
            Gets the current URL without fragment (by default).
        ###
        if not without_fragment
            return document.URL

        first_hash = document.URL.indexOf('#')
        if first_hash != -1
            return document.URL.substring(0, first_hash)
        else
            return document.URL

    render_url: (url, params, exclude = [], skip_get_append = false) ->
        ###
            Renders an URL given a template and a set of params.

            url: url template
            params: params used for GET params and to fill url placeholders
            exclude: ignore some parameters

            Most parameters from params will be appended as GET parameters
            (it will check if there are already other parameters), and
            some of them will be used to fill in for placeholders.
            If a parameter has been used for a placeholder, it won't be
            appended as a GET parameter anymore (its information has
            already been included in the URL).

            Example:
            render_url('streams/{{id}}/facebook?k1=v1',
                       {gender: 'male', id: 123, sentiment: 'positive'},
                       ['sentiment'])
            will return
            'streams/123/?k1=v1&gender=male'
        ###
        final_url = url

        # Do placeholder replacement and determine the remaining GET params
        get_params = {}
        for k, v of params
            token = '{{' + k + '}}'
            if url.indexOf(token) != -1
                final_url = final_url.replace(token, v)
            else
                get_params[k] = v

        # Exclude parameters
        for excluded_param of exclude
            if excluded_param of get_params
                delete get_params[excluded_param]

        # If there are no params to add, return the URL now
        if _.keys(get_params).length == 0 or skip_get_append
            return final_url

        # Add get params if it doesn't contain them already
        if Utils.has_get_params(final_url)
            final_url = final_url + '&'
        else
            final_url = final_url + '?'

        # Append the final GET parameters
        first = true
        for k, v of get_params
            if not first
                final_url = final_url + '&'
            else
                first = false
            final_url = final_url + k + '=' + v
        final_url

    model_url: (collection_url, id) ->
        ###
            Returns the URL for a given model, given the
            URL of its collection and the id of the model.
        ###

        # Strip the hashbang first
        first_hash = collection_url.indexOf('#')
        if first_hash != -1
            collection_url = collection_url.substring(0, first_hash)

        # Strip the GET params
        last_slash = collection_url.lastIndexOf('/')
        if last_slash != -1
            last_slice = collection_url.substring(last_slash + 1)
            get_start = last_slice.indexOf('?')
            if get_start != -1
                get_pos = last_slash + get_start
                collection_url = collection_url.substring(0, get_pos)

        # Add a trailing slash if there isn't one already
        if collection_url[collection_url.length - 1] != '/'
            collection_url = collection_url + '/'

        # Append the model id and be done with it
        collection_url + id + '/'

    injectWidget: (el, widget_name, params, extra_classes = null, clean = null, el_type = null, modal = false) ->
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
        ###
        stringified_params = JSON.stringify(params)
        classes = if extra_classes then "uberwidget #{extra_classes}" else "uberwidget"
        type = if el_type then "#{el_type}" else "div"

        html = "<#{type}
                    class='#{classes}'
                    data-widget='#{widget_name}'
                    data-params='#{stringified_params}'
                ></#{type}>"
                
        if not modal
            if clean? and clean
                el.html(html)
            else
                el.append(html)
        else
            pipe = loader.get_module('pubsub')
            pipe.publish('/modal', { html: html, title: widget_name })

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
