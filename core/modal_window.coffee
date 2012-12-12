define ['cs!mozaic_module', 'cs!loader'], (Module) ->
    class ModalWindow extends Module
        ###
            Wrapper over a modal window already inserted in the DOM.
            This module is instantiated only once (it's a singleton) and
            it's displayed every time a new event arrives on the /modal
            channel

            To control this widget one can use the following events:
            1. pipe.trigger '/modal' - to make the modal show up
            2. pipe.trigger '/closemodal' - to hide the modal
            3. pipe.on '/modalshown' - to be notified when the modal and i't containing widget are rendered
            4. pipe.on '/modalclosed' - to be notified when the modal is hidden and it's containing widget is deleted
        ###

        constructor :->
            super()

        initialize: =>
            @setup()
            @setupEvents()

        setup: ->
            ###
                Setup instance variables required later on
            ###
            @pipe = loader.get_module('pubsub')
            # Shortcuts for the modal div and it's body and title
            # div elements
            @modal = $('#modal')
            if not @modal
                throw('Missing modal html. Insert it in your base template')

            @body = @modal.find('.modal-body')
            @title = @modal.find('.modal-title')
            if not @body or not @title
                throw('Malformed modal html. Use Twitter bootstrap modal format')

            @defaultModalParams =
                backdrop: 'static'
                keyboard: false
                show: true
                remote: false
                showCloseButton: true


        setupEvents: =>
            ###
                Set callbacks for DOM events we are interested in
            ###
            @modal.on('hide', @unloadWidget)
            @modal.on('shown', @setDefaultFocus)
            @pipe.subscribe('/modal', @insertWidget)
            @pipe.subscribe('/closemodal', @close)

        empty: ->
            @body.empty()

        show: (display = 'show') ->
            ###
                Pass arguments directly to the modal jquery widget.
                If display is object, then pass options to the modal.
                Our modals support custom params, sucha as `showCloseButton`.
                @param {String} [display] - 'show' or 'hide' the modal window.
                @param {Boolean} [display.showCloseModal] - if true, we will hide the close button else we will show it.
            ###
            if display is 'hide'
                @modal.modal 'hide'
                # Also remove the modal from the element to make sure no config gets left behind.
                delete @modal.data().modal
                # TODO Also remove listener on `ESC` key and click on backdrop
                return

            if display is 'show'
                # Use default params for showing the modal.
                # Make sure jquery.modal uses default params when shown.
                display = @defaultModalParams
            else if $.isPlainObject display
                # merge default modal params into the arguments
                display = _.extend {}, @defaultModalParams, display
            else
                throw new Error "Unexpected param for ModalWindowWidget@show() #{display}"

            # display the modal
            @modal.modal display

            # Handle showCloseButton custom variable
            if display.showCloseButton is false
                @modal.find('i.icon-close-modal').hide()
            else
                @modal.find('i.icon-close-modal').show()


        setDefaultFocus: =>
            # Focus on first "tabbable" element but ignore anchors or buttons
            @modal.find(':tabbable:not(a,input.btn):first').focus()

        validMessage: (message) ->
            ###
                Every message received on the /modal channel should
                have html and title attributes
            ###
            true

        insertWidget: (message) =>
            ###
                Insert a new widget in the modal body. The format of the
                message is { title: 'Modal Title', 'body': '<html>...' }
            ###
            if @validMessage
                @empty()
                @title.html(message.title)
                @body.html(message.html)
                @show message.params
                @addWidgetName(message)
                @pipe.publish '/modalshown'

        addWidgetName: (message) ->
            ###
                Used to add the widget name to the @modal class.
                Used only for css styling.
            ###
            # First remove any old classes, on new inject.
            @modal.removeClass(@addedClass) if @addedClass
            # Add a new class with current data_widget name.
            @addedClass = message.data_widget
            @modal.addClass(@addedClass)


        close: () =>
            @show('hide') # :)


        unloadWidget: () =>
            ###
                This method is executed every time the modal is hidden.
                Remove the widget from the DOM for now by emptying
                the modal body
            ###
            @empty()
            @pipe.publish '/modalclosed'


    return ModalWindow


