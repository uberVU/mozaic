define ['cs!core/raw_data', 'cs!logger', 'chai'], (RawData, logger, chai) ->
	should = chai.should()

	describe 'RawData', ->
		describe 'setDefaultValue', ->

			it 'should set the default value of RawData', ->
				r = new RawData

				newValue = {Jager: 'rock', Elvis: 'roll'}

				eq = false
				r.setDefaultValue newValue

				eq = _.isEqual r.getData(), newValue

				eq.should.equal true


		describe 'getData', ->

			it 'data should be blank if no key is added', ->
				r = new RawData

				newValue = {Jager: 'rock', Elvis: 'roll'}

				eq = false
				r.setDefaultValue newValue

				eq = _.isEqual r.getData(false), {}

				eq.should.equal true
		describe 'set', ->

			it 'should set data then get data', ->
				r = new RawData

				r.set "/1", {status: "1"}
				r.set "/2", {status: "2"}
				r.set "/3", {status: "3"}

				r.get "/1", (message) ->
					message.status.should.equal "1"
				r.get "/2", (message) ->
					message.status.should.equal "2"
				r.get "/3", (message) ->
					message.status.should.equal "3"

		describe 'fetch', ->

			it 'should fetch data for a given URL', (done) ->
				r =  new RawData
				###
				Just an example - return JsonObject
				###
				r.url = "http://wouso-next.rosedu.org/api/bazaar/?user=alex"
				f = (raw_data) -> console.log raw_data

				r.on("change", (raw_data) ->
					console.log r.getData()
					x = r.get("spells")
					for i in x
						console.log i
						i.image.should.equal ""
					done()
				)
				r.fetch()
