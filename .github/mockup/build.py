import json, html
sol = json.load(open('solar.json')); mdi = json.load(open('mdi.json'))
def body(n):
    if n == 'github': return mdi['icons']['github']['body']
    if n in sol['icons']: return sol['icons'][n]['body']
    a = sol.get('aliases', {}).get(n)
    return sol['icons'][a['parent']]['body']
def ic(n, cls='i'):
    return f'<svg class="{cls}" viewBox="0 0 24 24" aria-hidden="true">{body(n)}</svg>'

def tile(letter, c1, c2, glyph=None):
    inner = ic(glyph, 'tg') if glyph else f'<span>{letter}</span>'
    return f'<div class="tile" style="--c1:{c1};--c2:{c2}">{inner}</div>'

status = '''<div class="status"><span class="time">9:41</span><div class="island"></div>
<span class="sb"><svg viewBox="0 0 18 12"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5.5" width="3" height="6.5" rx="1"/><rect x="10" y="3" width="3" height="9" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg>
<svg viewBox="0 0 16 12"><path d="M8 2.6c2.3 0 4.4.9 6 2.4l1.1-1.2A10.2 10.2 0 0 0 8 1C5.3 1 2.8 2 .9 3.8L2 5C3.6 3.5 5.7 2.6 8 2.6Zm0 3.3c1.4 0 2.6.5 3.6 1.4l1.1-1.2A7 7 0 0 0 8 4.3a7 7 0 0 0-4.7 1.8l1.1 1.2c1-.9 2.2-1.4 3.6-1.4Zm0 3.3c.6 0 1.1.2 1.5.6L8 11.4 6.5 9.8c.4-.4.9-.6 1.5-.6Z"/></svg>
<span class="bat"><i></i></span></span></div>'''

def tabbar(active):
    tabs = [('Sources','global-linear'),('Library','widget-linear'),('Settings','settings-linear')]
    t = ''.join(f'<div class="tab{" on" if n==active else ""}">{ic(i)}<span>{n}</span></div>' for n,i in tabs)
    return f'<div class="tabbar"><div class="pill">{t}</div></div><div class="home"></div>'

def phone(content, active, bg='#fff'):
    return f'<div class="phone"><div class="screen" style="--bg:{bg};background:{bg}">{status}<div class="content">{content}</div>{tabbar(active)}</div></div>'

# Sources
repos = [('AltStore','apps.altstore.io','A','#3fc1b0','#178f8a'),
         ('Feather Repository','feather.madebynuz.dev','F','#a99bf5','#7b6fe0'),
         ('LiveContainer','livecontainer.github.io','L','#4c9bff','#1f63e6'),
         ('Ignited Source','ignitedemulator.com','I','#ffae4a','#f2672e'),
         ('Flyinghead','flyinghead.github.io','F','#c67cf5','#7b3fe0'),
         ('Ceylo’s Apps Hub','ceylo.dev','C','#ffd35c','#f0a21d'),
         ('OatmealDome','oatmealdome.me','O','#62d6ff','#2b8ff0')]
src = f'''<div class="bar"><span></span><span class="round">{ic('add-circle-linear')}</span></div>
<h1>Sources</h1><div class="search">{ic('magnifier-linear')}Search</div>
<div class="allrepo">{tile('', '#9aa3ff', '#6b74ec', 'global-linear')}<div><b>All Repositories</b><small>See all apps from your sources</small></div></div>
<div class="sec">Repositories <em>{len(repos)}</em></div>
''' + ''.join(f'<div class="row">{tile(l,a,b)}<div class="tx"><b>{html.escape(n)}</b><small>{u}</small></div></div>' for n,u,l,a,b in repos)

# Library
signed = [('StikNES','5.2 · com.stik.StikNES','S','#56c8ff','#1c7fe8','8 days','red'),
          ('LiveContainer','2.1.1 · com.kdt.livecontainer','L','#4c9bff','#1f63e6','96 days','green'),
          ('iTorrent','2.0.14 · com.xitrix.iTorrent2','T','#ffb36b','#f27a2e','347 days','green'),
          ('Delta','1.7.1 · com.rileytestut.Delta','D','#b07cff','#6a3fe0','347 days','green'),
          ('Aidoku','0.6.9 · xyz.skitty.Aidoku','A','#ff6b8a','#e0284f','347 days','green')]
imported = [('Winston','1.1.5 · lo.cafe.winston','W','#5b5b66','#2b2b33'),
            ('Provenance','3.0 · org.provenance-emu','P','#7dd36b','#2e9f45')]
lib = f'''<div class="bar"><span class="round">{ic('filter-linear')}</span><span class="round">{ic('add-circle-linear')}</span></div>
<h1>Library</h1><div class="search">{ic('magnifier-linear')}Search</div>
<div class="sec">Signed <em>{len(signed)}</em></div>
''' + ''.join(f'<div class="row">{tile(l,a,b)}<div class="tx"><b>{n}</b><small>{v}</small></div><span class="badge {c}">{d}</span></div>' for n,v,l,a,b,d,c in signed) + f'''
<div class="sec">Imported <em>{len(imported)}</em></div>
''' + ''.join(f'<div class="row">{tile(l,a,b)}<div class="tx"><b>{n}</b><small>{v}</small></div><span class="badge sign">Sign</span></div>' for n,v,l,a,b in imported)

# Settings
def grp(rows, header=None, footer=None):
    h = f'<div class="gh">{header}</div>' if header else ''
    f = f'<div class="gf">{footer}</div>' if footer else ''
    return h + '<div class="grp">' + ''.join(rows) + '</div>' + f
def srow(icon, label):
    return f'<div class="srow">{ic(icon, "si")}<span>{label}</span>{ic("alt-arrow-right-linear","chev")}</div>'
cert = f'''<div class="srow cert"><div class="tx"><b>Nuz Developer</b><small>Apple Development · 9X2K7LM4QD</small></div><span class="badge green">347 days</span>{ic("alt-arrow-right-linear","chev")}</div>'''
st = '<h1 class="s">Settings</h1>' + \
  grp([srow('download-square-linear','Updates')]) + \
  grp([srow('pallete-2-linear','Appearance'), srow('smartphone-linear','App Icon'), srow('sidebar-minimalistic-linear','Navigator')]) + \
  grp([cert, srow('verified-check-linear','Certificates')], 'Certificates', 'Add and manage certificates used for signing applications.') + \
  grp([srow('pen-new-square-linear','Signing Options'), srow('archive-linear','Archive &amp; Compression'), srow('round-arrow-down-linear','Installation'), srow('server-linear','Backup &amp; Transfer')], 'Features')

css = open('style.css').read()
page = f'''<!doctype html><html><head><meta charset="utf-8"><style>{css}</style></head><body>
<div class="stage">
<div class="p left">{phone(src,'Sources')}</div>
<div class="p mid">{phone(lib,'Library')}</div>
<div class="p right">{phone(st,'Settings','#f2f2f7')}</div>
</div></body></html>'''
open('phones.html','w').write(page)
print('ok')
