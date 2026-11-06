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
assert.equal(run('prayerName("dhuhr","en", new Date(2026,10,6))'), "Jumu'ah");
assert.equal(run('prayerName("dhuhr","ar", new Date(2026,10,6))'), "الجمعة");
assert.equal(run('prayerName("dhuhr","en", new Date(2026,10,5))'), "Dhuhr");
const qibla = run('qiblaBearing(30.42,-9.598)');
assert.ok(qibla > 80 && qibla < 110, 'Agadir qibla ' + qibla);
assert.equal(run('duePrayers([{id:"asr",date:new Date(Date.now()-5000)}], new Date(), 20000).length'), 1);
assert.equal(run('duePrayers([{id:"sunrise",date:new Date(Date.now()-5000)}], new Date(), 20000).length'), 0);
assert.equal(run('duePrayers([{id:"asr",date:new Date(Date.now()-60000)}], new Date(), 20000).length'), 0);
const winter = run('daySchedule(new Date(2026,11,21),69,25,"MWL","Standard",0)');
assert.equal(winter.length, 6);
assert.ok(winter.every(p => Number.isFinite(p.date.getTime())));
const friday = new Date(2026, 10, 6, 16, 0, 0);
const rows = run(`enrichSchedule(daySchedule(new Date(2026,10,6,16,0,0),30.42,-9.598,"Morocco","Standard",0), new Date(2026,10,6,16,0,0), "en")`);
const dhuhr = rows.find(r => r.id === 'dhuhr');
assert.equal(dhuhr.name, "Jumu'ah");
assert.ok(['passed', 'now', 'next'].includes(dhuhr.status));
console.log('Passed: bounded geocoding, invalid coordinates, literal markup, offset limits, six ordered offline prayer times, Jumu\'ah, qibla, and adhan window.');
// Calendar regressions: the old floor/truncation conversion was months out.
for (const [date, expected] of [['2024-03-11T12:00:00',[1445,9,1]],['2024-04-10T12:00:00',[1445,10,1]],['2026-11-06T12:00:00',[1448,5,25]]]) {
  const h = run(`gregorianToHijri(new Date('${date}'))`);
  assert.deepEqual([h.year,h.month,h.day], expected);
}
assert.equal(run("gregorianToHijri(new Date(2024,3,10), -1).month"), 9);
assert.equal(run("parseHm('25:00')"), null);
assert.equal(run("parseHm('12:70')"), null);
assert.equal(run("parseLocationFile('{\"latitude\":91,\"longitude\":0}').latitude"), null);
const remote = JSON.stringify({data:{timings:Object.fromEntries(['Fajr','Sunrise','Dhuhr','Asr','Maghrib','Isha'].map(k=>[k,'2026-11-06T12:00:00+09:00']))}});
assert.equal(run(`scheduleFromAladhan(${JSON.stringify(remote)},new Date(2026,10,6))[0].date.getTime()`), Date.parse('2026-11-06T03:00:00Z'));
console.log('Passed: Hijri known dates and adjustment, invalid clocks, weather coordinate bounds, timezone-aware API timestamps.');
