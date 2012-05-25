define ['cs!modal_widget'], (ModalWidget) ->

    class TagModalWidget extends ModalWidget

        modal: "#addTag"
        subscribed_channels: ['/tags']
        modal_channel: '/new_tag'
        template_name: 'templates/modals/add_tag.hjs'

        events:
            "click .addTag": "addTag"
            "keypress .new_tag": "pressEnter"

        pressEnter: (event) =>
            if event.keyCode == 13
                @addTag(event)

        initialize: =>
            @renderLayout()
            @el.find(".new_tag").focus()

        get_tags: (params) =>
            if params.type == 'error'
                @el.find(".error").html(params.error).show()
            if params.type == 'add'
                tag = @el.find(".new_tag").val()
                @el.find(".error").hide()
                $(@modal).modal('hide')
                tag_params = _.extend({}, {tag: tag}, @params['extra_params'])
                @modifyChannel(@params['channel'], tag_params, 'append', true)

        addTag: (event) =>
            tag = @el.find(".new_tag").val()
            @addChannel('/tags', {name: tag}, @)

    return TagModalWidget
