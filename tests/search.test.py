#!/usr/bin/env python3
"""Exercise Panel.qml's actual async search code in an isolated Quickshell process."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
panel = (repo / 'Panel.qml').read_text()
search_code = panel[panel.index('  function cancelGeocode()'):panel.index('  KeyboardPanel {')]
with tempfile.TemporaryDirectory(prefix='salat-search-test-') as folder:
    work = Path(folder)
    shutil.copy(repo / 'Model.js', work / 'Model.js')
    fake_curl = work / 'curl'
    fake_curl.write_text('''#!/usr/bin/env python3
import json, sys, time
from urllib.parse import urlparse, parse_qs
name = parse_qs(urlparse(sys.argv[-1]).query)['name'][0]
if name == 'Failure': sys.exit(22)
if name == 'Cairo': time.sleep(1)
print(json.dumps({'results': [{'id': 1, 'name': name, 'latitude': 24.69, 'longitude': 46.72, 'country_code': 'SA', 'country': 'Saudi Arabia'}]}))
''')
    fake_curl.chmod(0o755)
    qml = '''import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model
ShellRoot {
  id: root
  property bool arabic: false
  property bool opened: true
  property bool settingsOpen: true
  property int focusRestores: 0
  QtObject { id: backButton; function forceActiveFocus() { root.focusRestores++ } }
  property bool editingLocation: true
  property string countryFilter: ""
  property string locationDraft: ""
  property var locationSuggestions: []
  property int suggestionIndex: 0
  property string locationFeedback: ""
  property bool geocodeBusy: false
  property int geocodeGeneration: 0
  property var geocodeProcess: null
  property int saves: 0
  property int weatherAdoptions: 0
  property var salat: ({
    setLocation: function() { root.saves++ },
    adoptWeatherLocation: function() { root.weatherAdoptions++ }
  })
  function check(ok, message) {
    if (!ok) { console.error("FAILED: " + message); Qt.quit() }
  }
  function query(name) {
    editingLocation = true
    locationDraft = name
    requestGeocode(name)
  }
''' + search_code + '''
  Timer {
    id: cancelPending
    interval: 450
    onTriggered: { root.locationDraft = ""; root.requestGeocode("") }
  }
  Timer {
    id: steps
    property int step: 0
    interval: 1500
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      if (step === 0) root.query("Riyadh")
      else if (step === 1) {
        root.check(root.locationSuggestions.length === 1 && root.locationSuggestions[0].name === "Riyadh", "valid response retained before process exit")
        root.query("Cairo")
        cancelPending.start()
      } else if (step === 2) {
        root.check(!root.geocodeBusy && root.locationSuggestions.length === 0 && root.locationFeedback === "", "cleared input cancels pending response without stale results or errors")
        root.commitLocation()
        root.check(root.weatherAdoptions === 0 && root.saves === 0, "empty Enter does not change location")
        root.query("Failure")
      } else if (step === 3) {
        root.check(!root.geocodeBusy && root.locationSuggestions.length === 0 && root.locationFeedback !== "", "failed request shows recoverable feedback")
        root.query("Riyadh")
      } else if (step === 4) {
        root.commitLocation()
        root.check(root.saves === 1 && !root.editingLocation, "selected result commits once and closes search")
        root.query("Cairo")
        root.cancelEditLocation()
      } else if (step === 5) {
        root.check(!root.editingLocation && !root.geocodeBusy && root.locationSuggestions.length === 0, "closed search remains clear")
        root.check(root.focusRestores > 0, "closing search restores focus to a visible control")
        console.log("PASSED: search success, cancellation, empty Enter, connection failure, selected-city commit and focus restoration")
        Qt.quit()
      }
      step++
    }
  }
}
'''
    (work / 'shell.qml').write_text(qml)
    env = dict(os.environ, PATH=str(work) + os.pathsep + os.environ['PATH'], QT_QPA_PLATFORM='offscreen')
    result = subprocess.run(['quickshell', '-p', str(work)], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20)
    if result.returncode or 'PASSED:' not in result.stdout or 'FAILED:' in result.stdout:
        raise SystemExit(result.stdout)
    print(next(line[line.index('PASSED:'):] for line in result.stdout.splitlines() if 'PASSED:' in line))
