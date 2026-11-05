const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const context = vm.createContext({ Date, Math, JSON, isFinite, parseInt, Number, String });
vm.runInContext(readFileSync(path.join(__dirname, '../Model.js'), 'utf8'), context);
const run = code => vm.runInContext(code, context);
assert.equal(run('parseGeocodingResults("invalid").length'), 0);
assert.equal(run('parseGeocodingResults("x".repeat(262145)).length'), 0);
assert.equal(run(`parseGeocodingResults(JSON.stringify({results:[{name:"Bad",latitude:91,longitude:0}]})).length`), 0);
assert.equal(run(`parseGeocodingResults(JSON.stringify({results:Array.from({length:10},()=>({name:"City",latitude:30,longitude:-9}))})).length`), 5);
assert.equal(run(`parseGeocodingResults(JSON.stringify({results:[{name:'<img src="https://example.invalid/tracker">',latitude:30,longitude:-9}]}))[0].name`), '<img src="https://example.invalid/tracker">');
for (const file of ['PlainLabel.qml']) {
  assert.match(readFileSync(path.join(__dirname, '..', file), 'utf8'), /textFormat: Text.PlainText/);
}
assert.equal(run('clampOffsetMinutes(500, 0)'), 30);
const schedule = run('daySchedule(new Date(2026,10,5),30.42018,-9.59815,"Morocco","Standard",0)');
assert.equal(schedule.length, 6);
assert.ok(schedule.every(p => Number.isFinite(p.date.getTime())));
assert.ok(schedule.every((p,i) => i === 0 || p.date > schedule[i-1].date));
console.log('Passed: bounded geocoding, invalid coordinates, literal markup, offset limits, and six ordered offline prayer times.');
