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
assert.equal(run(`parseGeocodingResults(JSON.stringify({results:[{name:'Null Island',latitude:null,longitude:null}]})).length`), 0);
assert.equal(run(`parseGeocodingResults(JSON.stringify({results:[{name:'Tokyo',latitude:35.68,longitude:139.69,country_code:'JP',timezone:'Asia/Tokyo'}]}))[0].countryCode`), 'JP');
for (let i = 0; i < 1500; i++) {
  const date = new Date(2023, 0, 1 + i);
  const h = context.gregorianToHijri(date);
  assert.ok(h.day >= 1 && h.day <= 30 && h.month >= 1 && h.month <= 12, `Invalid Hijri date on ${date}`);
}
console.log('Passed: null coordinate rejection, international country metadata and 1,500 consecutive Hijri dates.');
// Country filtering and offline setup are shipped data, not network requirements.
const countries = JSON.parse(readFileSync(path.join(__dirname, '../countries.json'), 'utf8'));
const presets = JSON.parse(readFileSync(path.join(__dirname, '../city-presets.json'), 'utf8'));
assert.equal(countries.length, 249);
assert.equal(new Set(countries.map(c=>c.code)).size, countries.length);
for (const [country,method] of [['SA','Makkah'],['EG','Egypt'],['US','ISNA'],['MY','Malaysia'],['ID','Indonesia']]) {
  assert.equal(context.methodForCountry(country),method);
  assert.ok(presets.some(p=>p.countryCode===country),`Missing city for ${country}`);
}
assert.match(context.geocodingUrl('Medina','SA','ar'), /countryCode=SA/);
assert.match(context.geocodingUrl('Cairo','EG','en'), /language=en/);
assert.doesNotMatch(context.geocodingUrl('City','<bad>','en'), /countryCode=/);
for(const city of presets) {
  assert.ok(countries.some(c=>c.code===city.countryCode));
  assert.ok(Math.abs(city.latitude)<=90 && Math.abs(city.longitude)<=180);
  const prayers=context.daySchedule(new Date(2026,10,6),city.latitude,city.longitude,context.methodForCountry(city.countryCode),'Standard',0);
  assert.equal(prayers.length,6);
  assert.ok(prayers.every(p=>Number.isFinite(p.date.getTime())),city.name);
  assert.ok(prayers.every((p,i)=>i===0||p.date>=prayers[i-1].date),city.name);
}
console.log(`Passed: ${countries.length} countries/territories, ${presets.length} offline city presets, country filters and regional calculation suggestions.`);

assert.equal(run('validLang(undefined)'), 'ar');
assert.equal(run('validLang("invalid")'), 'ar');
assert.equal(run('validLang("en")'), 'en');
assert.equal(run('formatNextCountdown(28 * 60000, "ar")'), 'بعد 28 دقيقة');
assert.equal(run('formatNextCountdown(2 * 60000, "ar")'), 'بعد دقيقتين');
assert.equal(run('formatNextCountdown(3 * 60000, "ar")'), 'بعد 3 دقائق');
assert.equal(run('formatNextCountdown(61 * 60000, "ar")'), 'بعد ساعة ودقيقة');
assert.equal(run('formatNextCountdown(120 * 60000, "ar")'), 'بعد ساعتين');
assert.equal(run('formatNextCountdown(28 * 60000, "en")'), 'in 28min');
assert.equal(run('formatNextCountdown(61 * 60000, "en")'), 'in 1h 1min');
assert.equal(run('formatNextCountdown(1, "en")'), 'in 1min');
assert.equal(run('formatNextCountdown(0, "ar")'), 'حان وقت الصلاة');
assert.equal(run(`localizedLocation('Agadir', 30.42, -9.598, [{name:'Agadir',nameAr:'أكادير',latitude:30.42,longitude:-9.598,countryCode:'MA'}], [{code:'MA',name:'Morocco',nameAr:'المغرب'}], 'ar')`), 'أكادير، المغرب');
assert.equal(run(`localizedLocation('My mosque', 30.42, -9.598, [{name:'Agadir',nameAr:'أكادير',latitude:30.42,longitude:-9.598,countryCode:'MA'}], [], 'ar')`), 'My mosque');
console.log('Passed: Arabic defaults, saved English preference, localized countdown grammar and location labels.');
assert.equal(run('formatCountdownShort(59 * 60000, "ar")'), '\u206759 د\u2069');
assert.equal(run('formatCountdownShort(80 * 60000, "ar")'), '\u20671 س 20 د\u2069');
assert.equal(run('formatCountdownShort(600, "ar")'), '\u2067أقل من دقيقة\u2069');
assert.equal(run('formatCountdownShort(80 * 60000, "en")'), '1h 20m');
for (const style of ['full', 'name', 'countdown', 'compact']) {
  const label = run(`barLabel('${style}', {prayer:{id:'asr',date:new Date(2026,10,7,15,26)}}, new Date(2026,10,7,14,6), 'ar')`);
  assert.ok(label.startsWith('\u2067') && label.endsWith('\u2069'));
  assert.equal((label.match(/\u2067/g)||[]).length, (label.match(/\u2069/g)||[]).length);
  assert.doesNotMatch(label, /[hm]/);
}
console.log('Passed: Arabic bar units, balanced bidi isolation and all bar-label styles.');

// Habous HTML parsing must stay linear: a hostile or corrupted response with
// unclosed tags previously blocked the shell thread for quadratic time.
const habousRow = '<tr><td>Dimanche</td><td>28</td><td>8</td><td>06:12</td><td>07:30</td><td>12:40</td><td>15:30</td><td>18:20</td><td>19:40</td></tr>';
assert.deepEqual(
  Array.from(run(`parseHabousDay(${JSON.stringify('<table><tbody>'+habousRow+'</tbody></table>')}, new Date(2026,10,8))`)),
  ['06:12','07:30','12:40','15:30','18:20','19:40']
);
assert.equal(run(`parseHabousDay(${JSON.stringify(habousRow)}, new Date(2026,10,9))`), null);
assert.equal(run('stripTags("a<><b>x</b>")'), 'a<>x');
assert.equal(run('stripTags("\\u00a0 a b \\u00a0")'), 'a b');
assert.equal(run('stripTags("a" + " ".repeat(1000) + "b")'), 'a' + ' '.repeat(1000) + 'b');
for (const [name, html] of [
  ['unclosed rows', '<tr>'.repeat(262144)],
  ['unclosed cells', '<tr>' + '<td>'.repeat(262144) + '</tr>'],
  ['bracket run in a cell', '<tr><td>' + '<'.repeat(262144) + '</td></tr>'],
  ['whitespace run in a cell', '<tr><td>a' + ' '.repeat(262144) + 'b</td></tr>'],
  ['oversized response', '<tr>'.repeat(300000)],
]) {
  const started = process.hrtime.bigint();
  assert.equal(run(`parseHabousDay(${JSON.stringify(html)}, new Date(2026,10,8))`), null, name);
  const elapsedMs = Number(process.hrtime.bigint() - started) / 1e6;
  assert.ok(elapsedMs < 2000, `${name} took ${elapsedMs.toFixed(0)}ms`);
}
console.log('Passed: Habous table parsing, weekday/day matching and linear handling of malformed or oversized HTML.');
