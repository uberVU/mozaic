module.exports = (grunt) ->

  # Initialize the configuration.
  @initConfig
    docco:
        debug:
            src: 'core/*.coffee'
    docco_husky:
        project_name:'testing'

  grunt.loadNpmTasks 'grunt-docco'
  grunt.loadNpmTasks 'grunt-docco-husky'

  grunt.registerTask 'default', 'Change comments', ->
      grunt.log.writeln 'running default' 

      shell = require('shelljs')
      shell.exec("cp -R core core~")
      shell.exec("rm -rf core~/libs")

      shell.exec("python script.py")
      shell.exec("docco-husky core~")
      shell.exec("rm -rf core~")
