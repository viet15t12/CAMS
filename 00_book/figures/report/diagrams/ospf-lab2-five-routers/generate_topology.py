"""Generate matching editable draw.io and vector SVG diagrams for Lab 2."""
from pathlib import Path
from urllib.parse import quote, unquote
from xml.sax.saxutils import escape
import xml.etree.ElementTree as ET
import runpy

OUT = Path(__file__).resolve().parent
REFERENCE = OUT.parent / "dhcp-snooping-lab/topology-redrawn.drawio"
WIDTH, HEIGHT = 1400, 1020
INK, BLUE, MGMT = "#17212b", "#036d91", "#60798c"
reference = ET.parse(REFERENCE).getroot()


def reference_icon(cell_id):
    cell = next(c for c in reference.iter("mxCell") if c.get("id") == cell_id)
    return unquote(cell.get("style").split("image=data:image/svg+xml,", 1)[1].split(";", 1)[0])


router = reference_icon("r1-icon")
switch = reference_icon("sw-icon")
cloud = reference_icon("mgmt-icon")
pc = '''<svg xmlns="http://www.w3.org/2000/svg" width="110" height="78" viewBox="0 0 110 78"><rect x="3" y="3" width="104" height="60" rx="5" fill="white" stroke="#036d91" stroke-width="3"/><rect x="9" y="9" width="92" height="48" fill="#036d91"/><path d="M47 63H63V71H81V76H29V71H47Z" fill="#036d91"/></svg>'''
icons = []
labels = []
edges = []


def icon(key, cx, y, art, w=130, h=80):
    icons.append((key, cx-w/2, y, w, h, art))


def label(key, text, cx, y, w=220, fs=23, bold=False, color=INK, background=False, align="center"):
    labels.append(dict(id=key, text=text, x=cx-w/2 if align=="center" else cx, y=y,
                       w=w, h=30, fs=fs, bold=bold, color=color, background=background, align=align))


def edge(key, src, dst, points, anchors, management=False):
    edges.append((key, src, dst, points, anchors, management))


icon("mgmt-m", 270, 5, cloud, 210, 92)
icon("mgmt-ma", 1000, 5, cloud, 210, 92)
for key, cx, name in [("mgmt-m",270,"ManagementM"),("mgmt-ma",1000,"ManagementMA")]:
    label(key+"-name",name,cx,48,w=205,fs=22)
    label(key+"-network","192.168.122.0/24",cx,118,w=260,fs=22,color=MGMT,background=True)

for key, cx, y in [("r1",150,570),("r2",490,570),("r3",590,300),("r4",900,300),("r5",1190,300)]:
    icon(key,cx,y,router)
    if key=="r5":
        label(key+"-name","R5",1270,403,w=100,fs=28,bold=True)
        label(key+"-rid","RID: 5.5.5.5",1280,439,w=200,fs=22)
    elif key in ('r1', 'r2'):
        # Leave the LAN wire clear for its two endpoint badges.
        name_cx, rid_cx = (265, 300) if key == 'r1' else (615, 650)
        label(key+"-name",key.upper(),name_cx,y+96,w=100,fs=28,bold=True,background=True)
        n=key[-1]
        label(key+"-rid",f"RID: {n}.{n}.{n}.{n}",rid_cx,y+132,w=205,fs=22,background=True)
    else:
        label(key+"-name",key.upper(),cx,y+96,w=100,fs=28,bold=True,background=True)
        n=key[-1]
        label(key+"-rid",f"RID: {n}.{n}.{n}.{n}",cx,y+132,w=205,fs=22,background=True)
icon("sw1",300,300,switch)
icon("sw2",1190,570,switch)
label("sw1-name","SW1",300,251,w=100,fs=28,bold=True,background=True)
label("shared-network","10.1.123.0/24",300,214,w=235,fs=23,background=True)
label("sw2-name","SW2",1190,666,w=100,fs=28,bold=True)
label("lan50","192.168.50.0/24",1190,707,w=255,fs=23)
label("area","OSPF",660,65,w=300,fs=24,bold=True)
label("net34","10.1.34.0/24",745,270,w=210,fs=23,background=True)
label("net45","10.1.45.0/24",1045,270,w=210,fs=23,background=True)

for key,cx,ip in [("vpc8",150,"192.168.10.10/24"),("vpc9",490,"192.168.20.10/24"),
                  ("vpc10",1000,"192.168.50.10/24"),("vpc11",1280,"192.168.50.11/24")]:
    icon(key,cx,830,pc,110,78)
    label(key+"-name",key.upper(),cx,920,w=130,fs=26,bold=True)
    label(key+"-ip",ip,cx,954,w=235,fs=22)
label("lan10","192.168.10.0/24",150,745,w=260,fs=23,background=True)
label("lan20","192.168.20.0/24",490,745,w=260,fs=23,background=True)

# Management links retain the two clouds and seven device attachments in EVE-NG.
edge("mgmt-r1","mgmt-m","r1",[(270,97),(270,180),(50,180),(50,610),(85,610)],(.5,1,0,.5),True)
edge("mgmt-sw1","mgmt-m","sw1",[(270,97),(270,180),(190,180),(190,320),(235,320)],(.5,1,0,.25),True)
edge("mgmt-r3","mgmt-m","r3",[(270,97),(270,180),(590,180),(590,300)],(.5,1,.5,0),True)
edge("mgmt-r2","mgmt-ma","r2",[(1000,97),(1000,180),(750,180),(750,610),(555,610)],(.5,1,1,.5),True)
edge("mgmt-r4","mgmt-ma","r4",[(1000,97),(1000,180),(900,180),(900,300)],(.5,1,.5,0),True)
edge("mgmt-r5","mgmt-ma","r5",[(1000,97),(1000,180),(1190,180),(1190,300)],(.5,1,.5,0),True)
edge("mgmt-sw2","mgmt-ma","sw2",[(1000,97),(1000,180),(1370,180),(1370,540),(1222.5,540),(1222.5,570)],(.5,1,.75,0),True)

# Ten data links; SW1 is a shared L2 transit segment, not a router.
edge("data-r1-sw1","sw1","r1",[(267.5,380),(267.5,470),(150,470),(150,570)],(.25,1,.5,0))
edge("data-r2-sw1","sw1","r2",[(332.5,380),(332.5,470),(490,470),(490,570)],(.75,1,.5,0))
edge("data-r3-sw1","sw1","r3",[(365,340),(525,340)],(1,.5,0,.5))
edge("data-r3-r4","r3","r4",[(655,340),(835,340)],(1,.5,0,.5))
edge("data-r4-r5","r4","r5",[(965,340),(1125,340)],(1,.5,0,.5))
edge("data-r5-sw2","r5","sw2",[(1190,380),(1190,570)],(.5,1,.5,0))
edge("data-r1-vpc8","r1","vpc8",[(150,650),(150,830)],(.5,1,.5,0))
edge("data-r2-vpc9","r2","vpc9",[(490,650),(490,830)],(.5,1,.5,0))
edge("data-sw2-vpc10","sw2","vpc10",[(1125,610),(1000,610),(1000,830)],(0,.5,.5,0))
edge("data-sw2-vpc11","sw2","vpc11",[(1255,610),(1280,610),(1280,830)],(1,.5,.5,0))

label("legend-data","Kết nối dữ liệu",265,992,w=260,fs=22,align="left")
label("legend-mgmt","Kết nối quản trị",815,992,w=280,fs=22,color=MGMT,align="left")

# Both exports use identical geometry and labels, with embedded vector icons.
svg=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">',
     '<title>Lab 2 - OSPF trên năm router</title>',
     '<desc>VPC8 nối R1, VPC9 nối R2. R1, R2 và R3 dùng mạng trung chuyển qua SW1. R3 nối R4, R4 nối R5, R5 nối SW2 và hai máy trạm VPC10/VPC11. Mạng quản trị không tham gia OSPF.</desc>',
     f'<rect width="{WIDTH}" height="{HEIGHT}" fill="white"/>']
for key,src,dst,points,anchors,management in edges:
    svg.append(f'<polyline id="{key}" points="'+" ".join(f"{x},{y}" for x,y in points)+
               f'" fill="none" stroke="{MGMT if management else INK}" stroke-width="2.4"'+
               (' stroke-dasharray="8 6"' if management else '')+'/>')
for key,x,y,w,h,art in icons:
    inner=art[art.index('>')+1:art.rindex('</svg>')]
    svg.append(f'<g id="{key}" transform="translate({x} {y})">{inner}</g>')
for l in labels:
    if l['background']:
        svg.append(f'<rect x="{l["x"]}" y="{l["y"]}" width="{l["w"]}" height="{l["h"]}" fill="white"/>')
    x=l['x']+l['w']/2 if l['align']=='center' else l['x']
    anchor='middle' if l['align']=='center' else 'start'
    svg.append(f'<text id="{l["id"]}" x="{x}" y="{l["y"]+l["h"]*.78}" text-anchor="{anchor}" font-family="Arial, Liberation Sans, sans-serif" font-size="{l["fs"]}" font-weight="{700 if l["bold"] else 400}" fill="{l["color"]}">{escape(l["text"])}</text>')
for x,color,dashed in [(190,INK,False),(740,MGMT,True)]:
    svg.append(f'<line x1="{x}" y1="1007" x2="{x+55}" y2="1007" stroke="{color}" stroke-width="2.4"'+(' stroke-dasharray="8 6"' if dashed else '')+'/>')
svg.append('</svg>')
(OUT/'topology-redrawn.svg').write_text('\n'.join(svg))

mx=ET.Element('mxfile',host='app.diagrams.net',agent='CAMS report diagram',type='device')
dia=ET.SubElement(mx,'diagram',id='lab2-ospf-five-routers',name='Lab 2 - OSPF')
model=ET.SubElement(dia,'mxGraphModel',dx=str(WIDTH),dy=str(HEIGHT),grid='1',gridSize='10',guides='1',tooltips='1',connect='1',arrows='1',fold='1',page='1',pageScale='1',pageWidth=str(WIDTH),pageHeight=str(HEIGHT),math='0',shadow='0',background='#ffffff')
rt=ET.SubElement(model,'root')
ET.SubElement(rt,'mxCell',id='0')
ET.SubElement(rt,'mxCell',id='1',parent='0')


def geometry(cell,x,y,w,h):
    ET.SubElement(cell,'mxGeometry',x=str(x),y=str(y),width=str(w),height=str(h),attrib={'as':'geometry'})


for key,x,y,w,h,art in icons:
    c=ET.SubElement(rt,'mxCell',id=key,value='',style='shape=image;imageAspect=0;aspect=fixed;image=data:image/svg+xml,'+quote(art,safe='')+';',vertex='1',parent='1')
    geometry(c,x,y,w,h)
for key,src,dst,points,anchors,management in edges:
    ex,ey,tx,ty=anchors
    style=f'edgeStyle=none;rounded=0;html=0;endArrow=none;startArrow=none;strokeColor={MGMT if management else INK};strokeWidth=2.4;exitX={ex};exitY={ey};exitDx=0;exitDy=0;entryX={tx};entryY={ty};entryDx=0;entryDy=0;'
    if management: style+='dashed=1;dashPattern=8 6;'
    c=ET.SubElement(rt,'mxCell',id=key,value='',style=style,edge='1',parent='1',source=src,target=dst)
    g=ET.SubElement(c,'mxGeometry',relative='1',attrib={'as':'geometry'})
    if len(points)>2:
        ar=ET.SubElement(g,'Array',attrib={'as':'points'})
        for x,y in points[1:-1]: ET.SubElement(ar,'mxPoint',x=str(x),y=str(y))
for l in labels:
    style=f'text;html=0;strokeColor=none;fillColor={"#ffffff" if l["background"] else "none"};align={l["align"]};verticalAlign=middle;whiteSpace=wrap;rounded=0;fontFamily=Arial;fontSize={l["fs"]};fontColor={l["color"]};fontStyle={1 if l["bold"] else 0};'
    c=ET.SubElement(rt,'mxCell',id=l['id'],value=l['text'],style=style,vertex='1',parent='1')
    geometry(c,l['x'],l['y'],l['w'],l['h'])
for key,x,color,dashed in [('legend-data-line',190,INK,False),('legend-mgmt-line',740,MGMT,True)]:
    c=ET.SubElement(rt,'mxCell',id=key,value='',style=f'endArrow=none;startArrow=none;strokeColor={color};strokeWidth=2.4;'+('dashed=1;dashPattern=8 6;' if dashed else ''),edge='1',parent='1')
    g=ET.SubElement(c,'mxGeometry',relative='1',attrib={'as':'geometry'})
    ET.SubElement(g,'mxPoint',x=str(x),y='1007',attrib={'as':'sourcePoint'})
    ET.SubElement(g,'mxPoint',x=str(x+55),y='1007',attrib={'as':'targetPoint'})
ET.indent(mx,space='  ')
ET.ElementTree(mx).write(OUT/'topology-redrawn.drawio',encoding='utf-8',xml_declaration=True)

assert len(icons)==13
assert len(edges)==17 and sum(e[-1] for e in edges)==7
assert len({c.get('id') for c in rt})==len(rt)
ET.parse(OUT/'topology-redrawn.svg')
print('Generated Lab 2: 5 routers, 2 switches, 4 PCs, 2 management clouds, 17 links.')
runpy.run_path(str(OUT.parent/'inline_port_labels.py'))['apply_labels'](OUT)
