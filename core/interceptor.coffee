define [], () ->
    class Interceptor
        
        @_addAjaxRequestCallback: (eventName, callback) =>
            ###
                Add posibility for multiple callbacks for 
                ajax call events
                The callbacks are stored on the jquery object
            ###
            CALLBACK_CONTAINER_SUFIX = '_callback_container'
            container = eventName + CALLBACK_CONTAINER_SUFIX
            
            if $[container]
                $[container].push( callback )
            else
                $[container] = [callback]
                $(document)[eventName]( (ev, xhr, settings) ->
                    # process the callback queue
                    for callback in $[ev.type + CALLBACK_CONTAINER_SUFIX]
                        callback(ev, xhr, settings)
                    )

        @addAjaxSendRequestCallback: (callback) =>
            @_addAjaxRequestCallback('ajaxSend', callback)
        
        @addAjaxCompleteRequestCallback: (callback) =>
            @_addAjaxRequestCallback('ajaxComplete', callback)
        
    return Interceptor