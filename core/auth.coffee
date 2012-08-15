define ['cs!interceptor', 'cs!constants', 'cs!utils'], (Interceptor, Constants, Utils) ->
    window.Mozaic = window.Mozaic or {}
    window.ajaxRequests = []

    class Auth
        constructor: ->
            Interceptor.addAjaxSendRequestCallback((e, xhr, settings) =>
                if window.Mozaic.stopping_ajax_requests
                    xhr.abort()
                else
                    window.ajaxRequests.push(xhr)
            )                

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

            # Get attempted page before login, if any. Maybe the user
            # was trying to access a page but was not logged in, so
            # save it, to redirect him after a successful login.
            url = Utils.current_url(false).split('#')[1]
            @params = if url then {url: url} else {}

            # Add Interceptor callback for ajaxComplete. If a request fails with 
            # 401 unauthorized we make all pending AJAX requests fail gracefully
            # and redirect the user to the login page.
            Interceptor.addAjaxCompleteRequestCallback((e, xhr, settings) =>
                if xhr.status == 401
                    @redirectToLogin(@params)
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

        redirectToLogin: (params = {}) =>
            ###
                Redirects the user to the login page. If params
                contains a url it means the user was trying to access
                this but was not loged in. So, after login, redirect
                him to the page stored in tue URL as ..?returnto=url.

                Note: setting window.location.href does *not* provoke 
                an immediate redirect, so in order to simulate that
                we throw a custom exception, UNAUTHORIZED_EXCEPTION.

                This exception should not be caught by any of our layers,
                and should be propagated to either the main error handler
                or the application bootstrap code in main.js
            ###
            window.Mozaic.stopping_ajax_requests = true
            @abortExpiredAjaxRequests()
            url = App.general.LOGIN_PAGE

            # Encode the URL part added to returnto, and decode it
            # after the login was successful.
            url += '?returnto=' + encodeURIComponent(params.url) if params.url
            window.location.href = url
            throw Constants.UNAUTHORIZED_EXCEPTION

        getRedirectPageAfterLogin: ->
            ###
                Redirect to the page the user was trying to access but was
                prompted with a login page.

                If the url is of type login.html?returnto='search/18181/stream'
                redirect the user after a successful login to search/18181/stream
            ###
            url = Utils.current_url()
            returnto = $.url(url).param('returnto')
            # Decode the previous encoded URL.
            returnto = decodeURIComponent(returnto) if returnto
            url_new = '/' + (if returnto then '#'+returnto else '')
            return url_new
