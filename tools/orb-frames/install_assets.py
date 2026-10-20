import sys, json, os, shutil
frames_dir, res_dir = sys.argv[1], sys.argv[2]
counts = json.load(open(os.path.join(frames_dir, 'frames.json')))
runners = os.path.join(res_dir, 'Media.xcassets', 'Runners')
for name in os.listdir(runners):
    p = os.path.join(runners, name)
    if os.path.isdir(p):
        shutil.rmtree(p)
info = {"info": {"author": "xcode", "version": 1}}
for state, n in counts.items():
    folder = os.path.join(runners, state.capitalize())
    os.makedirs(folder)
    json.dump(info, open(os.path.join(folder, 'Contents.json'), 'w'), indent=2)
    for i in range(n):
        name = f'{state}-frame-{i}'
        d = os.path.join(folder, name + '.imageset'); os.makedirs(d)
        shutil.copy(os.path.join(frames_dir, state, f'frame-{i}.png'), os.path.join(d, name + '.png'))
        json.dump({"images": [{"filename": name + '.png', "idiom": "mac"}], **info}, open(os.path.join(d, 'Contents.json'), 'w'), indent=2)
names = {
    'working': ('Working', '작업 중', '作業中'), 'searching': ('Searching', '검색 중', '検索中'),
    'solving': ('Solving', '푸는 중', '解決中'), 'listening': ('Listening', '듣는 중', '聞き取り中'),
    'connecting': ('Connecting', '연결 중', '接続中'), 'weaving': ('Weaving', '엮는 중', '編み込み中'),
    'composing': ('Composing', '작성 중', '作成中'), 'breathing': ('Breathing', '숨쉬기', '呼吸'),
    'shaping': ('Shaping', '모양 바꾸기', '変形中'),
}
unit = lambda v: {"stringUnit": {"state": "translated", "value": v}}
strings = {k: {"localizations": {"en": unit(en), "ko": unit(ko), "ja": unit(ja)}} for k, (en, ko, ja) in names.items()}
path = os.path.join(res_dir, 'RunnerNames.xcstrings')
doc = json.load(open(path)); doc['strings'] = strings
open(path, 'w').write(json.dumps(doc, ensure_ascii=False, indent=2, separators=(',', ' : ')) + '\n')
print(counts)
