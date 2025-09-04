# seed_pb_from_schema.py
# PocketBase test data seeder:
# - Superuser-only koleksiyalar SKIP qilinadi
# - Required relation'lar CREATE vaqtida to'ldiriladi; pool bo'sh bo'lsa kolleksiya skip
# - Sxemadan select values o'qiladi (masalan orders.discount_type)
# Talablar: pip install requests faker python-dateutil

import os, json, random, time
from collections import defaultdict, deque
from datetime import datetime, timedelta, date
from dateutil.relativedelta import relativedelta
import requests
from faker import Faker

# ---- MUHIT ----
PB_BASE   = os.getenv("PB_BASE", "http://127.0.0.1:8090")
PB_TOKEN  = os.getenv("PB_TOKEN", "")
SCHEMA    = os.getenv("PB_SCHEMA", "pb_schema.json")

session = requests.Session()
if PB_TOKEN:
    session.headers.update({"Authorization": f"Bearer {PB_TOKEN}"})

# ---- KONFIG ----
DEFAULT_COUNT = 30
COUNTS = {
    "users": 8,
    "regions": 8,
    "categories": 10,
    "suppliers": 6,
    "products": 80,
    "dealers": 40,
    "fx_rates": 420,          # ~14 oy
    "orders": 140,
    "order_items": 900,       # orderlarga 1..7 tadan
    "payments": 200,
    "return_entries": 30,
    "return_entry_items": 60,
    "stock_entries": 30,
    "stock_entry_items": 90,
    "stock_log": 30,
    "dealer_balance_adjustments": 20,
}

# Seed qilinmasin (rule/hook tufayli yoki service kolleksiyalar)
SKIP_SEED = {
    "activity_log",
    "payment_applications",
    "order_edit_requests",
    "dealer_balance_adjustments",
    "_superusers", "_authOrigins", "_externalAuths", "_mfas", "_otps",
}

# fallback select'lar (schema'da values bo'lmasa)
SELECT_FALLBACK = {
    "orders.status": ["created", "edit_requested", "editable", "packed", "shipped", "reserved"],
    # EHTIYOT: amount ko'p sxemalarda yo'q — fallback faqat none/percent
    "orders.discount_type": ["none", "percent"],
    "payments.currency": ["USD", "UZS"],
    "payments.method": ["cash", "card", "bank"],
    "products.type": ["pg", "po"],
    "users.role": ["admin", "accountant", "manager", "warehouseman", "owner"],
    "stock_log.reason": ["sale", "adjust", "return", "initial"],
}

fake = Faker()

# --------- UTIL ---------
def load_schema(path):
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, dict) and "collections" in data:
        return data["collections"]
    return data

def map_collections(colls):
    name_to = {c["name"]: c for c in colls}
    id_to_name = {}
    for c in colls:
        if "id" in c:
            id_to_name[c["id"]] = c["name"]
    return name_to, id_to_name

def build_field_list(coll):
    return coll.get("fields", coll.get("schema", []))

def topo_order(colls):
    name_to, id_to_name = map_collections(colls)
    deps = defaultdict(set)
    for c in colls:
        for f in build_field_list(c):
            if f.get("type") == "relation":
                opts = f.get("options", {}) or {}
                target = opts.get("collection") or opts.get("collectionId")
                if target:
                    tgt = id_to_name.get(target, target)
                    if tgt in name_to and tgt != c["name"]:
                        deps[c["name"]].add(tgt)
    indeg = {c["name"]: 0 for c in colls}
    for k, vs in deps.items():
        for v in vs:
            indeg[k] += 1
    q = deque([n for n, d in indeg.items() if d == 0])
    order = []
    while q:
        u = q.popleft()
        order.append(u)
        for k in list(deps.keys()):
            if u in deps[k]:
                deps[k].remove(u)
                indeg[k] -= 1
                if indeg[k] == 0:
                    q.append(k)
    remain = [n for n in indeg if n not in order]
    return order + remain

def get_select_values_from_schema(name_to: dict, coll_name: str, field_name: str):
    """Schema'dan select options.values ni o‘qib beradi."""
    coll = name_to.get(coll_name)
    if not coll:
        return []
    for f in build_field_list(coll):
        if f.get("name") == field_name and (f.get("type") or f.get("@type")) == "select":
            opts = f.get("options") or {}
            vals = opts.get("values") or []
            return list(vals)
    return []

def pb_post(coll, data):
    r = session.post(f"{PB_BASE}/api/collections/{coll}/records", json=data, timeout=60)
    if r.status_code != 200:
        raise RuntimeError(f"[POST {coll}] {r.status_code} {r.text}")
    return r.json()

def pb_patch(coll, rec_id, data):
    r = session.patch(f"{PB_BASE}/api/collections/{coll}/records/{rec_id}", json=data, timeout=60)
    if r.status_code != 200:
        print(f"[WARN PATCH {coll}/{rec_id}] {r.status_code} {r.text}")

def pb_list_ids(coll, limit=5000, fields="id"):
    try:
        r = session.get(f"{PB_BASE}/api/collections/{coll}/records?page=1&perPage={limit}&fields={fields}", timeout=60)
        if r.status_code != 200:
            return []
        items = r.json().get("items", [])
        return [it["id"] for it in items]
    except Exception:
        return []

def ensure_min_pool(coll_name, n=5):
    pool = pb_list_ids(coll_name)
    if len(pool) >= n:
        return pool
    # oddiy placeholderlarga urinish (rule/required bo’lsa tushmasligi mumkin)
    for _ in range(max(0, n - len(pool))):
        try:
            pb_post(coll_name, {})
        except Exception:
            pass
    return pb_list_ids(coll_name)

def pick_select(cname, fname, field_def):
    vals = field_def.get("values") or field_def.get("options", {}).get("values") or []
    if not vals:
        vals = SELECT_FALLBACK.get(f"{cname}.{fname}", [])
    return random.choice(vals) if vals else None

def rand_date_18m():
    start = datetime.now() - relativedelta(months=18)
    dt = start + timedelta(days=random.randint(0, 540))
    return dt.date().isoformat()

def rand_dt_18m():
    start = datetime.now() - relativedelta(months=18)
    dt = start + timedelta(days=random.randint(0, 540), seconds=random.randint(0, 86400))
    return dt.isoformat(timespec="seconds")

def rand_fx_value():
    return round(random.uniform(12500, 14000), 2)

def ensure_users_minimal(name_to):
    if "users" not in name_to:
        return []
    want_roles = SELECT_FALLBACK["users.role"]
    created = []
    for role in want_roles:
        email = f"{role}@example.com"
        body = {
            "email": email,
            "password": "Test1234!",
            "passwordConfirm": "Test1234!",
            "name": role.capitalize() + " User",
            "role": role,
            "emailVisibility": True,
            "verified": True,
            "is_active": True,
        }
        try:
            rec = pb_post("users", body)
            created.append(rec["id"])
        except Exception:
            pass
    pool = pb_list_ids("users")
    return pool or created

def gen_by_type(cname, fdef):
    fname = fdef["name"]
    ftype = fdef.get("type") or fdef.get("@type")
    req = fdef.get("required", False)

    def maybe(v):
        return v if req or random.random() > 0.08 else None

    if ftype in ("text", "editor", "json"):
        ln = fname.lower()
        if "email" in ln:
            return maybe(fake.unique.email())
        if "name" in ln or "title" in ln:
            return maybe(fake.sentence(nb_words=2).replace(".", ""))
        if "phone" in ln or "tel" in ln:
            return maybe(fake.msisdn())
        if "human_id" in ln:
            return maybe(f"ORD-{random.randint(100000,999999)}")
        if "barcode" in ln:
            return maybe(f"MD-{random.randint(10**9, 10**10-1)}")
        if "note" in ln or "reason" in ln:
            return maybe(fake.sentence(nb_words=6))
        return maybe(fake.word())
    if ftype == "number":
        return round(random.uniform(1, 9999), 2)
    if ftype == "bool":
        return bool(random.getrandbits(1))
    if ftype in ("date",):
        return rand_date_18m()
    if ftype in ("datetime", "autodate"):
        return rand_dt_18m()
    if ftype == "select":
        return pick_select(cname, fname, fdef)
    if ftype in ("file", "password", "relation", "email"):
        if ftype == "email":
            return maybe(fake.unique.email())
        return None
    return None

# --------- BOSHLAYMIZ ---------
collections = load_schema(SCHEMA)
name_to, id_to = map_collections(collections)
order = topo_order(collections)
print("Topologik tartib:", " -> ".join(order))

generated = defaultdict(list)
cached_ids = defaultdict(list)

# orders.discount_type ni schema'dan o'qib olaylik (fallback: none/percent)
ORDER_DISCOUNT_TYPES = get_select_values_from_schema(name_to, "orders", "discount_type")
if not ORDER_DISCOUNT_TYPES:
    ORDER_DISCOUNT_TYPES = list(SELECT_FALLBACK["orders.discount_type"])
# Amount schema ruxsat bermasa, ro‘yxatdan olib tashlaymiz
ORDER_DISCOUNT_TYPES = [v for v in ORDER_DISCOUNT_TYPES if v in ("none", "percent", "amount")]

# 0) users minimal
if "users" in name_to:
    ensure_users_minimal(name_to)
    cached_ids["users"] = pb_list_ids("users")

# 1) FX rates (oldindan) — 14 oy, kunma-kun (re-run’da unique xatolarini yutamiz)
if "fx_rates" in name_to and "fx_rates" not in SKIP_SEED:
    print("Seeding fx_rates ...")
    start = date.today() - relativedelta(months=14)
    days = (date.today() - start).days
    for i in range(days):
        d = start + timedelta(days=i)
        payload = {"date": d.isoformat(), "usd_to_uzs": rand_fx_value()}
        try:
            rec = pb_post("fx_rates", payload)
            generated["fx_rates"].append(rec["id"])
        except Exception:
            # validation_not_unique bo'lsa ham davom etamiz
            pass
        if (i + 1) % 60 == 0:
            time.sleep(0.02)
    cached_ids["fx_rates"] = generated["fx_rates"] or pb_list_ids("fx_rates")

# 2) Birinchi pass: required relation'lar CREATE vaqtida, optional'lar keyin PATCH
optional_rel_tracker = {cn: [] for cn in order}

for cname in order:
    if cname in SKIP_SEED:
        print(f"Skipping {cname} (blacklisted)")
        continue
    if cname == "users":
        continue

    coll = name_to[cname]
    fields = build_field_list(coll)
    count = COUNTS.get(cname, DEFAULT_COUNT)

    print(f"Seeding {cname} ({count}) ...")
    forbidden = False  # 403 superuser-only bo'lsa, kolleksiyani tashlab ketamiz

    # CREATE vaqtida kerak bo‘ladigan REQUIRED relation’lar uchun target pool'lar bo‘sh bo‘lmasligi kerak
    required_targets = []
    for rf in fields:
        if rf.get("type") == "relation" and rf.get("required"):
            opts = rf.get("options", {}) or {}
            target = opts.get("collection") or opts.get("collectionId")
            # target nomini topamiz
            tname = None
            for _c in collections:
                if _c.get("id") == target or _c.get("name") == target:
                    tname = _c["name"]
                    break
            if tname:
                required_targets.append(tname)

    # Agar required relation target kolleksiyalarida yozuv bo'lmasa — skip
    pool_missing = False
    for tname in required_targets:
        pool = cached_ids.get(tname) or pb_list_ids(tname)
        if not pool:
            print(f"[SKIP {cname}] required pool '{tname}' is empty — skipping this collection seeding.")
            pool_missing = True
            break
    if pool_missing:
        continue

    for i in range(count):
        if forbidden:
            break

        record = {}
        opt_rels_for_this_record = []

        # 2.1: non-relation fieldlar
        for f in fields:
            if f.get("primaryKey"):
                continue
            if f.get("type") == "relation":
                continue
            record[f["name"]] = gen_by_type(cname, f)

        # maxsus defaultlar (unique friendly)
        if cname == "categories":
            record["name"] = (record.get("name") or fake.word().title()) + f" {random.randint(1000,9999)}"

        if cname == "dealers":
            record["name"] = (record.get("name") or f"{fake.city()} Diller") + f" {random.randint(1000,9999)}"
            record.setdefault("tin", str(random.randint(100000000, 999999999)))

        if cname == "products":
            record["name"] = (record.get("name") or f"{fake.color_name()} Door") + f" {random.randint(1000,9999)}"
            record["is_active"] = True
            price = round(random.uniform(50, 500), 2)
            cost  = round(price * random.uniform(0.5, 0.9), 2)
            record["price_usd"] = price
            record.setdefault("cost_price_usd", cost)

        # 2.2: REQUIRED relation'lar – CREATE paytida
        for rf in fields:
            if rf.get("type") != "relation":
                continue
            rname = rf["name"]
            opts  = rf.get("options", {}) or {}
            target = opts.get("collection") or opts.get("collectionId")

            tname = None
            for _c in collections:
                if _c.get("id") == target or _c.get("name") == target:
                    tname = _c["name"]
                    break
            if not tname:
                continue

            if rf.get("required"):
                pool = cached_ids.get(tname) or pb_list_ids(tname)
                if not pool:
                    pool = ensure_min_pool(tname, n=5)
                maxSel = opts.get("maxSelect", 1)
                minSel = opts.get("minSelect", 0)
                if (maxSel or 1) > 1:
                    k = max(1, minSel)
                    k = min(k, len(pool)) if len(pool) > 0 else 0
                    record[rname] = random.sample(pool, k) if k > 0 else []
                else:
                    record[rname] = random.choice(pool) if pool else None
            else:
                opt_rels_for_this_record.append(rf)

        # 2.3: CREATE (unique errors va select fallback'ni yutish)
        created = None
        try:
            created = pb_post(cname, record)
        except RuntimeError as e:
            msg = str(e)
            # superuser-only kolleksiya bo'lsa — skip
            if "403" in msg and ("Only superusers" in msg or "forbidden" in msg.lower()):
                print(f"[SKIP {cname}] superuser-only collection. Skipping the rest.")
                forbidden = True
                break

            # required select/text fallback
            for f in fields:
                if f.get("type") == "select" and f.get("required") and not record.get(f["name"]):
                    record[f["name"]] = pick_select(cname, f["name"], f) or "none"
            # unique name xatolariga oddiy suffix qo'yib qayta urinish
            if "validation_not_unique" in msg and "name" in msg:
                record["name"] = (record.get("name") or fake.word().title()) + f" {random.randint(10000,99999)}"
            created = pb_post(cname, record)

        rid = created["id"]
        generated[cname].append(rid)
        optional_rel_tracker[cname].append((rid, opt_rels_for_this_record))

    cached_ids[cname] = generated[cname] or pb_list_ids(cname)

# 3) OPTIONAL relation'larni PATCH
for cname in order:
    if cname in SKIP_SEED or cname == "users":
        continue
    pairs = optional_rel_tracker.get(cname, [])
    if not pairs:
        continue

    for rid, opt_rels in pairs:
        patch = {}
        for rf in opt_rels:
            rname = rf["name"]
            opts  = rf.get("options", {}) or {}
            target = opts.get("collection") or opts.get("collectionId")
            tname = None
            for _c in collections:
                if _c.get("id") == target or _c.get("name") == target:
                    tname = _c["name"]
                    break
            if not tname:
                continue
            pool = cached_ids.get(tname) or pb_list_ids(tname)
            if not pool:
                continue
            maxSel = opts.get("maxSelect", 1)
            minSel = opts.get("minSelect", 0)
            if (maxSel or 1) > 1:
                k = random.randint(max(0, minSel), min(maxSel, len(pool)))
                if k > 0:
                    patch[rname] = random.sample(pool, k)
            else:
                patch[rname] = random.choice(pool)
        if patch:
            pb_patch(cname, rid, patch)

# 4) Domain tweaks: orders (+ optional order_items), payments, returns, stock, stock_log
print("Tweaking orders & (optional) order_items ...")
oids = cached_ids.get("orders", []) or pb_list_ids("orders")
cached_ids["orders"] = oids
dids = cached_ids.get("dealers", []) or pb_list_ids("dealers")
uids = cached_ids.get("users", [])   or pb_list_ids("users")
rids = cached_ids.get("regions", []) or pb_list_ids("regions")
cached_ids["dealers"], cached_ids["users"], cached_ids["regions"] = dids, uids, rids

for oid in oids:
    patch = {"status": random.choice(SELECT_FALLBACK["orders.status"])}

    # discount_type — faqat schema ruxsat bergan qiymatlardan
    dct = random.choice(ORDER_DISCOUNT_TYPES) if ORDER_DISCOUNT_TYPES else "none"
    patch["discount_type"] = dct
    if dct == "percent":
        patch["discount_value"] = round(random.uniform(0, 10), 2)
    elif dct == "amount":
        if "amount" in ORDER_DISCOUNT_TYPES:
            patch["discount_value"] = round(random.uniform(0, 50), 2)
        else:
            patch["discount_type"] = "none"
            patch["discount_value"] = 0
    else:
        patch["discount_value"] = 0

    if uids: patch["manager"] = random.choice(uids)
    if dids: patch["dealer"]  = random.choice(dids)
    if rids: patch["region"]  = random.choice(rids)
    pb_patch("orders", oid, patch)

# order_items — ixtiyoriy (agar mavjud bo'lmasa, bir oz yaratamiz)
have_items = pb_list_ids("order_items")
if "order_items" in name_to and "order_items" not in SKIP_SEED:
    target_items = COUNTS.get("order_items", 900)
    if len(have_items) < target_items * 0.6 and oids:
        pids = cached_ids.get("products", []) or pb_list_ids("products")
        for oid in oids:
            n = random.randint(1, 7)
            for _ in range(n):
                body = {
                    "order": oid,
                    "product": random.choice(pids) if pids else None,
                    "qty": round(random.uniform(1, 20), 2),
                    "unit_price_usd": round(random.uniform(50, 500), 2),
                }
                try:
                    pb_post("order_items", body)
                except Exception:
                    pass
            time.sleep(0.004)

# payments (dealer required)
if "payments" in name_to and "payments" not in SKIP_SEED:
    print("Tweaking payments ...")
    dids = cached_ids.get("dealers", []) or pb_list_ids("dealers")
    pm_target = COUNTS.get("payments", 200)
    pm_existing = pb_list_ids("payments")
    to_create = max(0, pm_target - len(pm_existing))
    for _ in range(to_create):
        curr = random.choice(SELECT_FALLBACK["payments.currency"])
        body = {
            "dealer": random.choice(dids) if dids else None,
            "currency": curr,
            "method": random.choice(SELECT_FALLBACK["payments.method"]),
            "amount": round(random.uniform(50, 3000), 2),
            "date": rand_date_18m(),
        }
        if curr == "UZS":
            body["fx_rate"] = rand_fx_value()
        try:
            pb_post("payments", body)
        except Exception:
            pass

# return_entries + return_entry_items
if "return_entries" in name_to and "return_entries" not in SKIP_SEED:
    re_existing = pb_list_ids("return_entries")
    dids = cached_ids.get("dealers", []) or pb_list_ids("dealers")
    to_create = max(0, COUNTS.get("return_entries", 30) - len(re_existing))
    for _ in range(to_create):
        body = {
            "dealer": random.choice(dids) if dids else None,
            "date": rand_date_18m(),
            "note": fake.sentence(nb_words=4)
        }
        try:
            pb_post("return_entries", body)
        except Exception:
            pass

if ("return_entry_items" in name_to and "return_entry_items" not in SKIP_SEED
        and "return_entries" in name_to and "return_entries" not in SKIP_SEED):
    eids = pb_list_ids("return_entries")
    pids = cached_ids.get("products", []) or pb_list_ids("products")
    rei_existing = pb_list_ids("return_entry_items")
    need = max(0, COUNTS.get("return_entry_items", 60) - len(rei_existing))
    idx = 0
    while need > 0 and eids:
        eid = eids[idx % len(eids)]
        n = random.randint(1, 2)
        for _ in range(n):
            body = {
                "entry": eid,
                "product": random.choice(pids) if pids else None,
                "qty": round(random.uniform(1, 5), 2),
                "price_usd": round(random.uniform(10, 180), 2),
            }
            try:
                pb_post("return_entry_items", body)
                need -= 1
                if need <= 0:
                    break
            except Exception:
                pass
        idx += 1

# stock_entries + stock_entry_items
if "stock_entries" in name_to and "stock_entries" not in SKIP_SEED:
    sids = cached_ids.get("suppliers", []) or pb_list_ids("suppliers")
    se_existing = pb_list_ids("stock_entries")
    to_create = max(0, COUNTS.get("stock_entries", 30) - len(se_existing))
    for _ in range(to_create):
        body = {
            "supplier": random.choice(sids) if sids else None,
            "date": rand_date_18m(),
            "note": fake.sentence(nb_words=4),
        }
        try:
            pb_post("stock_entries", body)
        except Exception:
            pass

if ("stock_entry_items" in name_to and "stock_entry_items" not in SKIP_SEED
        and "stock_entries" in name_to and "stock_entries" not in SKIP_SEED):
    eids = pb_list_ids("stock_entries")
    pids = cached_ids.get("products", []) or pb_list_ids("products")
    sei_existing = pb_list_ids("stock_entry_items")
    need = max(0, COUNTS.get("stock_entry_items", 90) - len(sei_existing))
    idx = 0
    while need > 0 and eids:
        eid = eids[idx % len(eids)]
        n = random.randint(1, 4)
        for _ in range(n):
            body = {
                "entry": eid,
                "product": random.choice(pids) if pids else None,
                "qty": round(random.uniform(1, 20), 2),
                "unit_cost_usd": round(random.uniform(10, 150), 2),
            }
            try:
                pb_post("stock_entry_items", body)
                need -= 1
                if need <= 0:
                    break
            except Exception:
                pass
        idx += 1

# stock_log (product required)
if "stock_log" in name_to and "stock_log" not in SKIP_SEED:
    pids = cached_ids.get("products", []) or pb_list_ids("products")
    sl_existing = pb_list_ids("stock_log")
    need = max(0, COUNTS.get("stock_log", 30) - len(sl_existing))
    for _ in range(need):
        body = {
            "product": random.choice(pids) if pids else None,
            "delta": random.randint(-10, 10),
            "reason": random.choice(SELECT_FALLBACK["stock_log.reason"]),
            "date": rand_date_18m(),
        }
        try:
            pb_post("stock_log", body)
        except Exception:
            pass

print("\n✅ Tayyor. Qisqa hisob:")
# qayta hisob (ba’zilar skip bo’lgani uchun)
keys = set(k for k in (list(COUNTS.keys()) + list(name_to.keys())) if k not in SKIP_SEED)
for k in sorted(keys):
    cnt = len(pb_list_ids(k)) if k != "users" else len(pb_list_ids("users"))
    print(f"  {k}: {cnt} ta yozuv")

if not PB_TOKEN:
    print("⚠️  PB_TOKEN topilmadi. Admin yoki service token (PB_TOKEN) ber.")
