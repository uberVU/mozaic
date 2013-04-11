define [], () ->

    CLASS_IMG_LOADED = 'img-load-success'

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

        lazyLoadImages: ($images, options) ->
            ###
                Method loads images in the background, then pops them
                into the DOM. It expects as param a jQuery object
                with an img (or a list of imgs) that has a `data-src`
                attribute containing the url of the image to be loaded
                in the background.

                Process:()
                1. clone the img element in memory
                2. get url from data-src and put it in src in the cloned img tag
                 - if we're doing twitter avatars load a fast low-res image first.
                3. wait until appropriate image is loaded on the cloned img tag
                 - if it has load add a class `img-load-success`
                4. replace the original img tag with the cloned and loaded img
                 - if it's not loaded keep the original image (which will display nothing)

                @param {Object} $images - jQuery object
                @param {Object} options
                @param {Function} [options.callback] - gets executed either on
                                    error or on success when loading the image.
                @param {String} [options.twitterAvatarSize] - if executed on a
                                        twitter avatar, resize it to this image
                @return undefined

                TODO (topliceanu) allow this function to be controlled from the
                DOM, using a data-size attribute, which will override anything.
                Ex: <img data-src="..' data-size="_mini"/>
            ###

            defaults =
                # This is the size that the image should be resized to.
                twitterAvatarSize: '_bigger'
                # This method is executed when the final image is loaded.
                # It's called wither with an error or the final image jQuery el.
                callback: ->

            options = _.extend defaults, options

            twitterPostfixes = [
                '_reasonably_small' # 128x128px
                '_bigger' # 73x73px
                '_normal' # 48x48px
                '_mini' # 24x24px
            ]

            $images.each (index, image) ->

                # Filter out elements that are not `img` tags and don't have
                # `data-src` attribute.
                return unless image.nodeName.toLowerCase() is 'img' and
                    image.hasAttribute 'data-src'

                $image = $(image)
                $clone = $image.clone()
                originalUrl = $clone.attr 'data-src'

                isTwitterAvatar = false
                for postfix in twitterPostfixes
                    if (originalUrl.indexOf postfix) >= 0
                        isTwitterAvatar = true
                        break

                if isTwitterAvatar
                    # Load the low-res avatar for smooth experience, but
                    # prepare to replace it with the appropriate res version.
                    fastAvatar = originalUrl.replace postfix, '_mini'
                    appropriateUrl = originalUrl.replace postfix,
                        options.twitterAvatarSize
                    $image.attr 'src', fastAvatar
                else
                    appropriateUrl = originalUrl

                ($clone.attr 'src', appropriateUrl)
                    .load ->
                        # Mark the image tag as loaded by adding setting a class.
                        $clone.addClass CLASS_IMG_LOADED
                        # Ensures indempotency. If this helper is used multiple
                        # times on the same template, it will not reload images.
                        $clone.removeAttr 'data-src'
                        $image.replaceWith $clone
                        options.callback null, $clone
                    .error ->
                        options.callback (new Error 'could not load image'), $image
