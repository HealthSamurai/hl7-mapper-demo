mapper = require("./hl7mapper")
app = angular.module('app', ['ui.codemirror'])
data = require("./data")

app.controller 'MainCtrl', ['$scope', ($scope) ->
  codemirrorExtraKeys = window.CodeMirror.normalizeKeyMap
    "Ctrl-Space": "autocomplete"
    Tab: (cm) ->
      cm.replaceSelection("  ")

  $scope.codemirrorConfig =
    lineWrapping: false
    lineNumbers: true
    mode: 'yaml'
    extraKeys: codemirrorExtraKeys,
    viewportMargin: Infinity

  $scope.mapping = data.mapping
  $scope.message = data.message
  $scope.currentTab = 'mapping'

  $scope.result = "Still no result"
]
