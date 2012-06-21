define ['cs!core/raw_data', 'chai'], (RawData, chai) ->
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
				
		describe 'get', ->
				
