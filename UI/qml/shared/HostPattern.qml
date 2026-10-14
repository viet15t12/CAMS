pragma Singleton

import QtQuick

// Bulk host selection by pattern, like "passive-interface default" followed by
// "no passive-interface X": tokens add hosts, "!token" removes them, and an
// expression made only of exclusions starts from every host.
//   all | *                 every host
//   192.168.1.10            one IP
//   192.168.1.0/24          a subnet
//   192.168.1.10-50         last-octet range (or full a.b.c.d-e.f.g.h)
//   R1-R10  SW1-10          device-name range: same prefix, number in range
//   router switch l2 l3     device type (needs item.role)
//   SW*  core-?             device name or host wildcard, case-insensitive
QtObject {
    readonly property var roleAliases: ({
        "router": ["rou", "router"], "routers": ["rou", "router"],
        "switch": ["sw2", "sw3", "switch", "switch_l2", "switch_l3"],
        "switches": ["sw2", "sw3", "switch", "switch_l2", "switch_l3"],
        "l2": ["sw2", "switch_l2"], "sw2": ["sw2", "switch_l2"],
        "l3": ["sw3", "switch_l3"], "sw3": ["sw3", "switch_l3"]
    })

    function ipToInt(text) {
        const m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(String(text || "").trim())
        if (!m)
            return -1
        let value = 0
        for (let i = 1; i <= 4; i++) {
            const octet = Number(m[i])
            if (octet > 255)
                return -1
            value = value * 256 + octet
        }
        return value
    }

    function ipRange(first, last) {
        return first >= 0 && last >= first
                ? item => { const ip = ipToInt(item.host); return ip >= first && ip <= last }
                : null
    }

    // Returns a predicate over {host, name}, or null when the token is invalid.
    function tokenMatcher(token) {
        const value = String(token || "").trim()
        if (value === "")
            return null
        if (value.toLowerCase() === "all" || value === "*")
            return () => true
        let m = /^([\d.]+)\/(\d{1,2})$/.exec(value)
        if (m) {
            const base = ipToInt(m[1])
            const prefix = Number(m[2])
            if (base < 0 || prefix > 32)
                return null
            const size = Math.pow(2, 32 - prefix)
            const network = Math.floor(base / size) * size
            return ipRange(network, network + size - 1)
        }
        m = /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.)(\d{1,3})-(\d{1,3})$/.exec(value)
        if (m)
            return ipRange(ipToInt(m[1] + m[2]), ipToInt(m[1] + m[3]))
        m = /^([\d.]+)-([\d.]+)$/.exec(value)
        if (m)
            return ipRange(ipToInt(m[1]), ipToInt(m[2]))
        if (ipToInt(value) >= 0)
            return item => String(item.host) === value
        const roles = roleAliases[value.toLowerCase()]
        if (roles)
            return item => roles.indexOf(String(item.role || "").toLowerCase()) >= 0
        m = /^([a-z][a-z_-]*)(\d+)-(?:\1)?(\d+)$/i.exec(value)
        if (m) {
            const first = Number(m[2])
            const last = Number(m[3])
            if (last < first)
                return null
            const named = new RegExp("^" + m[1] + "(\\d+)$", "i")
            return item => {
                const hit = named.exec(String(item.name || ""))
                return hit !== null && Number(hit[1]) >= first && Number(hit[1]) <= last
            }
        }
        if (/^[\d.\/-]+$/.test(value))
            return null
        const escaped = value.replace(/[.+^${}()|[\]\\]/g, "\\$&")
        const wildcard = new RegExp("^" + escaped.replace(/\*/g, ".*").replace(/\?/g, ".") + "$", "i")
        return item => wildcard.test(String(item.host || "")) || wildcard.test(String(item.name || ""))
    }

    // items: [{host, name}] -> {hosts: [host...], error: ""}
    function select(items, expression) {
        const rows = items || []
        const tokens = String(expression || "").split(/[\s,;]+/).filter(token => token !== "")
        if (tokens.length === 0)
            return {hosts: [], error: "Type a pattern, for example: all !10.0.0.0/26 !R3"}
        const include = []
        const exclude = []
        for (let i = 0; i < tokens.length; i++) {
            const negative = tokens[i].charAt(0) === "!"
            const body = negative ? tokens[i].slice(1) : tokens[i]
            const matcher = tokenMatcher(body)
            if (matcher === null)
                return {hosts: [], error: "Unrecognized pattern: " + tokens[i]}
            ;(negative ? exclude : include).push(matcher)
        }
        const hosts = []
        for (let r = 0; r < rows.length; r++) {
            const row = rows[r]
            const included = include.length === 0 || include.some(match => match(row))
            if (included && !exclude.some(match => match(row)))
                hosts.push(String(row.host))
        }
        return {hosts: hosts, error: ""}
    }
}
