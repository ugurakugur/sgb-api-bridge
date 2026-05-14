# USOM Bridge

[![Last sync](https://img.shields.io/endpoint?url=https://sinansh.github.io/usom-bridge/badge.json)](https://sinansh.github.io/usom-bridge/stats.json)
[![Delta sync](https://github.com/sinansh/usom-bridge/actions/workflows/sync-delta.yml/badge.svg)](https://github.com/sinansh/usom-bridge/actions/workflows/sync-delta.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

USOM (Ulusal Siber Olaylara Müdahale Merkezi) tehdit beslemesini güvenlik duvarlarının (FortiGate, Sophos, Palo Alto, pfSense, Pi-hole, Squid) doğrudan tüketebileceği **düz metin** formatına dönüştüren açık kaynak proje.

Üç farklı dağıtım modelini destekler:

| Model | Senaryo | Kurulum dokümanı |
|---|---|---|
| **GitHub Pages** (genel) | Public CDN, sıfır kurulum, herkese açık feed | [docs/setup-github.md](docs/setup-github.md) |
| **Self-hosted GitLab** | Kurumun kendi GitLab sunucusu; internet'ten bağımsız | [docs/setup-gitlab.md](docs/setup-gitlab.md) |
| **Docker** | Tek konteyner, "indir-çalıştır-unut" | [docs/setup-docker.md](docs/setup-docker.md) |
| **Kubernetes** | CronJob + Deployment, kurumsal | [docs/setup-k8s.md](docs/setup-k8s.md) |

---

## Hızlı başlangıç (GitHub Pages — bu repo)

Aşağıdaki URL'leri firewall'una doğrudan ver:

| Tür | Adet | URL |
|---|---:|---|
| Domain | ~450K | `https://sinansh.github.io/usom-bridge/domain-list.txt` |
| IPv4 | ~14K | `https://sinansh.github.io/usom-bridge/ip-list.txt` |
| URL | ~7K | `https://sinansh.github.io/usom-bridge/url-list.txt` |
| IPv6 | — | `https://sinansh.github.io/usom-bridge/ip6-list.txt` |
| IPv6 subnet | — | `https://sinansh.github.io/usom-bridge/ip6net-list.txt` |
| Stats | — | `https://sinansh.github.io/usom-bridge/stats.json` |

## Hızlı başlangıç (Docker)

```bash
docker run -d \
  --name usom-bridge \
  -p 8080:80 \
  -v usom-bridge-data:/data \
  --restart unless-stopped \
  ghcr.io/sinansh/usom-bridge:latest
```

Detay: [docs/setup-docker.md](docs/setup-docker.md)

## Hızlı başlangıç (Kubernetes)

```bash
git clone https://github.com/sinansh/usom-bridge.git
kubectl apply -k usom-bridge/k8s/
```

Detay: [docs/setup-k8s.md](docs/setup-k8s.md)

---

## Nasıl çalışır?

- **Delta sync** — saatte bir, USOM API'sinden her tür için (`domain`, `url`, `ip`, `ip6`, `ip6net`) yalnız yeni kayıtları çeker (~1-3 dk).
- **Full sync** — pazar 03:00 UTC (veya 7 günde bir, Docker loop modunda), tüm kayıtları yeniden çeker (drift düzeltici, ~5-10 saat). Resume desteklidir; runner timeout'a takılırsa kaldığı yerden devam eder.

USOM API kayıtları tarih sırasına göre newest-first dönüyor ve ID'ler global monoton artıyor. Delta job'ı her tür için `state/seen_ids.json`'daki `max_id`'den büyük kayıtlara ulaşana kadar sayfaları dolaşıp, bilinen kayda denk gelince durur.

## Cihaz konfigürasyon örnekleri

### FortiGate (CLI)

```
config system external-resource
    edit "USOM-Domain"
        set type domain
        set resource "https://sinansh.github.io/usom-bridge/domain-list.txt"
        set refresh-rate 60
    next
    edit "USOM-IP"
        set type address
        set resource "https://sinansh.github.io/usom-bridge/ip-list.txt"
        set refresh-rate 60
    next
end
```

Kendi base URL'ini kullanmak için (GitLab/Docker/K8s) yukarıdaki host kısmını değiştir. Tüm cihazlar (Sophos, Palo Alto, pfSense, Pi-hole, Squid) için detaylı örnekler: [docs/setup-github.md](docs/setup-github.md).

## Kendin koşturmak istersen (CLI)

```bash
git clone https://github.com/sinansh/usom-bridge
cd usom-bridge
pip install requests
python scripts/sync.py --mode full     # ~5-10 saat
python scripts/sync.py --mode delta    # ~1-3 dk
python scripts/sync.py --mode loop     # docker icin: delta saatte, full haftada
```

Environment variables:

| Variable | Default | Açıklama |
|---|---|---|
| `USOM_BRIDGE_ROOT` | repo kökü | State ve docs/'un kök dizini |
| `USOM_BRIDGE_DELTA_INTERVAL_SEC` | `3600` | Loop modunda delta sıklığı |
| `USOM_BRIDGE_FULL_INTERVAL_DAYS` | `7` | Loop modunda full sıklığı |

## Veri kaynağı

USOM Open Threat Feed API: <https://www.usom.gov.tr/api/address/index>

Kayıt kategorileri (`desc` alanı):

| Kod | Açıklama |
|---|---|
| PH | Oltalama (Phishing) |
| BP | Bankacılık - Oltalama |
| MD / MI / MU | Zararlı yazılım barındıran Domain / IP / URL |
| MC | Komuta-Kontrol Merkezi |
| CA | Siber saldırı (port tarama, brute force vb.) |

## Sorumluluk reddi

Bu proje **USOM ile resmi bir bağlantısı olmayan**, kişisel, kâr amacı gütmeyen, açık kaynak bir araçtır. Üretim sistemlerinde "as-is" kullanılır; veri doğruluğundan USOM sorumludur.

## Lisans

[MIT](LICENSE)
