define [], () ->
    dom =
        checkCloseToViewport: ($el, scroll_element = window, pagesNum = 3) ->
            ###
                Check if element $el is in viewport or close to it by
                #pagesNum number of pages
            ###
            if scroll_element is window
                [elementTop, elementHeight] = [$el.offset().top, $el.height()]
                {top, height} = @_getViewportRectangle()
            else
                # elementTop is top position $el relative to $(scroll_element)
                # That's why top for $(scroll_element) will always be 0
                [elementTop, elementHeight] = [$el.position().top, $el.height()]
                [top, height] = [0, $(scroll_element).height()]

            viewportTop = top - pagesNum*height
            viewportBottom = top + height + pagesNum*height

            # In the element is outside viewport these situations can happen:
            # ____ elementTop
            # ____ elementTop + elementHeight
            # .... viewportTop
            # .... viewportBottom
            # or:
            # .... viewportTop
            # .... viewportBottom
            # ____ elementTop
            # ____ elementTop + elementHeight
            isOutsideViewport = elementTop + elementHeight < viewportTop or
                                viewportBottom < elementTop

            isCloseToViewport =  not isOutsideViewport
            return isCloseToViewport

        checkInViewport: ($el) ->
            ###
                Checks if a given element is in browser viewport.
                @param {Object} $el jQueryObject
                @return {Boolean}
            ###
            return @checkCloseToViewport($el, window, 0)

        _getViewportRectangle: () ->
            # Cross-browser viewport height.
            if document.compatMode or not $.support.boxModel
                if document.compatMode is 'CSS1Compat'
                    height = document.documentElement.clientHeight
                else
                    height = document.body.clientHeight
            else
                height = window.innerHeight

            # Cross-browser scrolltop value.
            if document.documentElement.scrollTop
                top = document.documentElement.scrollTop
            else
                top = document.body.scrollTop

            return {top: top, height: height}

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
