#!/usr/bin/env python3
"""Cree la maquette dans GNS3 via l'API REST (aucun clic, aucune dependance externe).

Exemples :
  ./create_lab.py                          # serveur local http://127.0.0.1:3080
  ./create_lab.py --server http://192.168.56.101:3080 --compute vm
  ./create_lab.py --recreate               # supprime et recree le projet
  ./create_lab.py --destroy                # supprime le projet
  ./create_lab.py --dry-run                # affiche ce qui serait fait
"""
import argparse, base64, json, os, sys, urllib.error, urllib.parse, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))


class Api:
    def __init__(self, server, user, password, dry=False):
        self.server = server.rstrip("/")
        self.user, self.password, self.dry = user, password, dry
        self.token = None
        self.prefix = None

    def raw(self, method, path, body=None, form=None, auth=True):
        url = self.server + path
        data, headers = None, {}
        if form is not None:
            data = urllib.parse.urlencode(form).encode()
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        elif body is not None:
            data = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"
        if auth and self.token:
            headers["Authorization"] = "Bearer " + self.token
        elif auth and self.prefix == "/v2":
            credentials = f"{self.user}:{self.password}".encode()
            headers["Authorization"] = "Basic " + base64.b64encode(credentials).decode()
        req = urllib.request.Request(url, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                txt = r.read().decode() or "null"
                return json.loads(txt)
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")[:400]
            raise SystemExit(f"[ERREUR] {method} {path} -> HTTP {e.code} : {detail}")
        except urllib.error.URLError as e:
            raise SystemExit(f"[ERREUR] serveur GNS3 injoignable ({self.server}) : {e.reason}")

    def detect(self):
        for pfx in ("/v3", "/v2"):
            self.prefix = pfx
            try:
                v = self.raw("GET", pfx + "/version")
                print(f"Serveur GNS3 {v.get('version', '?')} (API {pfx})")
                break
            except SystemExit as e:
                self.prefix = None
                if pfx == "/v2" and "HTTP 401" in str(e):
                    raise SystemExit(
                        "[ERREUR] authentification GNS3 refusee. "
                        "Indique les identifiants du serveur avec --user et --password "
                        "ou GNS3_USER et GNS3_PASSWORD."
                    )
                continue
        if not self.prefix:
            raise SystemExit("[ERREUR] impossible de joindre l'API GNS3 (ni /v3 ni /v2).")
        if self.prefix == "/v3":
            tok = self.raw("POST", "/v3/access/users/login",
                           form={"username": self.user, "password": self.password}, auth=False)
            self.token = tok["access_token"]

    def call(self, method, path, body=None):
        if self.dry:
            print(f"  [dry-run] {method} {self.prefix}{path} {json.dumps(body)[:110] if body else ''}")
            return {"project_id": "DRY", "node_id": "DRY", "compute_id": "local", "link_id": "DRY"}
        return self.raw(method, self.prefix + path, body=body)


def env_string(d):
    return "\n".join(f"{k}={v}" for k, v in d.items())


def build_node(name, spec, compute):
    if spec.get("type") == "switch":
        n = spec["ports"]
        return {"name": name, "node_type": "ethernet_switch", "compute_id": compute,
                "x": spec["x"], "y": spec["y"],
                "properties": {"ports_mapping": [
                    {"name": f"Ethernet{i}", "port_number": i, "type": "access", "vlan": 1} for i in range(n)]}}
    props = {"image": spec["image"], "adapters": spec["adapters"],
             "environment": env_string(spec.get("env", {})), "start_command": "",
             "console_type": spec.get("console", "telnet")}
    if spec.get("console") == "http":
        props["console_http_port"] = spec["http_port"]
        props["console_http_path"] = "/"
    return {"name": name, "node_type": "docker", "compute_id": compute,
            "x": spec["x"], "y": spec["y"], "properties": props}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--server", default=os.environ.get("GNS3_SERVER", "http://127.0.0.1:3080"))
    ap.add_argument("--user", default=os.environ.get("GNS3_USER", "admin"))
    ap.add_argument("--password", default=os.environ.get("GNS3_PASSWORD", "admin"))
    ap.add_argument("--compute", default=None, help="'vm' (GNS3 VM) ou 'local' ; auto par defaut")
    ap.add_argument("--topology", default=os.path.join(HERE, "topology.json"))
    ap.add_argument("--recreate", action="store_true", help="supprime le projet existant avant de le recreer")
    ap.add_argument("--destroy", action="store_true", help="supprime le projet et quitte")
    ap.add_argument("--no-start", action="store_true", help="ne demarre pas les noeuds")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    topo = json.load(open(a.topology))
    name = topo["project"]
    api = Api(a.server, a.user, a.password, dry=a.dry_run)
    if a.dry_run:
        api.prefix = "/v3"
    else:
        api.detect()

    projects = [] if a.dry_run else api.call("GET", "/projects")
    existing = [p for p in projects if p["name"] == name]
    if existing and (a.recreate or a.destroy):
        for p in existing:
            print(f"Suppression du projet '{name}' ({p['project_id']})")
            api.call("DELETE", f"/projects/{p['project_id']}")
        existing = []
    if a.destroy:
        return
    if existing:
        raise SystemExit(f"[ERREUR] le projet '{name}' existe deja : relance avec --recreate ou --destroy.")

    computes = [] if a.dry_run else api.call("GET", "/computes")
    ids = [c["compute_id"] for c in computes]
    compute = a.compute or ("vm" if "vm" in ids else "local")
    if not a.dry_run and compute not in ids:
        raise SystemExit(f"[ERREUR] compute '{compute}' introuvable (disponibles : {ids}).")
    print(f"Compute utilise : {compute}")

    pid = api.call("POST", "/projects", {"name": name})["project_id"]
    print(f"Projet '{name}' cree ({pid})")
    if not a.dry_run:
        try:
            api.call("POST", f"/projects/{pid}/open")
        except SystemExit:
            pass  # deja ouvert

    node_ids, kinds, next_port = {}, {}, {}
    for nname, spec in topo["nodes"].items():
        node_ids[nname] = api.call("POST", f"/projects/{pid}/nodes", build_node(nname, spec, compute))["node_id"]
        kinds[nname] = spec.get("type", "docker")
        next_port[nname] = 0
        print(f"  noeud {nname:<14} {spec.get('image', 'switch')}")

    def endpoint(text):
        if ":" in text:
            nm, itf = text.split(":")
            return {"node_id": node_ids[nm], "adapter_number": int(itf.replace("eth", "")), "port_number": 0}
        port = next_port[text]
        next_port[text] += 1
        return {"node_id": node_ids[text], "adapter_number": 0, "port_number": port}

    for a_end, b_end in topo["links"]:
        api.call("POST", f"/projects/{pid}/links", {"nodes": [endpoint(a_end), endpoint(b_end)]})
    print(f"  {len(topo['links'])} liens crees")

    if not a.no_start:
        api.call("POST", f"/projects/{pid}/nodes/start")
        print("Noeuds demarres.")
    print("\nEtape suivante : ouvrir la console de 'ansible-ctl' puis  cd /ansible && ansible-playbook site.yml")


if __name__ == "__main__":
    main()
