module.exports = (grunt) ->

  # Initialize the configuration.
  @initConfig
    docco:
        debug:
            src: 'core/*.coffee'
    docco_husky:
        project_name:'testing'

  grunt.registerTask 'default', 'Change comments', ->
      shell = require('shelljs')
      shell.exec("cp -R core core~")
      shell.exec("rm -rf core~/libs")

      shell.exec("python generate-documentation.py core~")
      shell.exec("docco-husky core~")
      shell.exec("rm -rf core~")
