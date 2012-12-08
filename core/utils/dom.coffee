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
    
    return dom
