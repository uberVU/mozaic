define [], () ->
    images =
        mapDefaultImages: (el, types = {}) ->
            ###
                Map broken image paths to corresponding
                default ones

                The types argument must be a key-value object, where
                the key is a jQuery selector and the value is a
                default image name from Constants.DEFAULT_IMAGES

                The value can also be null if the img tags have
                pre-defined data-default-image values
            ###
            # Go through specified types and replace the defaut-image
            # data param of the targeted img tags
            for selector, name of types
                # Add event handler for error
                el.find(selector).on 'error', ->
                    # Prevent infinite loop if default image is also broken
                    $(this).off('error')
                    # Replace image source
                    this.src = src if (src = $(this).data('default-image'))
                # Populate default-image data value from constants, if a src
                # for the given image name is defined
                if (src = Utils.getDefaultImage(name))
                    el.find(selector).data('default-image', src)

        getDefaultImage: (name) ->
            if not Constants.DEFAULT_IMAGES[name]?
                return false
            return Utils.getStaticUrl(Constants.DEFAULT_IMAGES[name])

    return images
