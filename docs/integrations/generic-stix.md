# Entegrasyon: Diğer Ürünler (Generic TAXII 2.1)

> **Hedef:** TAXII 2.1 destekleyen herhangi bir SIEM/XDR/EDR/SOAR/TIP için
> SGB feed'ini bağlama rehberi. TAXII destekleyemeyen klasik araçlar
> (Suricata, Wazuh) için text slice alternatifi.

**Tüketilen servis:** `https://sgb-taxii.bilsec.tr/taxii2/` (anonim, TAXII 2.1)

## BG Rehberi karşılığı

| Madde | Madde adı | Bu entegrasyon nasıl karşılar? |
|-------|-----------|--------------------------------|
| **3.1.5.1** ⭐ | Zararlı Yazılımdan Korunma + Merkezi Yönetim | EDR/XDR'a SGB IoC besleme = "imza/IoC veri tabanını güncel tut" |
| **3.1.10.4** ⭐ | Siber Tehdit Bildirimlerinin Yönetilmesi | SGB feed'in operasyonel ürünlere taşınması |
| **3.1.6.4** | Kara Liste Kullanımı | Suricata/Wazuh text slice = kara liste |
| **3.1.8.7** | Kayıt Analizi Araçları (SIEM) | Elastic / Securonix / Exabeam — alternatif SIEM'ler |

## Servis bilgileri

```
Discovery: https://sgb-taxii.bilsec.tr/taxii2/
API root:  https://sgb-taxii.bilsec.tr/api/
Koleksiyonlar: sgb-phishing, sgb-botnet-cc, sgb-apt-cc, sgb-exploit-kit,
               sgb-malware-download, sgb-mining, sgb-mobile-cc, sgb-other
Auth: yok (anonim)
Polling: saatlik öneri (added_after ile incremental)
```

## Hedef sistem matrisi

| Sistem | Önerilen yöntem | Birincil BG madde |
|--------|------------------|-------------------|
| **Cortex XSOAR** | Built-in "TAXII 2 Feed" integration | 3.1.10.4 |
| **Trellix XDR (eski FireEye)** | TAXII 2.1 client (built-in) | 3.1.10.4 |
| **Microsoft Defender XDR** | Sentinel TI blade üzerinden (TAXII), Defender otomatik ingest | 3.1.5.1 |
| **CrowdStrike Falcon** | Falcon Foundry TAXII connector veya custom API push | 3.1.5.1 |
| **Elastic Security** | Threat Intel Filebeat module — TAXII input | 3.1.8.7 |
| **Securonix / Exabeam UEBA** | Built-in TAXII threat intel ingest | 3.1.8.7 |
| **Suricata / Snort** | Text slice (TAXII desteği yok) | 3.1.6.18 |
| **Wazuh** | Text slice + CDB list (TAXII desteği yok) | 3.1.6.4 |
| **OPNsense / pfSense** | Text slice (ana sayfada zaten kapsanır) | 3.1.6.4 |

## Pattern: Built-in TAXII 2.1 client

Modern SIEM/XDR ürünlerinin çoğu native TAXII 2.1 client içerir.
Genel kurulum şablonu (UI menü adları değişir):

1. Settings / Integrations → "TAXII 2 Feed" (veya "Threat Intelligence — TAXII")
2. **Discovery URL:** `https://sgb-taxii.bilsec.tr/taxii2/`
3. **API root:** `https://sgb-taxii.bilsec.tr/api/`
4. **Collection ID:** istenen koleksiyon (örn. `sgb-phishing`)
5. **Auth:** None
6. **Poll interval:** 60 dakika
7. Default reputation / verdict: Malicious

Her UC için ayrı feed/instance (8 koleksiyon → 8 feed).

### Cortex XSOAR

**Settings → Integrations → TAXII 2 Feed**

| Parameter | Value |
|-----------|-------|
| Discovery Service | `https://sgb-taxii.bilsec.tr/taxii2/` |
| Collection to Fetch | `sgb-phishing` (her UC için ayrı instance) |
| Fetch Indicators | ✓ |
| Indicator Reputation | Bad |
| Fetch interval | 1 hour |

Indicator types map (otomatik):

- `domain-name` → `Domain`
- `ipv4-addr` → `IP`
- `ipv6-addr` → `IPv6`
- `url` → `URL`

### Elastic Security (Filebeat threatintel module)

```yaml
# filebeat.yml
filebeat.modules:
  - module: threatintel
    misp:
      enabled: false
    taxii:
      enabled: true
      var.input: httpjson
      var.url: "https://sgb-taxii.bilsec.tr/api/collections/sgb-phishing/objects/"
      var.interval: 1h
```

Index pattern: `filebeat-*` → "Threat Intel" dashboard otomatik dolar.

## Pattern: Air-gapped / TAXII desteği olmayan ürünler

TAXII'ye çıkamayan ortamlar için iki seçenek:

### Seçenek A — Self-host TAXII servisi

İç ağda Docker/K8s ile aynı TAXII endpoint'i ayağa kaldırın; ürünler
internal host'a bağlanır, sadece host'un SGB API'sine outbound HTTPS
erişimi olur. Bkz. [setup-docker.md](../setup-docker.md),
[setup-k8s.md](../setup-k8s.md).

### Seçenek B — Düz metin (text slice) feed

Suricata, Wazuh CDB list, MikroTik address-list gibi STIX/TAXII
anlamayan araçlar için ana sayfa düz metin URL'leri:

```
https://bilsectr.github.io/sgb-api-bridge/domain-list.txt
https://bilsectr.github.io/sgb-api-bridge/ip-list.txt
https://bilsectr.github.io/sgb-api-bridge/url-list.txt
```

Bu listeler `connectiontype` ayrımı **içermez** (tek birleşik kara liste).
CT ayrımı isterseniz TAXII koleksiyonlarından kendi script'inizle çıkartın:

```bash
# sgb-botnet-cc koleksiyonundan IP'leri çıkar (Suricata için)
curl -s "https://sgb-taxii.bilsec.tr/api/collections/sgb-botnet-cc/objects/?limit=5000" \
  | jq -r '.objects[] | select(.x_sgb_type=="ip") | .x_sgb_value' \
  > /etc/suricata/rules/sgb-bc-ip.txt
```

Suricata rule generation:

```bash
awk '{print "drop ip any any -> "$1" any (msg:\"SGB Botnet C2\"; sid:9000001+NR;)"}' \
  /etc/suricata/rules/sgb-bc-ip.txt > /etc/suricata/rules/sgb-bc-ip.rules

systemctl reload suricata
```

Wazuh CDB list:

```bash
curl -s "https://sgb-taxii.bilsec.tr/api/collections/sgb-phishing/objects/?limit=5000" \
  | jq -r '.objects[] | select(.x_sgb_type=="domain") | .x_sgb_value + ":sgb_phishing"' \
  > /var/ossec/etc/lists/sgb_phishing.txt

/var/ossec/bin/wazuh-control reload
```

## Veri tazeliği

| Sistem | Önerilen polling | Notlar |
|--------|------------------|--------|
| XSOAR / XDR / Sentinel / Splunk ES / QRadar TI | 1 saat (built-in) | TAXII `added_after` ile incremental |
| Elastic Filebeat threatintel | 1 saat | `var.interval: 1h` |
| Suricata / Wazuh (text slice) | 1 saat | curl + reload |
| SOAR enrichment (synchronous lookup) | Lokal cache + 1h TTL | Hot lookup için TAXII çağrısı yapma |

## Custom enrichment cache (Python örnek)

```python
import requests, time

class SGBCache:
    def __init__(self, collection="sgb-phishing", ttl_sec=3600):
        self.url = f"https://sgb-taxii.bilsec.tr/api/collections/{collection}/objects/"
        self.ttl = ttl_sec
        self._values = set()
        self._loaded_at = 0

    def _refresh(self):
        next_cursor = ""
        values = set()
        while True:
            params = {"limit": 5000}
            if next_cursor:
                params["next"] = next_cursor
            r = requests.get(self.url, params=params, timeout=30).json()
            for obj in r.get("objects", []):
                if obj.get("type") == "indicator":
                    values.add(obj.get("x_sgb_value"))
            if not r.get("more"):
                break
            next_cursor = r["next"]
        self._values = values
        self._loaded_at = time.time()

    def __contains__(self, value):
        if time.time() - self._loaded_at > self.ttl:
            self._refresh()
        return value in self._values

sgb_phishing = SGBCache("sgb-phishing")
if "evilbank.example" in sgb_phishing:
    raise_alert()
```
