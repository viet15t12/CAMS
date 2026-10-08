"""Draw Lab 5 from the EVE-NG screenshot and the verified report address plan."""
from pathlib import Path
from urllib.parse import quote, unquote
from xml.sax.saxutils import escape
import xml.etree.ElementTree as ET
import math

OUT = Path(__file__).resolve().parent
WIDTH, HEIGHT = 1400, 1210
INK, MGMT = "#17212b", "#60798c"
reference = ET.parse(OUT.parent / "dhcp-snooping-lab/topology-redrawn.drawio").getroot()


def reference_icon(cell_id):
    cell = next(c for c in reference.iter("mxCell") if c.get("id") == cell_id)
    return unquote(cell.get("style").split("image=data:image/svg+xml,", 1)[1].split(";", 1)[0])


router = reference_icon("r1-icon")
switch = reference_icon("sw-icon")
cloud = reference_icon("mgmt-icon")
pc = '''<svg xmlns="http://www.w3.org/2000/svg" width="110" height="78" viewBox="0 0 110 78"><rect x="3" y="3" width="104" height="60" rx="5" fill="white" stroke="#036d91" stroke-width="3"/><rect x="9" y="9" width="92" height="48" fill="#036d91"/><path d="M47 63H63V71H81V76H29V71H47Z" fill="#036d91"/></svg>'''
icons, labels, edges, port_tags = [], [], [], []


def icon(key, cx, y, art, w=130, h=80):
    icons.append((key, cx-w/2, y, w, h, art))


def label(key, text, cx, y, w=220, fs=23, bold=False, color=INK, background=False, align="center"):
    labels.append(dict(id=key, text=text, x=cx-w/2 if align=="center" else cx, y=y,
                       w=w, h=30, fs=fs, bold=bold, color=color, background=background, align=align))


def edge(key, src, dst, points, anchors, management=False):
    edges.append((key, src, dst, points, anchors, management))


icon("mgmt-left",260,5,cloud,210,92)
icon("mgmt-right",965,5,cloud,210,92)
label("mgmt-left-name","Management",260,48,w=200,fs=22)
label("mgmt-right-name","ManagementMa",965,48,w=205,fs=22)
for key,cx in [("mgmt-left",260),("mgmt-right",965)]:
    label(key+"-network","192.168.122.0/24",cx,111,w=260,fs=22,color=MGMT,background=True)
label("title","ACL",650,50,w=220,fs=28,bold=True)

for key,cx,y in [("r1",240,240),("r2",710,240),("r3",1160,240)]:
    icon(key,cx,y,router)
label("r1-name","R1",150,339,w=100,fs=28,bold=True)
label("r1-role","Liên VLAN",150,377,w=200,fs=23)
label("r1-acl","ACL",150,409,w=100,fs=23)
label("r2-name","R2",710,339,w=100,fs=28,bold=True)
label("r2-role","NAT",710,377,w=100,fs=23)
label("r3-name","R3",1270,339,w=100,fs=28,bold=True)
label("r3-role","ISP / HTTP",1270,377,w=190,fs=23)
label("r3-loopback-name","Loopback0",1000,350,w=220,fs=23)
label("r3-loopback-ip","203.162.4.1/32",1000,384,w=250,fs=23)
label("r1-r2-network","192.168.12.0/24",475,221,w=270,fs=24)
label("r2-r3-network","203.162.2.0/30",935,221,w=255,fs=24)
label("trunk","Trunk VLAN 10, 20, 30",465,379,w=320,fs=23)

for key,cx,y in [("sw1",460,490),("sw2",180,740),("sw3",870,740)]:
    icon(key,cx,y,switch)
    label(key+"-name",key.upper(),cx,y+96,w=120,fs=28,bold=True,background=True)

for key,cx,vlan,ip in [("vpc7",180,10,"192.168.10.1/24"),
                       ("vpc8",740,20,"192.168.20.1/24"),
                       ("vpc9",1080,30,"192.168.30.1/24")]:
    icon(key,cx,1000,pc,110,78)
    label(key+"-name",key.upper()+f" - VLAN {vlan}",cx,1094,w=300,fs=25,bold=True)
    label(key+"-ip",ip,cx,1132,w=260,fs=23)
icon("vpc10",1160,530,pc,110,78)
label("vpc10-name","VPC10",1160,623,w=140,fs=26,bold=True)

# Six management links, preserving the two source cloud memberships.
edge("mgmt-r1","mgmt-left","r1",[(260,97),(260,150),(240,150),(240,240)],(.5,1,.5,0),True)
edge("mgmt-sw1","mgmt-left","sw1",[(260,97),(260,150),(70,150),(70,450),(440.5,450),(440.5,490)],(.5,1,.35,0),True)
edge("mgmt-sw2","mgmt-left","sw2",[(260,97),(260,150),(35,150),(35,780),(115,780)],(.5,1,0,.5),True)
edge("mgmt-r2","mgmt-right","r2",[(965,97),(965,150),(710,150),(710,240)],(.5,1,.5,0),True)
edge("mgmt-r3","mgmt-right","r3",[(965,97),(965,150),(1160,150),(1160,240)],(.5,1,.5,0),True)
edge("mgmt-sw3","mgmt-right","sw3",[(965,97),(965,150),(1370,150),(1370,780),(935,780)],(.5,1,1,.5),True)

# Twelve data links, including both members of each paired switch connection.
edge("data-r1-r2","r1","r2",[(305,280),(645,280)],(1,.5,0,.5))
edge("data-r2-r3","r2","r3",[(775,280),(1095,280)],(1,.5,0,.5))
edge("data-r1-sw1","r1","sw1",[(272.5,320),(272.5,420),(460,420),(460,490)],(.75,1,.5,0))
edge("data-r3-vpc10","r3","vpc10",[(1160,320),(1160,530)],(.5,1,.5,0))
edge("data-sw1-sw2-a","sw1","sw2",[(395,510),(147.5,740)],(0,.25,.25,0))
edge("data-sw1-sw2-b","sw1","sw2",[(395,550),(212.5,740)],(0,.75,.75,0))
edge("data-sw1-sw3-a","sw1","sw3",[(525,510),(902.5,740)],(1,.25,.75,0))
edge("data-sw1-sw3-b","sw1","sw3",[(525,550),(837.5,740)],(1,.75,.25,0))
edge("data-sw2-sw3","sw2","sw3",[(245,780),(805,780)],(1,.5,0,.5))
edge("data-sw2-vpc7","sw2","vpc7",[(180,820),(180,1000)],(.5,1,.5,0))
edge("data-sw3-vpc8","sw3","vpc8",[(837.5,820),(837.5,930),(740,930),(740,1000)],(.25,1,.5,0))
edge("data-sw3-vpc9","sw3","vpc9",[(902.5,820),(902.5,930),(1080,930),(1080,1000)],(.75,1,.5,0))

# Position labels by distance along their own wire, not free canvas coordinates.
# The draw.io labels are children of the edge and move with that connection.
port_mapping = {
    "data-r1-r2": ("Gi0/2", "Gi0/2", 65, 65),
    "data-r2-r3": ("Gi0/3", "Gi0/3", 65, 65),
    "data-r1-sw1": ("Gi0/1", "Gi0/3", 55, 60),
    "data-r3-vpc10": ("Gi0/1", "eth0", 50, 30),
    "data-sw1-sw2-a": ("Gi0/1", "Gi0/1", 70, 70),
    "data-sw1-sw2-b": ("Gi0/2", "Gi0/2", 70, 70),
    "data-sw1-sw3-a": ("Gi1/1", "Gi1/1", 70, 70),
    "data-sw1-sw3-b": ("Gi1/0", "Gi1/0", 70, 70),
    "data-sw2-sw3": ("Gi0/3", "Gi0/3", 65, 65),
    "data-sw2-vpc7": ("Gi1/0", "eth0", 80, 30),
    "data-sw3-vpc8": ("Gi1/2", "eth0", 65, 30),
    "data-sw3-vpc9": ("Gi1/3", "eth0", 100, 30),
}


def wire_point(points, distance):
    lengths = [math.hypot(b[0]-a[0], b[1]-a[1]) for a,b in zip(points, points[1:])]
    total = sum(lengths)
    remaining = min(max(distance, 0), total)
    for (a,b), length in zip(zip(points, points[1:]), lengths):
        if remaining <= length:
            fraction = remaining / length
            dx,dy = b[0]-a[0], b[1]-a[1]
            angle = math.degrees(math.atan2(dy,dx))
            if angle > 90: angle -= 180
            if angle < -90: angle += 180
            if abs(dx)<0.01 or abs(dy)<0.01: angle=0
            return a[0]+fraction*dx, a[1]+fraction*dy, angle, total
        remaining -= length
    raise ValueError("No segment for port label")


for key,src,dst,points,anchors,management in edges:
    total=sum(math.hypot(b[0]-a[0],b[1]-a[1]) for a,b in zip(points,points[1:]))
    if management:
        end_distance={"mgmt-sw1":100,"mgmt-sw2":45,"mgmt-sw3":60}.get(key,40)
        specs=[("target","Gi0/0",total-end_distance)]
    else:
        source_port,target_port,source_distance,target_distance=port_mapping[key]
        specs=[("source",source_port,source_distance),("target",target_port,total-target_distance)]
    for endpoint,text,distance in specs:
        cx,cy,angle,total=wire_point(points,distance)
        port_tags.append(dict(id=f"port-{key}-{endpoint}",edge=key,text=text,cx=cx,cy=cy,
                              angle=angle,relative=2*distance/total-1,w=76 if text!="eth0" else 58,
                              h=28,color=MGMT if management else INK))
label("legend-data","Kết nối dữ liệu",255,1179,w=270,fs=23,align="left")
label("legend-mgmt","Kết nối quản trị",820,1179,w=280,fs=23,color=MGMT,align="left")

svg=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">',
     '<title>Lab 5 - Kiểm chứng ACL và nhật ký an ninh</title>',
     '<desc>R1 nối R2 và SW1; R2 nối R3. SW1 nối kép tới SW2 và SW3, SW2 nối SW3. VPC7 thuộc VLAN 10, VPC8 thuộc VLAN 20, VPC9 thuộc VLAN 30. VPC10 nối R3. Đường quản trị dùng nét đứt.</desc>',
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
for p in port_tags:
    svg.append(f'<g id="{p["id"]}" transform="translate({p["cx"]} {p["cy"]}) rotate({p["angle"]})">'
               f'<rect x="{-p["w"]/2}" y="{-p["h"]/2}" width="{p["w"]}" height="{p["h"]}" rx="5" fill="white" stroke="#c8d2dc" stroke-width="1"/>'
               f'<text x="0" y="7" text-anchor="middle" font-family="Arial, Liberation Sans, sans-serif" font-size="20" fill="{p["color"]}">{escape(p["text"])}</text></g>')
for x,color,dashed in [(180,INK,False),(745,MGMT,True)]:
    svg.append(f'<line x1="{x}" y1="1194" x2="{x+55}" y2="1194" stroke="{color}" stroke-width="2.4"'+(' stroke-dasharray="8 6"' if dashed else '')+'/>')
svg.append('</svg>')
(OUT/'topology-redrawn.svg').write_text('\n'.join(svg))

mx=ET.Element('mxfile',host='app.diagrams.net',agent='CAMS report diagram',type='device')
dia=ET.SubElement(mx,'diagram',id='lab5-acl',name='Lab 5 - ACL')
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
for p in port_tags:
    style=f'rounded=1;arcSize=25;html=0;align=center;verticalAlign=middle;resizable=0;points=[];fillColor=#ffffff;strokeColor=#c8d2dc;strokeWidth=1;fontFamily=Arial;fontSize=20;fontColor={p["color"]};rotation={p["angle"]};'
    c=ET.SubElement(rt,'mxCell',id=p['id'],value=p['text'],style=style,vertex='1',connectable='0',parent=p['edge'])
    g=ET.SubElement(c,'mxGeometry',x=str(p['relative']),y='0',width=str(p['w']),height=str(p['h']),relative='1',attrib={'as':'geometry'})
    ET.SubElement(g,'mxPoint',x=str(-p['w']/2),y=str(-p['h']/2),attrib={'as':'offset'})
for key,x,color,dashed in [('legend-data-line',180,INK,False),('legend-mgmt-line',745,MGMT,True)]:
    c=ET.SubElement(rt,'mxCell',id=key,value='',style=f'endArrow=none;startArrow=none;strokeColor={color};strokeWidth=2.4;'+('dashed=1;dashPattern=8 6;' if dashed else ''),edge='1',parent='1')
    g=ET.SubElement(c,'mxGeometry',relative='1',attrib={'as':'geometry'})
    ET.SubElement(g,'mxPoint',x=str(x),y='1194',attrib={'as':'sourcePoint'})
    ET.SubElement(g,'mxPoint',x=str(x+55),y='1194',attrib={'as':'targetPoint'})
ET.indent(mx,space='  ')
ET.ElementTree(mx).write(OUT/'topology-redrawn.drawio',encoding='utf-8',xml_declaration=True)
assert len(icons)==12
assert len(edges)==18 and sum(e[-1] for e in edges)==6
assert len(port_tags)==30
assert len({c.get('id') for c in rt})==len(rt)
ET.parse(OUT/'topology-redrawn.svg')
print('Generated Lab 5: 3 routers, 3 switches, 4 PCs, 2 clouds, 18 links.')
