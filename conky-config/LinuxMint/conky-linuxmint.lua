-- Script Lua pour Conky - Version Linux Mint
-- Compatible avec tous les environnements Lua de Conky
-- Détecte le nombre de cœurs CPU et les interfaces réseau actives

-- Cache pour éviter de relire les fichiers trop souvent
local cpu_count_cache = nil
local network_interface_cache = nil
local last_network_check = 0

-- Fonction pour compter le nombre de CPUs (via /proc/cpuinfo)
function get_cpu_count()
    if cpu_count_cache then
        return cpu_count_cache
    end

    local count = 0
    local file = io.open("/proc/cpuinfo", "r")

    if file then
        for line in file:lines() do
            if line:match("^processor") then
                count = count + 1
            end
        end
        file:close()
    end

    -- Fallback vers nproc si /proc/cpuinfo inaccessible
    if count == 0 then
        local handle = io.popen("nproc 2>/dev/null")
        if handle then
            count = tonumber(handle:read("*l")) or 4
            handle:close()
        end
    end

    cpu_count_cache = count
    return count
end

-- Fonction pour obtenir l'interface réseau active
function get_active_interface()
    local current_time = os.time()

    -- Cache pendant 10 secondes
    if network_interface_cache and (current_time - last_network_check) < 10 then
        return network_interface_cache
    end

    -- Liste des interfaces à vérifier par ordre de priorité
    local interfaces = {}
    local file = io.open("/proc/net/route", "r")

    if file then
        local first_line = true
        for line in file:lines() do
            if not first_line then
                local iface = line:match("^(%S+)")
                if iface and iface ~= "lo" then
                    -- Vérifier si l'interface a du trafic
                    local tx_file = io.open("/sys/class/net/" .. iface .. "/statistics/tx_bytes", "r")
                    if tx_file then
                        local tx_bytes = tx_file:read("*n")
                        tx_file:close()
                        if tx_bytes and tx_bytes > 0 then
                            table.insert(interfaces, iface)
                        end
                    end
                end
            else
                first_line = false
            end
        end
        file:close()
    end

    -- Prendre la première interface active
    if #interfaces > 0 then
        network_interface_cache = interfaces[1]
    else
        network_interface_cache = "none"
    end

    last_network_check = current_time
    return network_interface_cache
end

-- Fonction pour afficher tous les cœurs CPU (compact: 2 par ligne)
function conky_show_cpus()
    local cpu_count = get_cpu_count()
    local result = ""
    local i = 1

    while i <= cpu_count and i <= 16 do
        local line = "${color2}│${color}"
        line = line .. " C" .. i .. ": ${cpu cpu" .. i .. "}%"
        if i + 1 <= cpu_count and i + 1 <= 16 then
            line = line .. "  C" .. (i + 1) .. ": ${cpu cpu" .. (i + 1) .. "}%"
        end
        result = result .. line .. "\n"
        i = i + 2
    end

    return result
end

-- Fonction pour afficher l'interface réseau active (compact)
function conky_show_network()
    local iface = get_active_interface()

    if iface == "none" or iface == "" then
        return "${color2}│${color} Aucune connexion réseau"
    end

    -- Déterminer le type d'interface
    local iface_type = "Ethernet"
    if iface:match("^wl") or iface:match("^wlan") then
        iface_type = "WiFi"
    end

    local result = string.format(
        "${color2}│ ${color4}%s (${addr %s})${color}\n" ..
        "${color2}│${color} ↓ ${downspeed %s}/s  ↑ ${upspeed %s}/s${alignr}${totaldown %s}\n" ..
        "${color1}│${color} ${downspeedgraph %s 18,298 4a8b30 87c540 -t}",
        iface_type, iface,
        iface, iface, iface,
        iface
    )

    return result
end

-- Fonction pour obtenir la distribution Linux Mint
function conky_get_distro()
    local handle = io.popen("cat /etc/linuxmint/info 2>/dev/null | grep '^DISTRIB_DESCRIPTION=' | cut -d'=' -f2 | tr -d '\"'")

    if not handle then
        handle = io.popen("lsb_release -d 2>/dev/null | cut -f2")
    end

    if not handle then
        return "Linux Mint"
    end

    local distro = handle:read("*l") or "Linux Mint"
    handle:close()

    return distro
end

-- Fonction pour obtenir le nombre de mises à jour disponibles (apt)
function conky_get_updates()
    local handle = io.popen("apt list --upgradable 2>/dev/null | grep -c upgradable")

    if not handle then
        return "N/A"
    end

    local updates = tonumber(handle:read("*l")) or 0
    handle:close()

    if updates > 0 then
        return updates .. " update(s) disponible(s)"
    else
        return "Système à jour"
    end
end
