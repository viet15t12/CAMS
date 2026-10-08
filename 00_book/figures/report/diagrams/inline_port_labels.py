"""Attach Lab 1/2 port badges to wires in matching SVG and draw.io exports.

Run this after changing either source diagram. Lab 2's generator calls it too.
The transformation is idempotent and preserves device/link identities.
"""
from pathlib import Path
import math
import xml.etree.ElementTree as ET

BASE = Path(__file__).resolve().parent
NS = 'http://www.w3.org/2000/svg'
ET.register_namespace('', NS)
PLANS = {
    'dhcp-snooping-lab': {
        'data-r1': ('Gi0/1', 'Gi0/1', 60, 60),
        'data-r2': ('Gi0/2', 'Gi0/2', 60, 60),
        'data-fake': ('Gi0/3', 'Gi0/1', 40, 35),
        'mgmt-r1': (None, 'Gi0/0', 0, 35),
        'mgmt-sw': (None, 'Gi0/0', 0, 35),
        'mgmt-r2': (None, 'Gi0/0', 0, 35),
        'mgmt-fake': (None, 'Gi0/0', 0, 70),
    },
    'ospf-lab2-five-routers': {
        'data-r1-sw1': ('Gi0/1', 'Gi0/1', 50, 40),
        'data-r2-sw1': ('Gi0/2', 'Gi0/1', 85, 40),
        'data-r3-sw1': ('Gi0/3', 'Gi0/1', 40, 40),
        'data-r3-r4': ('Gi0/2', 'Gi0/1', 40, 40),
        'data-r4-r5': ('Gi0/2', 'Gi0/2', 40, 40),
        'data-r5-sw2': ('Gi0/1', 'Gi0/1', 45, 45),
        'data-r1-vpc8': ('Gi0/2', 'eth0', 45, 40),
        'data-r2-vpc9': ('Gi0/2', 'eth0', 45, 40),
        'data-sw2-vpc10': ('Gi0/2', 'eth0', 45, 40),
        'data-sw2-vpc11': ('Gi0/3', 'eth0', 80, 40),
        'mgmt-r1': (None, 'Gi0/0', 0, 70),
        'mgmt-sw1': (None, 'Gi0/0', 0, 75),
        'mgmt-r3': (None, 'Gi0/0', 0, 45),
        'mgmt-r2': (None, 'Gi0/0', 0, 45),
        'mgmt-r4': (None, 'Gi0/0', 0, 45),
        'mgmt-r5': (None, 'Gi0/0', 0, 45),
        'mgmt-sw2': (None, 'Gi0/0', 0, 100),
    },
}


def wire_point(points, distance):
    remaining = distance
    for a, b in zip(points, points[1:]):
        dx, dy = b[0]-a[0], b[1]-a[1]
        length = math.hypot(dx, dy)
        if remaining <= length:
            angle = math.degrees(math.atan2(dy, dx))
            if angle > 90: angle -= 180
            if angle < -90: angle += 180
            if abs(dx) < .01 or abs(dy) < .01: angle = 0
            return a[0]+remaining/length*dx, a[1]+remaining/length*dy, angle
        remaining -= length
    raise ValueError('Port outside wire')


def apply_labels(folder):
    folder = Path(folder)
    plan = PLANS[folder.name]
    svgtree = ET.parse(folder/'topology-redrawn.svg')
    svg = svgtree.getroot()
    mxtree = ET.parse(folder/'topology-redrawn.drawio')
    root = mxtree.find('.//root')
    cells = {c.get('id'): c for c in root}
    edges = {k: c for k, c in cells.items() if c.get('edge') == '1' and c.get('source')}
    assert set(plan) == set(edges)
    for child in list(svg):
        if child.get('id', '').startswith(('p-', 'port-')) or child.get('id', '').endswith('-port'):
            svg.remove(child)
    for child in list(root):
        if child.get('id', '').startswith(('p-', 'port-')) or child.get('id', '').endswith('-port'):
            root.remove(child)
    polylines = {c.get('id'): c for c in svg if c.tag == f'{{{NS}}}polyline'}
    count = 0
    for key, (source_port, target_port, source_distance, target_distance) in plan.items():
        wire = polylines[key]
        points = [tuple(map(float, p.split(','))) for p in wire.get('points').split()]
        total = sum(math.dist(a, b) for a, b in zip(points, points[1:]))
        specs = [('target', target_port, total-target_distance)]
        if source_port:
            specs.insert(0, ('source', source_port, source_distance))
        for endpoint, text, distance in specs:
            x, y, angle = wire_point(points, distance)
            w, h = (58 if text == 'eth0' else 76), 28
            color = wire.get('stroke')
            identifier = f'port-{key}-{endpoint}'
            badge = ET.SubElement(svg, f'{{{NS}}}g', id=identifier,
                                  transform=f'translate({x} {y}) rotate({angle})')
            ET.SubElement(badge, f'{{{NS}}}rect', x=str(-w/2), y=str(-h/2), width=str(w),
                          height=str(h), rx='5', fill='white', stroke='#c8d2dc',
                          attrib={'stroke-width': '1'})
            t = ET.SubElement(badge, f'{{{NS}}}text', x='0', y='7', fill=color,
                              attrib={'text-anchor': 'middle', 'font-family': 'Arial, Liberation Sans, sans-serif',
                                      'font-size': '20'})
            t.text = text
            style = ('rounded=1;arcSize=25;html=0;align=center;verticalAlign=middle;'
                     'resizable=0;points=[];fillColor=#ffffff;strokeColor=#c8d2dc;'
                     f'strokeWidth=1;fontFamily=Arial;fontSize=20;fontColor={color};rotation={angle};')
            c = ET.SubElement(root, 'mxCell', id=identifier, value=text, style=style,
                              vertex='1', connectable='0', parent=key)
            g = ET.SubElement(c, 'mxGeometry', x=str(2*distance/total-1), y='0', width=str(w),
                              height=str(h), relative='1', attrib={'as': 'geometry'})
            ET.SubElement(g, 'mxPoint', x=str(-w/2), y=str(-h/2), attrib={'as': 'offset'})
            count += 1
    assert count == (10 if folder.name == 'dhcp-snooping-lab' else 27)
    assert len({c.get('id') for c in root}) == len(root)
    ET.indent(mxtree, space='  ')
    mxtree.write(folder/'topology-redrawn.drawio', encoding='utf-8', xml_declaration=True)
    svgtree.write(folder/'topology-redrawn.svg', encoding='utf-8', xml_declaration=True)
    print(f'{folder.name}: {len(edges)} connections, {count} attached port labels')


if __name__ == '__main__':
    for name in PLANS:
        apply_labels(BASE/name)
