define ['cs!widget'], (Widget) ->

    class ModalWidget extends Widget
        ###
            The ModalWidget is a base class that is meant to be used ONLY inside a
            modal window.

            It provides functionality related to the modal window such as the close
            event.

            Provided events:

            - close: called when the modal is closed by the user (override the @close method)
        ###

        initialize: () ->
            @setup_events()

        setup_events: () ->
            ###
                Setup events needed by the modal window.
            ###

            # Bind a callback to the close button of the modal
            ($ '.icon-close-modal').one 'click', @on_close

