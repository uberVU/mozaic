define ['cs!widget'], (Widget) ->
    class ModalWidget extends Widget
        constructor: (params) ->
            super(params)
            pipe = loader.get_module('pubsub')
            pipe.subscribe(@modal_channel, @showModal)

        showModal: (params) =>
            logger.info("Show Modal")
            @params = _.extend(@params, params)
            $(@modal).find(".error").hide()
            $(@modal).modal('show')
