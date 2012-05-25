define ['cs!module', 'cs!loader'], (Module) ->
    class ModalWindow extends Module
        ###
            Wrapper over a modal window already inserted in the DOM. 
            This module is instantiated only once (it's a singleton) and 
            it's displayed every time a new event arrives on the /modal 
            channel
        ###

        constructor :->

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
        
        setupEvents: =>
            ###
                Set callbacks for DOM events we are interested in
            ###
            @modal.on('hide', @unloadWidget)
            @pipe.subscribe('/modal', @insertWidget)
            
        empty: ->
            @body.empty()
            
        show: (display = 'show') ->
            @modal.modal(display)
            
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
                @show()
                
        unloadWidget: () =>
            ###
                This method is executed every time the modal is hidden. 
                Remove the widget from the DOM for now by emptying 
                the modal body
            ###
            @empty()
            
    return ModalWindow
            
        
