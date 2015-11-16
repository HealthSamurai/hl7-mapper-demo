mapper = require("./hl7mapper")
data = require("./data")
yaml = require("js-yaml")

app = angular.module('app', ['ui.codemirror', 'firebase'])

app.controller 'MainCtrl', ['$scope', '$firebaseArray', ($scope, $firebaseArray) ->
  fbRef = new Firebase("https://brilliant-fire-3098.firebaseio.com/presets")
  fbRef.auth('RT8psSDePEt9qoWALaDQPjfr6bLWmmnoLklxQalZ')

  $scope.presets = $firebaseArray(fbRef);

  codemirrorExtraKeys = window.CodeMirror.normalizeKeyMap
    "Ctrl-Space": () ->
      $scope.$apply('doMapping()')

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

  $scope.doMapping = () ->
    try
      mapping = yaml.safeLoad($scope.mapping)
      r = mapper.doMapping($scope.message, mapping)
      $scope.result = JSON.stringify(r, null, 1)
      $scope.error = null
    catch e
      if e.message
        $scope.error = e.message
      else
        $scope.error = JSON.stringify(e, null, 1)

  $scope.$watch 'message', (newValue) ->
    $scope.doMapping()

  $scope.$watch 'mapping', () ->
    $scope.doMapping()

  $scope.savePreset = () ->
    loop
      name = prompt("Preset name?")
      break if name == null || name.length > 0 

    if name != null 
      $scope.presets.$add
        name: name
        message: $scope.message
 
  $scope.loadPreset = (p) ->
   $scope.message = p.message
   $scope.mapping = p.mapping

  $scope.doMapping()
]
