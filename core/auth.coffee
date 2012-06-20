define ["cs!constants"], (Constants) ->
    window.Mozaic = window.Mozaic or {}
    ajaxRequests = []

    class Auth
        constructor: ->
            $.ajaxSetup
                beforeSend: (jqXHR) ->
                    if window.Mozaic.stopping_ajax_requests
                        jqXHR.abort()
                    else
                        ajaxRequests.push(jqXHR)

        login: (username, password, callback) =>
            ###
                Try to login an user with the given username and password.
                Whenever the request completes, perform a callback regardless
                of the result.
            ###

            # This stuff will be sent to the login API
            params =
                username: username
                password: password

            @makeAjaxRequest('login', callback, params)

        logout: (callback) =>
            ###
                Try to log out the current user.
            ###
            callback = (type, data) ->
                if type == 'success'
                    window.user = null
                    window.Mozaic.stopping_ajax_requests = true
                    window.location.href = App.general.LOGIN_PAGE

            @makeAjaxRequest('logout', callback)

        makeAjaxRequest: (type, callback, params={}) =>
            # Define own callbacks which call the callback given by the user
            # with an extra parameter 'success' / 'error' depending on the
            # result of the AJAX request.
            success_callback = (data) -> callback('success', data)
            error_callback = (jqXHR, textStatus, errorThrown) -> callback('error', jqXHR)
            complete_callback = (jqXHR, textStatus) ->

            switch type
                when 'login'
                    url = App.general.LOGIN_URL
                    type = 'POST'
                when 'logout'
                    url = App.general.LOGOUT_URL
                    type = 'POST'
                else
                    url = App.general.CURRENT_USER_URL
                    type = 'GET'

            # Make the actual AJAX request
            $.ajax
                url: url
                dataType: 'json'
                data: params
                success: success_callback
                error: error_callback
                complete: complete_callback
                type: type

        abortExpiredAjaxRequests: () =>
            while request = ajaxRequests.shift()
                request.abort()

        startWatchingForUnauthorizedApiAnswers: =>
            ###
                Hooks all AJAX requests in order to detect 401 unauthorized
                status codes and redirect to the login page.
            ###

            # We intercept all AJAX requests done via XMLHttpRequest in order
            # to stop them whenever needed. The problem is that sometimes
            # when we issue a redirect to the login page because we are detecting
            # a 401 status code from the API we are consuming, there are still
            # pending HTTP requests and callbacks to be called which need
            # to fail gracefully.
            #
            # TODO: check if core data structures can become corrupted from
            # not calling these callbacks

            # Override Backbone.sync, the primary method with which we are
            # consuming our RESTful API. If a request fails with 401 unauthorized
            # status code, we make all pending AJAX requests fail gracefully
            # and redirect the user to the login page.
            Backbone._sync = Backbone.sync
            Backbone.sync = (method, model, options) ->
                # Check if there is a complete callback defined already,
                # and call it later in order to avoid breaking user-defined stuff.
                old_complete = options.complete or null

                # Our new complete callback will call the old one if it exists
                # and check the status code to detect whether redirect to login
                # is needed.
                options.complete = (xhr, status) =>
                    if xhr.status == 401
                        @redirectToLogin()
                    else if old_complete
                        old_complete(xhr, status)
                Backbone._sync(method, model, options)

            # Hook into AJAX requests done with jQuery.
            # These are mostly RawData requests.
            $(document).ajaxError((e, xhr) =>
                if xhr.status == 401
                    @redirectToLogin()
            )

        refreshCurrentUser: (user_callback = null) =>
            ###
                Refreshes the current user by issuing an AJAX request.
            ###
            callback = (type, data) ->
                if type == 'success'
                    window.user = data
                user_callback(type, data) if user_callback

            @makeAjaxRequest('current', callback, {})

        setupCurrentUserRefresh: ->
            ###
                Setup periodic refresh for the current user object.
            ###
            setInterval(@refreshCurrentUser, App.general.CURRENT_USER_TIMEOUT)

        redirectToLogin: =>
            ###
                Redirects the user to the login page.

                Note: setting window.location.href does *not* provoke 
                an immediate redirect, so in order to simulate that
                we throw a custom exception, UNAUTHORIZED_EXCEPTION.

                This exception should not be caught by any of our layers,
                and should be propagated to either the main error handler
                or the application bootstrap code in main.js
            ###
            window.Mozaic.stopping_ajax_requests = true
            @abortExpiredAjaxRequests()
            window.location.href = App.general.LOGIN_PAGE
            throw Constants.UNAUTHORIZED_EXCEPTION

    return Auth