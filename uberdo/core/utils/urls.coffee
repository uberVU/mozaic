define [], () ->
    urls =
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
            for param, value of params
                tokens = ["{{#{param}}}", ":#{param}"]
                for token in tokens
                    if url.indexOf(token) != -1
                        delete get_params[param]
                        final_url = final_url.replace(token, encodeURIComponent(value))
                        break
                    else
                        get_params[param] = encodeURIComponent(value)

            # Exclude parameters
            for excluded_param in exclude
                if excluded_param of get_params
                    delete get_params[excluded_param]

            # If there are no params to add, return the URL now
            if _.keys(get_params).length == 0 or skip_get_append
                return final_url

            # Add get params using Uri lib
            final_url = new Uri(final_url)
            for param, encodedValue of get_params
                final_url.addQueryParam(param, encodedValue)
            final_url.toString()

        model_url: (collection_url, id) ->
            ###
                Returns the URL for a given model, given the
                URL of its collection and the id of the model.
            ###
            # Anything coming after ? (including ?). Ex: ?keyword_id= 25
            get_params_slice = ''
            # Strip the hashbang first
            first_hash = collection_url.indexOf('#')
            if first_hash != -1
                collection_url = collection_url.substring(0, first_hash)

            # Strip the GET params
            last_slash = collection_url.lastIndexOf('/')
            if last_slash != -1
                # GET params ?keyword_id = 1
                get_params_slice = collection_url.substring(last_slash + 1)
                # Find out the position of the ? in the collection_url
                get_start = get_params_slice.indexOf('?')
                if get_start != -1
                    get_pos = last_slash + get_start + 1
                    collection_url = collection_url.substring(0, get_pos)

            # Add a trailing slash if there isn't one already
            if collection_url[collection_url.length - 1] != '/'
                collection_url = collection_url + '/'

            # Append the model id and be done with it
            collection_url + id + '/' + get_params_slice

        add_params_to_url: (url, array) ->
            ###
                Add a GET param to URL fragment.
                E.g. add_params_to_url('index.html#search/39315/stream',
                                      [{cat: 'tom'}, {retard: 'ceva'}])
                -> 'index.html#search/39315/stream?cat=tom&retard=ceva'
            ###
            return unless $.isArray(array)

            obj = Utils.split_url_to_fragment(url)
            uri = new Uri(obj.fragment)
            _.each(array, (param) ->
                [key] = _.keys(param)
                # We are using jsUri#replaceQueryParams instead of jsUri#addQueryParam
                # because replace will not add it again if it already exists.
                uri.replaceQueryParam(key, param[key])
            )
            obj.path + uri.toString()

        # Get al fragment GET params from URL.
        # E.g. get_params('index.html#search/39315/stream?cat=tom&retard=ceva', 'cat', true)
        # -> [1, 2, 3]
        # for all = false, return the first one, 1
        get_fragment_url_params: (url, param, all = false) ->
            uri = new Uri(Utils.split_url_to_fragment(url).fragment)
            if all
                uri.getQueryParamValues(param)
            else
                uri.getQueryParamValue(param)

        # Split this in order to append the query url params to
        # the fragment if any, not to the path. Like so
        # index.html#fragment?query_appended_after_fragment
        split_url_to_fragment: (url) ->
            if (i = url.indexOf('#')) != -1
                url =
                    fragment: url.slice(i+1)
                    path: url.slice(0, i+1)
            else
                url =
                    fragment: url
                    path: ''

        get_domain: (url, strip_www=true) ->
            ###
                Returns only the domain of a given string.
                If strip_www is true it removes www. too
            ###

            # In case the url is wrong uri.host() will return the original string
            uri = new Uri(url)

            final_url = uri.host()

            # Only trim www. from the begining of the url
            if strip_www
                final_url = final_url.replace(/^\www./,'')

            return final_url

        get_url_and_params_from: (hash)->
            ###
                Input: #search/1000002491/stream?language=english&country=united states
                Returns:
                    url: /search/1000002491/stream
                    params: {language: 'english', country: 'united states'}
            ###

            # Change the hash into a relative path ..
            relativeUrl = "/" + _.string.ltrim(hash, '#')
            # .. And pass it to the Uri constructor
            # We're doing this so that the Uri object would compute the path and query params correctly
            uri = new Uri(relativeUrl)

            # take the path from url
            url = uri.path()

            params = {}
            # Uri returns query().params in this form: [['language': 'english'], ['country': 'united states']]
            # And we want to return them as object: {language: 'english', country: 'united states'}
            for param in uri.query().params
                [key, value] = [param[0], param[1]]
                params[key] = value

            return [url, params]

        stripHTMLOutsideTags: (content) ->
            ###
                Given a text like <a href='#'>http://url.com</a>, remove the
                anchors around the URL, returning only http://url.com.
            ###
            return $("<div>#{content}</div>").text()


    return urls
