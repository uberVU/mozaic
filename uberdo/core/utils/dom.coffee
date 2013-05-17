define [], () ->
    dom =
        checkInViewport: ($el) ->
            ###
                Checks if a given element is in browser viewport.
                @param {Object} $el jQueryObject
                @return {Boolean}
            ###
            top = $el.offset().top
            viewportHeight = @getViewportHeight()
            scrolltop = @getScrolltop()
            inViewport = (viewportHeight + scrolltop) >= top


        getViewportHeight: ->
            # Cross-browser viewport height.
            if document.compatMode or not $.support.boxModel
                if document.compatMode is 'CSS1Compat'
                    document.documentElement.clientHeight
                else
                    document.body.clientHeight
            else
                window.innerHeight


        getScrolltop: ->
            # Cross-browser scrolltop value.
            if document.documentElement.scrollTop
                document.documentElement.scrollTop
            else
                document.body.scrollTop

        escape_css_name: (name) ->
            ###
                Makes sure that name is safe to be used as element's class or id.
                If it finds any element not matching [_a-zA-Z0-9-] it simply removes it.
                This is needed for g+ reactions/comments which contain a dot `.` in the id.
                @param {String} name
                @return {String}
            ###
            name.replace /[^_a-zA-Z0-9-]/gi, '' if _.isString(name)

    return dom
