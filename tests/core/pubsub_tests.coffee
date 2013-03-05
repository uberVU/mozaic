define ['cs!tests/base_test', 'cs!pubsub'], (BaseTest, PubSub) ->

    class PubSubTests extends BaseTest
        testName: '[Core] PubSub'

        test_async_pubsub_subscribers: ->
            ###
                Tests for pubsub functionality
            ###
            expect(8)

            pubsub = new PubSub()

            pubsub.subscribe('all', () ->
                equal(arguments.length, 2)
            )
            pubsub.publish('delete blur', {id: 1}, {silent: true})

            pubsub.subscribe('/change', (type, data) ->
                equal(type, 'reset')
                deepEqual(data, {change: 'value'})
            )
            pubsub.subscribe('/delete', (data, options) ->
                deepEqual(data, {id: 1})
                deepEqual(options, {silent: true})
                start()
            )
            pubsub.publish('/change', 'reset', {change: 'value'})
            pubsub.publish('/delete', {id: 1}, {silent: true})
