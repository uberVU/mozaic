define ['cs!core/pubsub', 'chai'], (PubSub, chai) ->
	should = chai.should()
	
	describe 'PubSub', ->
		describe 'subscribe()', ->

			it 'should create 2 new subscribers without callback functions', ->
				p = new PubSub

				p.subscribe "/1"
				p.subscribe "/2"
				p.should.not.have.property("_callbacks")				

			it 'should create 2 new subscribers with callback functions', ->
				p = new PubSub

				p.subscribe "/1", ->
					some_var1 = 'this is the callback function #1'
				p.subscribe "/2", ->
					some_var2 = 'this is the callback function #2'

				p.should.have.property("_callbacks")
				p._callbacks.should.have.keys("/1", "/2")

			it 'should create 1 subscriber then 1 publisher', ->
				p = new PubSub
				
				p.subscribe "/1", (message) ->
					message.status.should.equal "OK"

				p.publish "/1", {status: "OK"}
				
			it 'should create 1 publisher then 1 subscriber', ->
				p = new PubSub
				
				p.publish "/1", {status: "1"}

				p.subscribe "/1", (message) ->
					message.status.should.equal "1"

			it 'should create 3 publisher then 2 subscriber', ->
				p = new PubSub
				
				p.publish "/1", {status: "1"}
				p.publish "/2", {status: "2"}
				p.publish "/3", {status: "3"}

				p.subscribe "/1", (message) ->
					message.status.should.equal "1"

				p.subscribe "/3", (message) ->
					message.status.should.not.equal "2"

				p.should.have.property("_publishedEvents")
				p._publishedEvents.should.have.keys("/1", "/2", "/3")

			it 'should create 1 subscriber, then 2 publishers, then 1 subscriber', ->
				p = new PubSub

				p.subscribe "/1"

				p.publish "/2", {status: "2"}
				p.publish "/3", {status: "3"}

				p.subscribe "/3", (message) ->
					message.status.should.equal "3"

			it 'should create 100 subscribers then 150 publishers, then 50 subscribers', ->
				p = new PubSub

				for i in [1..100]
					p.subscribe "/#{i}", (message) ->
						message.status.should.equal "#{i}"

				for i in [1..150]
					p.publish "/#{i}", {status: "#{i}"}

				for i in [1..50]
					p.subscribe "/#{i}", (message) ->
						message.status.should.equal "#{i}"
			
			it 'should create 1 subscribers then 100 publishers for him', ->
				p = new PubSub

				p.subscribe "/1", (message) ->
					message.status.should.equal "/2"

				for i in [1..100]
					p.publish "/1", {status: "/2"}		
